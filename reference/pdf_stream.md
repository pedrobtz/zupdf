# One object's stream

Reads a stream object's bytes, decoded or as stored. pdfio decodes
`FlateDecode`, with or without a PNG predictor. A stream with any other
filter, such as `DCTDecode` (JPEG) or `ASCII85Decode`, is returned as
stored even when `decode = TRUE`, with `decoded = FALSE`, so the caller
can decode it, for example with `jpeg::readJPEG()`.

## Usage

``` r
pdf_stream(pdf, n, decode = TRUE)
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

- n:

  An object number, as in
  [`pdf_objects()`](https://pedrobtz.github.io/zupdf/reference/pdf_objects.md)'s
  `number` column.

- decode:

  `TRUE` to decode the stream's filters, `FALSE` for the bytes as stored
  in the file.

## Value

A raw vector with attributes `decoded` (whether the filters were
applied) and `filter` (the stream's filter names, in order).

## Details

The stream is bounded by the `max_stream` limit of
[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md),
which stops a small compressed stream that inflates to gigabytes.

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
rawToChar(pdf_stream(pdf, 5))
#> [1] "BT /F1 12 Tf 72 720 Td (Hello from zupdf.) Tj ET"
pdf_close(pdf)
```
