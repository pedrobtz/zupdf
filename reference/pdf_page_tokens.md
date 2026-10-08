# Content stream tokens

The tokens of one page's content streams, in order: the raw material for
anything
[`pdf_page_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_text.md)
does not do. Strings are shown as text, read as UTF-8 or PDFDocEncoding;
the bytes an inline image holds are not shown, only their count.

## Usage

``` r
pdf_page_tokens(pdf, i)
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

- i:

  A page number.

## Value

A data frame with columns `type` (`"number"`, `"name"`, `"string"`,
`"operator"`, `"array_open"`, `"array_close"`, `"dict_open"`,
`"dict_close"` or `"inline_image"`) and `value` (names without their
slash).

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_page_tokens(pdf, 1)
#>        type             value
#> 1  operator                BT
#> 2      name                F1
#> 3    number                12
#> 4  operator                Tf
#> 5    number                72
#> 6    number               720
#> 7  operator                Td
#> 8    string Hello from zupdf.
#> 9  operator                Tj
#> 10 operator                ET
pdf_close(pdf)
```
