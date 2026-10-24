# Fonts in a file

Lists every font object in the file.

## Usage

``` r
pdf_font_table(pdf)
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

## Value

A data frame with columns `object` (the font's object number), `name`
(its `/BaseFont`, with any subset prefix such as `ABCDEF+` kept), `type`
(its `/Subtype`, such as `"Type1"`, `"TrueType"` or `"Type0"`) and
`embedded` (whether the font program is in the file; always for a Type 3
font, whose glyphs are drawn by the file).

## Details

A font whose dictionary cannot be read is listed with `NA` name, type
and `embedded`, and the errors become one `zupdf_warning`, as in
[`pdf_objects()`](https://pedrobtz.github.io/zupdf/reference/pdf_objects.md).

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_font_table(pdf)
#>   object      name  type embedded
#> 1      3 Helvetica Type1    FALSE
pdf_close(pdf)
```
