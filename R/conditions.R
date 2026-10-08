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
