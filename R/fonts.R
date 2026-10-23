#' Fonts in a file
#'
#' Lists every font object in the file.
#'
#' A font whose dictionary cannot be read is listed with `NA` name, type
#' and `embedded`, and the errors become one `zupdf_warning`, as in
#' [pdf_objects()].
#'
#' @inheritParams pdf_meta
#' @return A data frame with columns `object` (the font's object number),
#'   `name` (its `/BaseFont`, with any subset prefix such as `ABCDEF+`
#'   kept), `type` (its `/Subtype`, such as `"Type1"`, `"TrueType"` or
#'   `"Type0"`) and `embedded` (whether the font program is in the file;
#'   always for a Type 3 font, whose glyphs are drawn by the file).
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_font_table(pdf)
#' pdf_close(pdf)
pdf_font_table <- function(pdf) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  objs <- suppressWarnings(pdf_objects(pdf))
  # A descendant CID font is listed by its Type0 parent, not on its own.
  numbers <- objs$number[
    objs$type %in% "Font" & !objs$subtype %in% c("CIDFontType0", "CIDFontType2")
  ]
  na_row <- list(name = NA_character_, type = NA_character_, embedded = NA)
  rows <- zpd_rows(numbers, na_row, call, function(n) {
    d <- pdf_object(pdf, n)
    list(
      name = zpd_chr(zpd_key(d, "BaseFont")),
      type = zpd_chr(zpd_key(d, "Subtype")),
      embedded = zpd_font_embedded(pdf, d)
    )
  })
  data.frame(
    object = numbers,
    name = vapply(rows, `[[`, "", "name"),
    type = vapply(rows, `[[`, "", "type"),
    embedded = vapply(rows, `[[`, TRUE, "embedded")
  )
}

# Calls `f` on each of `numbers` and returns the results as a list. An
# object that fails with a zupdf_error gets `na_row` instead, and the
# failures become one zupdf_warning naming them, as in pdf_objects(): one
# unreadable object does not fail a table.
zpd_rows <- function(numbers, na_row, call, f) {
  failed <- numeric()
  first <- NULL
  rows <- lapply(numbers, function(n) {
    tryCatch(f(n), zupdf_error = function(e) {
      failed <<- c(failed, n)
      if (is.null(first)) {
        first <<- conditionMessage(e)
      }
      na_row
    })
  })
  if (length(failed)) {
    zpd_warn(
      sprintf(
        "%d object%s could not be read; the first: %s",
        length(failed),
        if (length(failed) == 1L) "" else "s",
        first
      ),
      detail = first,
      count = length(failed),
      object = zpd_counts(failed),
      call = call
    )
  }
  rows
}

# A name or string value as character, NA when absent.
zpd_chr <- function(x) {
  if (is.null(x)) NA_character_ else as.character(unclass(x))[[1L]]
}

# A dictionary's entry under exactly `key`; NULL when absent or when `d` is
# not a dictionary. `$` would match a prefix: d$F finds /FS.
zpd_key <- function(d, key) {
  if (is.list(d) && !is.null(names(d))) d[[key, exact = TRUE]] else NULL
}

# Follows a pdf_ref to its object's value; anything else is returned as is.
zpd_deref <- function(pdf, x) {
  if (inherits(x, "pdf_ref")) pdf_object(pdf, unclass(x)[[1L]]) else x
}

# A whole-number entry, followed through a reference, as an integer; NA
# when absent, not a number, or outside R's integer range.
zpd_int <- function(pdf, x) {
  x <- zpd_deref(pdf, x)
  ok <- is.numeric(x) &&
    length(x) == 1L &&
    is.finite(x) &&
    abs(x) <= .Machine$integer.max
  if (ok) as.integer(x) else NA_integer_
}

zpd_font_embedded <- function(pdf, d) {
  subtype <- zpd_chr(zpd_key(d, "Subtype"))
  # A Type 3 font's glyphs are content streams in the file itself.
  if (identical(subtype, "Type3")) {
    return(TRUE)
  }
  if (identical(subtype, "Type0")) {
    desc <- zpd_deref(pdf, zpd_key(d, "DescendantFonts"))
    if (!is.list(desc) || length(desc) == 0L) {
      return(FALSE)
    }
    d <- zpd_deref(pdf, desc[[1L]])
  }
  fd <- zpd_deref(pdf, zpd_key(d, "FontDescriptor"))
  is.list(fd) && any(c("FontFile", "FontFile2", "FontFile3") %in% names(fd))
}
