# qpdf-compatible assembly

These functions take qpdf's arguments and do what qpdf does, so code
written for qpdf runs with
[`library(zupdf)`](https://github.com/pedrobtz/zupdf) in place of
[`library(qpdf)`](https://docs.ropensci.org/qpdf/). They are
[`pdf_copy_pages()`](https://pedrobtz.github.io/zupdf/reference/pdf_copy_pages.md)
underneath: pdfio writes the output, so its bytes differ from qpdf's,
but its pages, their content and their order are the same.
Document-level parts, such as outlines and forms, are not carried over.
`pdf_compress()` and `pdf_overlay_stamp()` are not provided.

## Usage

``` r
pdf_length(input, password = "")

pdf_split(input, output = NULL, password = "")

pdf_subset(input, pages = 1, output = NULL, password = "")

pdf_combine(input, output = NULL, password = "")

pdf_rotate_pages(
  input,
  pages,
  angle = 90,
  relative = FALSE,
  output = NULL,
  password = ""
)
```

## Arguments

- input:

  A path (for `pdf_combine()`, paths), or an open `pdf_file`.

- password:

  The password for the input, or `""`.

- output:

  The output path, or `NULL` for qpdf's default next to the input: for
  `pdf_split()` a prefix, to which `_1.pdf`, `_2.pdf`, ... are added.

- pages:

  Page numbers to keep (`pdf_subset()`) or rotate
  (`pdf_rotate_pages()`); any R index into the pages, such as `-1`.

- angle:

  Degrees, a multiple of 90.

- relative:

  `TRUE` to add `angle` to each page's rotation, `FALSE` to set it.

## Value

`pdf_length()` the page count; the others the output path or paths, as
qpdf returns them.

## Examples

``` r
path <- system.file("examples", "hello.pdf", package = "zupdf")
pdf_length(path)
#> [1] 2
out <- pdf_subset(path, pages = 2, output = tempfile(fileext = ".pdf"))
pdf_length(out)
#> [1] 1
```
