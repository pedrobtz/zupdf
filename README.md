# zupdf

<!-- badges: start -->
[![R-CMD-check](https://github.com/pedrobtz/zupdf/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zupdf/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/zupdf/main/.github/badges/coverage.svg)](https://github.com/pedrobtz/zupdf/actions/workflows/coverage.yaml)
<!-- badges: end -->

zupdf reads, assembles and writes PDF files from R. It opens a file and reads
its metadata, pages, objects, streams, fonts, images and text; copies pages
between files to split, merge, rotate and reorder them; and writes new files
with text, paths and images. It bundles the [pdfio](https://github.com/michaelrsweet/pdfio)
C library, so it needs no system library beyond zlib. It never renders a page
to pixels: for that, use pdftools.

## Installation

zupdf is not on CRAN yet. Install the development version with:

``` r
# install.packages("pak")
pak::pak("pedrobtz/zupdf")
```

## Reading

``` r
library(zupdf)
pdf <- pdf_open("report.pdf")         # a path, raw vector or connection
pdf_meta(pdf)$pages
pdf_page_text(pdf, pages = 1)
pdf_font_table(pdf)
pdf_close(pdf)
```

Untrusted files are bounded by limits on size, objects, stream size and
nesting depth, and every error is a classed condition.

## Writing

``` r
w <- pdf_new(media_box = pdf_paper("a4"))
page <- pdf_page_new(w)
pdf_draw_text(page, 72, 760, "A heading", font = "Helvetica-Bold", size = 18)
pdf_draw(page, data.frame(op = "rect", x = 72, y = 600, w = 200, h = 100), fill = "steelblue")
pdf_page_end(page)
pdf_save(w, "out.pdf")
```

## Switching from pdftools and qpdf

zupdf provides the pdftools and qpdf functions that need no renderer, under
their names and with their arguments: `pdf_info()`, `pdf_text()`,
`pdf_data()`, `pdf_fonts()`, `pdf_pagesize()`, `pdf_toc()`,
`pdf_attachments()`, `pdf_length()`, `pdf_split()`, `pdf_subset()`,
`pdf_combine()` and `pdf_rotate_pages()`. Code using only these runs with
`library(zupdf)` in their place. Attached after pdftools or qpdf, zupdf masks
their functions of the same name. See `vignette("switching", package = "zupdf")`
for where the results differ.
