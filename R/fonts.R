#' Fonts in a file
#'
#' Lists every font object in the file.
#'
#' @inheritParams pdf_meta
#' @return A data frame with columns `object` (the font's object number),
#'   `name` (its `/BaseFont`, with any subset prefix such as `ABCDEF+`
#'   kept), `type` (its `/Subtype`, such as `"Type1"`, `"TrueType"` or
#'   `"Type0"`) and `embedded` (whether the font program is in the file).
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
  rows <- lapply(numbers, function(n) {
    d <- pdf_object(pdf, n)
    list(
      object = n,
      name = zpd_chr(d$BaseFont),
      type = zpd_chr(d$Subtype),
      embedded = zpd_font_embedded(pdf, d)
    )
  })
  data.frame(
    object = vapply(rows, `[[`, 1L, "object"),
    name = vapply(rows, `[[`, "", "name"),
    type = vapply(rows, `[[`, "", "type"),
    embedded = vapply(rows, `[[`, TRUE, "embedded")
  )
}

# A name or string value as character, NA when absent.
zpd_chr <- function(x) {
  if (is.null(x)) NA_character_ else as.character(unclass(x))[[1L]]
}

# Follows a pdf_ref to its object's value; anything else is returned as is.
zpd_deref <- function(pdf, x) {
  if (inherits(x, "pdf_ref")) pdf_object(pdf, unclass(x)[[1L]]) else x
}

zpd_font_embedded <- function(pdf, d) {
  if (identical(zpd_chr(d$Subtype), "Type0")) {
    desc <- zpd_deref(pdf, d$DescendantFonts)
    if (length(desc) == 0L) {
      return(FALSE)
    }
    d <- zpd_deref(pdf, desc[[1L]])
  }
  fd <- zpd_deref(pdf, d$FontDescriptor)
  is.list(fd) && any(c("FontFile", "FontFile2", "FontFile3") %in% names(fd))
}
