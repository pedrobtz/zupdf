#' Text on pages
#'
#' Extracts each page's text. zupdf walks the page's content streams,
#' tracks the text state, maps each character code to Unicode through the
#' font's ToUnicode map or its encoding, and places each glyph on the page.
#'
#' `layout = "reading"` groups the glyphs into lines by baseline, top to
#' bottom, and each line's runs left to right, with a space where the gap
#' between runs is a word space or more. Columns that share baselines come
#' out side by side on one line. `layout = "raw"` is the text in the order
#' the content stream shows it, with a line break where the stream moves to
#' a new line and a space at a large gap in a `TJ` array.
#'
#' A character the font cannot map becomes U+FFFD, and the count per page
#' is the `unmapped` attribute. Text in Form XObjects is included; their
#' nesting is bounded by the `max_depth` of [pdf_open()], and a form drawn
#' inside itself is a `zupdf_limit_error`.
#'
#' @inheritParams pdf_meta
#' @param pages Page numbers, or `NULL` for every page.
#' @param layout `"reading"` or `"raw"`.
#' @return A character vector, one string per page, with an integer
#'   attribute `unmapped`.
#' @seealso [pdf_page_tokens()] for the content stream's tokens.
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_page_text(pdf)
#' pdf_page_text(pdf, pages = 2, layout = "raw")
#' pdf_close(pdf)
pdf_page_text <- function(pdf, pages = NULL, layout = c("reading", "raw")) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  layout <- zpd_match_arg(layout, c("reading", "raw"), "layout", call)
  pages <- zpd_check_pages(pdf, pages, call = call)
  limits <- zpd_limits(pdf)
  v <- zpd_unwrap(
    .Call(
      zupdf_page_text,
      pdf,
      pages,
      layout == "raw",
      zpd_depth_int(limits$max_depth),
      limits$max_stream
    ),
    "Cannot extract the text",
    call,
    limits = limits
  )
  structure(v$text, unmapped = v$unmapped)
}

#' Content stream tokens
#'
#' The tokens of one page's content streams, in order: the raw material for
#' anything [pdf_page_text()] does not do. Strings are shown as text, read
#' as UTF-8 or PDFDocEncoding; the bytes an inline image holds are not
#' shown, only their count.
#'
#' @inheritParams pdf_meta
#' @param i A page number.
#' @return A data frame with columns `type` (`"number"`, `"name"`,
#'   `"string"`, `"operator"`, `"array_open"`, `"array_close"`,
#'   `"dict_open"`, `"dict_close"` or `"inline_image"`) and `value` (names
#'   without their slash).
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_page_tokens(pdf, 1)
#' pdf_close(pdf)
pdf_page_tokens <- function(pdf, i) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  i <- zpd_check_pages(pdf, i, single = TRUE, arg = "i", call = call)
  limits <- zpd_limits(pdf)
  v <- zpd_unwrap(
    .Call(zupdf_page_tokens, pdf, i, limits$max_stream),
    "Cannot read the content stream",
    call,
    limits = limits
  )
  data.frame(type = v$type, value = v$value)
}

# Page numbers in 1..length(pdf) as integers; NULL means every page.
zpd_check_pages <- function(
  pdf,
  pages,
  single = FALSE,
  arg = "pages",
  call = NULL
) {
  n <- length(pdf)
  if (is.null(pages) && !single) {
    return(seq_len(n))
  }
  ok <- is.numeric(pages) &&
    length(pages) >= 1L &&
    (!single || length(pages) == 1L) &&
    !anyNA(pages) &&
    all(pages == floor(pages)) &&
    all(pages >= 1 & pages <= n)
  if (!ok) {
    zpd_invalid_argument(
      arg,
      sprintf(
        "`%s` must be %s between 1 and %d, the page count.",
        arg,
        if (single) "a page number" else "page numbers",
        n
      ),
      call = call
    )
  }
  as.integer(pages)
}

zpd_match_arg <- function(value, choices, arg, call = NULL) {
  if (identical(value, choices)) {
    return(choices[[1L]])
  }
  if (!is.character(value) || length(value) != 1L || !value %in% choices) {
    zpd_invalid_argument(
      arg,
      sprintf(
        "`%s` must be one of %s.",
        arg,
        paste0("\"", choices, "\"", collapse = ", ")
      ),
      call = call
    )
  }
  value
}
