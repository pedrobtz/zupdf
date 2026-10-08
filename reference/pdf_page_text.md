# Text on pages

Extracts each page's text. zupdf walks the page's content streams,
tracks the text state, maps each character code to Unicode through the
font's ToUnicode map or its encoding, and places each glyph on the page.

## Usage

``` r
pdf_page_text(pdf, pages = NULL, layout = c("reading", "raw"))
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

- pages:

  Page numbers, or `NULL` for every page.

- layout:

  `"reading"` or `"raw"`.

## Value

A character vector, one string per page, with an integer attribute
`unmapped`.

## Details

`layout = "reading"` groups the glyphs into lines by baseline, top to
bottom, and each line's runs left to right, with a space where the gap
between runs is a word space or more. Columns that share baselines come
out side by side on one line. `layout = "raw"` is the text in the order
the content stream shows it, with a line break where the stream moves to
a new line and a space at a large gap in a `TJ` array.

A character the font cannot map becomes U+FFFD, and the count per page
is the `unmapped` attribute. Text in Form XObjects is included; their
nesting is bounded by the `max_depth` of
[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md),
and a form drawn inside itself is a `zupdf_limit_error`.

## See also

[`pdf_page_tokens()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_tokens.md)
for the content stream's tokens.

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_page_text(pdf)
#> [1] "Hello from zupdf." "Page two."        
#> attr(,"unmapped")
#> [1] 0 0
pdf_page_text(pdf, pages = 2, layout = "raw")
#> [1] "Page two."
#> attr(,"unmapped")
#> [1] 0
pdf_close(pdf)
```
