# Switching from pdftools and qpdf

zupdf provides the functions of pdftools and qpdf that need no renderer,
under their names and with exactly their arguments, so code written for
either runs with [`library(zupdf)`](https://github.com/pedrobtz/zupdf)
in their place:

``` r

library(zupdf)
path <- system.file("examples", "hello.pdf", package = "zupdf")
pdf_info(path)$pages
#> [1] 2
pdf_text(path)
#> [1] "Hello from zupdf.\n" "Page two.\n"
pdf_data(path)[[1]]
#>   width height   x  y space   text
#> 1    27     11  72 63  TRUE  Hello
#> 2    24     11 103 63  TRUE   from
#> 3    33     11 130 63 FALSE zupdf.
pdf_length(path)
#> [1] 2
```

| From | Provided | Not provided |
|----|----|----|
| pdftools | [`pdf_info()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md), [`pdf_text()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md), [`pdf_data()`](https://pedrobtz.github.io/zupdf/reference/pdf_data.md), [`pdf_fonts()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md), [`pdf_pagesize()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md), [`pdf_toc()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md), [`pdf_attachments()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md) | `pdf_render_page()`, `pdf_convert()`, `pdf_ocr_text()`, `pdf_ocr_data()`, `poppler_config()` |
| qpdf | [`pdf_length()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md), [`pdf_split()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md), [`pdf_subset()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md), [`pdf_combine()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md), [`pdf_rotate_pages()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md) | `pdf_compress()`, `pdf_overlay_stamp()` |

What is not provided is not defined at all, so a call fails with “could
not find function” rather than doing something else.

## Where results differ

- [`pdf_text()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md)
  comes from zupdf’s extractor, not poppler’s physical layout: the same
  pages and words, single spaces where poppler pads to page positions,
  and no text from annotations (form fields and stamps).
- [`pdf_data()`](https://pedrobtz.github.io/zupdf/reference/pdf_data.md)‘s
  word boxes agree with poppler’s to within a point or two; poppler
  takes some fonts’ heights from elsewhere.
- [`pdf_fonts()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md)
  reports `file` as `""` for an embedded font and `NA` otherwise: zupdf
  looks up no system fonts.
- [`pdf_info()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md)
  reports an absent date as `NA`.
- The qpdf functions write through pdfio, so the output’s bytes differ
  from qpdf’s; its pages, content and order are the same. Outlines and
  forms are not carried over.

## Attaching both

R lets the package attached last win, and says so. Attaching zupdf after
pdftools or qpdf masks their functions of the same name; `pdftools::`
and `qpdf::` still reach theirs.
