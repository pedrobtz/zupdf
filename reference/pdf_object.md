# One object's value

Reads an object by number and returns its value as R values (design
section 6): dictionaries are named lists, arrays unnamed lists, names
character scalars of class `pdf_name`, strings plain character, byte
strings raw vectors of class `pdf_binary`, dates `POSIXct` in UTC,
references integers of class `pdf_ref` with a `generation` attribute,
`null` is `NULL`, and whole numbers within R's integer range are
integers. Dictionary keys come in the order pdfio keeps them, which is
sorted.

## Usage

``` r
pdf_object(pdf, n)
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

- n:

  An object number, as in
  [`pdf_objects()`](https://pedrobtz.github.io/zupdf/reference/pdf_objects.md)'s
  `number` column.

## Value

The object's value.

## Details

A stream object's value is its dictionary;
[`pdf_stream()`](https://pedrobtz.github.io/zupdf/reference/pdf_stream.md)
reads its bytes.

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_object(pdf, 1)
#> $Pages
#> 2 0 R
#> 
#> $Type
#> /Catalog
#> 
pdf_close(pdf)
```
