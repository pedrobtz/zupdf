# The condition hierarchy of design section 11. The class is the contract:
# callers branch on it and on the fields below, never on the message.

#' Conditions raised by zupdf
#'
#' Every error zupdf raises carries a condition class, so it can be caught
#' by kind rather than by matching the message, which may change. Every
#' class below inherits from `zupdf_error`, which inherits from `error`.
#' Each carries `detail`, pdfio's own message where there is one.
#'
#' \describe{
#'   \item{`zupdf_invalid_argument`}{An argument was unusable: an unknown
#'     page, a bad colour, a limit that is not a positive whole number.
#'     Carries `arg`, the argument at fault.}
#'   \item{`zupdf_parse_error`}{pdfio refused the file or an object.
#'     Carries `object`, the object number, when pdfio named one.}
#'   \item{`zupdf_password_error`}{The file is encrypted and no password
#'     given opened it.}
#'   \item{`zupdf_limit_error`}{A limit was reached. Carries `limit`, the
#'     argument's name, such as `"max_stream"`, and `limit_value`.}
#'   \item{`zupdf_unsupported_input`}{The input uses something zupdf does
#'     not support, such as a WebP image or AES-256 writing.}
#'   \item{`zupdf_write_error`}{pdfio refused to write, or a closed writer
#'     was used.}
#'   \item{`zupdf_font_error`}{A font file could not be read.}
#'   \item{`zupdf_io_error`}{A file, temporary file or connection failed.}
#'   \item{`zupdf_encoding_error`}{Extracted text is not valid UTF-8 after
#'     mapping.}
#' }
#'
#' Warnings carry the class `zupdf_warning`.
#'
#' @name zupdf-conditions
#' @examples
#' tryCatch(
#'   stop(structure(
#'     class = c("zupdf_parse_error", "zupdf_error", "error", "condition"),
#'     list(message = "PDF parse error", call = NULL, detail = NULL)
#'   )),
#'   zupdf_error = function(e) class(e)[1]
#' )
NULL

# Every class of design section 11, most specific first. test-conditions.R
# checks that zpd_abort() refuses anything else.
zpd_condition_classes <- c(
  "zupdf_invalid_argument",
  "zupdf_parse_error",
  "zupdf_password_error",
  "zupdf_limit_error",
  "zupdf_unsupported_input",
  "zupdf_write_error",
  "zupdf_font_error",
  "zupdf_io_error",
  "zupdf_encoding_error"
)

# Builds and raises a classed condition. `class` is one of
# zpd_condition_classes; the fields in `...` become list elements.
zpd_abort <- function(class, message, ..., detail = NULL, call = NULL) {
  stopifnot(class %in% zpd_condition_classes)
  stop(structure(
    class = c(class, "zupdf_error", "error", "condition"),
    list(message = message, call = call, detail = detail, ...)
  ))
}

zpd_invalid_argument <- function(arg, message, call = NULL) {
  zpd_abort("zupdf_invalid_argument", message, arg = arg, call = call)
}

zpd_limit_error <- function(limit, limit_value, message, call = NULL) {
  zpd_abort(
    "zupdf_limit_error",
    message,
    limit = limit,
    limit_value = limit_value,
    call = call
  )
}

# Raises a classed warning. pdfio's WARNING: messages arrive as `detail`,
# one warning per call with their count (design section 11).
zpd_warn <- function(message, ..., detail = NULL, call = NULL) {
  warning(structure(
    class = c("zupdf_warning", "warning", "condition"),
    list(message = message, call = call, detail = detail, ...)
  ))
}

# ---- pdfio's messages -------------------------------------------------------

# pdfio reports errors as English strings, so the class comes from the
# message's prefix; anything else falls to the bare default class on
# purpose (design section 11). test-conditions.R enumerates this table.
zpd_pdfio_prefixes <- c(
  "Unable to unlock PDF file." = "zupdf_password_error",
  "Unable to unlock AES-256" = "zupdf_unsupported_input",
  "Unable to open file" = "zupdf_io_error",
  "Unable to open image file" = "zupdf_io_error",
  "Unable to open font file" = "zupdf_io_error",
  "Unsupported image file" = "zupdf_unsupported_input"
)

zpd_pdfio_class <- function(detail, default = "zupdf_parse_error") {
  if (length(detail) != 1L || is.na(detail)) {
    return(default)
  }
  hit <- startsWith(detail, names(zpd_pdfio_prefixes))
  if (any(hit)) zpd_pdfio_prefixes[[which(hit)[[1L]]]] else default
}

# Unwraps a zpd_result() from C: warns once for pdfio's warnings, raises
# for a status other than "ok", and returns the value. `what` begins the
# message; pdfio's own message follows it and is kept as `detail`.
zpd_unwrap <- function(
  res,
  what,
  call = NULL,
  default = "zupdf_parse_error",
  limits = NULL
) {
  if (res$nwarning > 0L) {
    zpd_warn(
      sprintf(
        "pdfio reported %d warning%s; the first: %s",
        res$nwarning,
        if (res$nwarning == 1L) "" else "s",
        sub("^WARNING: *", "", res$warning)
      ),
      detail = res$warning,
      count = res$nwarning,
      call = call
    )
  }
  switch(
    res$status,
    ok = res$value,
    closed = zpd_invalid_argument("pdf", "The PDF file is closed.", call),
    pdfio = zpd_abort(
      zpd_pdfio_class(res$detail, default),
      paste0(what, ": ", res$detail),
      detail = res$detail,
      call = call
    ),
    max_depth = zpd_limit_error(
      "max_depth",
      limits$max_depth,
      sprintf(
        "%s: the value nests deeper than `max_depth` (%s).",
        what,
        format(limits$max_depth, scientific = FALSE)
      ),
      call = call
    ),
    max_stream = zpd_limit_error(
      "max_stream",
      limits$max_stream,
      sprintf(
        "%s: the stream is larger than `max_stream` (%s bytes).",
        what,
        format(limits$max_stream, scientific = FALSE, big.mark = "")
      ),
      call = call
    ),
    unknown_object = zpd_invalid_argument(
      "n",
      sprintf("%s: there is no such object in the file.", what),
      call = call
    ),
    no_stream = zpd_invalid_argument(
      "n",
      sprintf("%s: the object has no stream.", what),
      call = call
    ),
    unknown_ref = zpd_invalid_argument(
      "x",
      sprintf("%s: a pdf_ref names no object in the file.", what),
      call = call
    ),
    font = zpd_abort(
      zpd_pdfio_class(res$detail, "zupdf_font_error"),
      paste0(what, ": ", res$detail),
      detail = res$detail,
      call = call
    ),
    image = zpd_abort(
      zpd_pdfio_class(res$detail, "zupdf_parse_error"),
      paste0(what, ": ", res$detail),
      detail = res$detail,
      call = call
    ),
    memory = zpd_abort(
      "zupdf_parse_error",
      sprintf("%s: out of memory.", what),
      call = call
    ),
    unsupported = zpd_invalid_argument(
      "x",
      sprintf("%s: a value has no PDF form.", what),
      call = call
    ),
    closed_writer = zpd_abort(
      "zupdf_write_error",
      sprintf("%s: the writer is closed.", what),
      call = call
    ),
    stop("unknown status from C: ", res$status)
  )
}
