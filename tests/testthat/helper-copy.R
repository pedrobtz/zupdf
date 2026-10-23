# Inputs for the page-copying tests (test-assemble.R). They live here, not
# at the top of a test file, because devtools::test(shuffle = TRUE) reorders
# a file's top-level expressions, definitions included.

# A one-page PDF whose page has /Foo 4 0 R, the head of a chain of `n`
# objects << /N k+1 0 R >>: copying the page follows the whole chain.
chain_pdf <- function(n) {
  chain <- sprintf("<< /N %d 0 R >>", seq_len(n) + 4L)
  chain[[n]] <- "<< >>"
  build_pdf(c(
    list(
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Foo 4 0 R >>"
    ),
    as.list(chain)
  ))
}

# Three pages, 3, 4 and 5, under a page tree that also carries /Resources,
# /Rotate and a key no page inherits (/Foo). Page 3 has a link annotation,
# object 9, whose /P is page 3 and whose destination is page 5; each page's
# content stream (6, 7, 8) holds `size` bytes of comment, so a page copied
# by accident shows in the output's size.
linked_pdf <- function(size = 10000L) {
  content <- function(i) {
    list(dict = "<< >>", data = paste0("% ", strrep(letters[i], size)))
  }
  page <- function(k, extra = "") {
    sprintf("<< /Type /Page /Parent 2 0 R /Contents %d 0 R%s >>", k, extra)
  }
  build_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    paste(
      "<< /Type /Pages /Kids [3 0 R 4 0 R 5 0 R] /Count 3",
      "/MediaBox [0 0 300 400] /Rotate 90 /Foo 1",
      "/Resources << /ProcSet [/PDF] >> >>"
    ),
    page(6L, " /Annots [9 0 R]"),
    page(7L),
    page(8L),
    content(1L),
    content(2L),
    content(3L),
    "<< /Type /Annot /Subtype /Link /Rect [0 0 10 10] /P 3 0 R /Dest [5 0 R /Fit] >>"
  ))
}

# The output's objects of type `type`.
objects_of_type <- function(pdf, type) {
  o <- pdf_objects(pdf)
  o$number[!is.na(o$type) & o$type == type]
}
