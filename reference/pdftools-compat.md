# pdftools-compatible readers

These functions take pdftools's arguments and return what pdftools
returns, so code written for pdftools runs with
[`library(zupdf)`](https://github.com/pedrobtz/zupdf) in place of
[`library(pdftools)`](https://ropensci.r-universe.dev/pdftools) for
everything but rendering. Each opens its input with
[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md)'s
default limits and closes it again; `pdf` may also be an open
`pdf_file`, which is left open.

## Usage

``` r
pdf_info(pdf, opw = "", upw = "")

pdf_text(pdf, opw = "", upw = "", raw = FALSE)

pdf_fonts(pdf, opw = "", upw = "")

pdf_pagesize(pdf, opw = "", upw = "")

pdf_toc(pdf, opw = "", upw = "")

pdf_attachments(pdf, opw = "", upw = "")
```

## Arguments

- pdf:

  A path, a raw vector, or an open `pdf_file`.

- opw, upw:

  The owner and user passwords; `""` for none.

- raw:

  For `pdf_text()`: `TRUE` for the text in content-stream order.

## Value

As pdftools: `pdf_info()` a list of `version`, `pages`, `encrypted`,
`linearized`, `keys`, `created`, `modified`, `metadata`, `locked`,
`attachments` and `layout`; `pdf_text()` one string per page;
`pdf_fonts()` a data frame of `name`, `type`, `embedded` and `file`;
`pdf_pagesize()` a data frame of `top`, `right`, `bottom`, `left`,
`width` and `height`; `pdf_toc()` a nested list of `title`, `is_open`
and `children`; `pdf_attachments()` a list of attachments, each with
`name`, `mime`, `created`, `modified`, `description` and `data`.

## Details

Where the results differ from pdftools's (design section 5.1):

- `pdf_text()` comes from zupdf's extractor
  ([`pdf_page_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_text.md)),
  not poppler's physical layout: the same pages and words, single spaces
  instead of padding to page positions, and no text from annotations.

- `pdf_fonts()` reports `file` as `""` for an embedded font and `NA`
  otherwise, since zupdf looks up no system fonts.

- `pdf_info()` reports an absent date as `NA`, where pdftools reports
  one second before 1970.

`pdf_render_page()`, `pdf_convert()` and the OCR functions need a
renderer and are not provided;
[`pdf_data()`](https://pedrobtz.github.io/zupdf/reference/pdf_data.md)
is not provided yet.

## Examples

``` r
path <- system.file("examples", "hello.pdf", package = "zupdf")
pdf_info(path)$pages
#> [1] 2
pdf_text(path)
#> [1] "Hello from zupdf.\n" "Page two.\n"        
pdf_pagesize(path)
#>   top right bottom left width height
#> 1   0   612    792    0   612    792
#> 2   0   612    792    0   612    792
```
