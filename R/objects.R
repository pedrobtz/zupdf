#' The object table
#'
#' Lists every object in the file's cross-reference table.
#'
#' Objects that cannot be read are listed with `NA` type and subtype, and
#' pdfio's messages for them become one `zupdf_warning`.
#'
#' @inheritParams pdf_meta
#' @return A data frame with columns `number` and `generation` (the object
#'   identifier), `type` and `subtype` (the dictionary's `/Type` and
#'   `/Subtype`, `NA` where absent) and `length` (the stored length of the
#'   object's stream, `NA` for an object without one).
#' @seealso [pdf_object()], [pdf_stream()].
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_objects(pdf)
#' pdf_close(pdf)
pdf_objects <- function(pdf) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  v <- zpd_unwrap(.Call(zupdf_objects, pdf), "Cannot list the objects", call)
  data.frame(
    number = zpd_counts(v$number),
    generation = v$generation,
    type = v$type,
    subtype = v$subtype,
    length = zpd_counts(v$length)
  )
}

#' One object's value
#'
#' Reads an object by number and returns its value as R values (design
#' section 6): dictionaries are named lists, arrays unnamed lists, names
#' character scalars of class `pdf_name`, strings plain character, byte
#' strings raw vectors of class `pdf_binary`, dates `POSIXct` in UTC,
#' references integers of class `pdf_ref` with a `generation` attribute,
#' `null` is `NULL`, and whole numbers within R's integer range are
#' integers. Dictionary keys come in the order pdfio keeps them, which is
#' sorted.
#'
#' A stream object's value is its dictionary; [pdf_stream()] reads its
#' bytes.
#'
#' @inheritParams pdf_meta
#' @param n An object number, as in [pdf_objects()]'s `number` column.
#' @return The object's value.
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_object(pdf, 1)
#' pdf_close(pdf)
pdf_object <- function(pdf, n) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  n <- zpd_check_number(n, "n", call = call)
  limits <- zpd_limits(pdf)
  v <- zpd_unwrap(
    .Call(zupdf_object, pdf, n, zpd_depth_int(limits$max_depth)),
    sprintf("Cannot read object %s", format(n, scientific = FALSE)),
    call,
    limits = limits
  )
  v$value
}

#' One object's stream
#'
#' Reads a stream object's bytes, decoded or as stored. pdfio decodes
#' `FlateDecode`, with or without a PNG predictor. A stream with any other
#' filter, such as `DCTDecode` (JPEG) or `ASCII85Decode`, is returned as
#' stored even when `decode = TRUE`, with `decoded = FALSE`, so the caller
#' can decode it, for example with `jpeg::readJPEG()`.
#'
#' The stream is bounded by the `max_stream` limit of [pdf_open()], which
#' stops a small compressed stream that inflates to gigabytes.
#'
#' @inheritParams pdf_object
#' @param decode `TRUE` to decode the stream's filters, `FALSE` for the
#'   bytes as stored in the file.
#' @return A raw vector with attributes `decoded` (whether the filters were
#'   applied) and `filter` (the stream's filter names, in order).
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' rawToChar(pdf_stream(pdf, 5))
#' pdf_close(pdf)
pdf_stream <- function(pdf, n, decode = TRUE) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  n <- zpd_check_number(n, "n", call = call)
  if (!isTRUE(decode) && !isFALSE(decode)) {
    zpd_invalid_argument("decode", "`decode` must be TRUE or FALSE.", call)
  }
  limits <- zpd_limits(pdf)
  v <- zpd_unwrap(
    .Call(zupdf_stream, pdf, n, decode, limits$max_stream),
    sprintf(
      "Cannot read the stream of object %s",
      format(n, scientific = FALSE)
    ),
    call,
    limits = limits
  )
  structure(v$bytes, decoded = v$decoded, filter = v$filter)
}

# Counts as integers where every one fits, doubles otherwise.
zpd_counts <- function(x) {
  if (all(is.na(x) | x <= .Machine$integer.max)) as.integer(x) else x
}
