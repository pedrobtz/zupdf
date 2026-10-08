# The object table

Lists every object in the file's cross-reference table.

## Usage

``` r
pdf_objects(pdf)
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

## Value

A data frame with columns `number` and `generation` (the object
identifier), `type` and `subtype` (the dictionary's `/Type` and
`/Subtype`, `NA` where absent) and `length` (the stored length of the
object's stream, `NA` for an object without one).

## Details

Objects that cannot be read are listed with `NA` type and subtype, and
pdfio's messages for them become one `zupdf_warning`.

## See also

[`pdf_object()`](https://pedrobtz.github.io/zupdf/reference/pdf_object.md),
[`pdf_stream()`](https://pedrobtz.github.io/zupdf/reference/pdf_stream.md).

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_objects(pdf)
#>   number generation    type subtype length
#> 1      1          0 Catalog    <NA>     NA
#> 2      2          0   Pages    <NA>     NA
#> 3      3          0    Font   Type1     NA
#> 4      4          0    Page    <NA>     NA
#> 5      5          0    <NA>    <NA>     48
#> 6      6          0    Page    <NA>     NA
#> 7      7          0    <NA>    <NA>     40
#> 8      8          0    <NA>    <NA>     NA
pdf_close(pdf)
```
