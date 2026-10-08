# Paper sizes

Page sizes as media boxes for
[`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md) and
[`pdf_page_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md):
the ISO A and B series and the North American letter, legal and tabloid
sizes, in PDF points (1/72 inch).

## Usage

``` r
pdf_paper(name, landscape = FALSE)
```

## Arguments

- name:

  A size, such as `"a4"`, `"b5"` or `"letter"`; case is ignored.

- landscape:

  `TRUE` to swap width and height.

## Value

`c(0, 0, width, height)`.

## Examples

``` r
pdf_paper("a4")
#> [1]   0.00   0.00 595.28 841.89
pdf_paper("letter", landscape = TRUE)
#> [1]   0   0 792 612
```
