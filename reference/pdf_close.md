# Close a PDF file

Closes the file and removes any temporary copy
[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md)
made. Every other function refuses a closed handle. Closing twice is
harmless.

## Usage

``` r
pdf_close(pdf)
```

## Arguments

- pdf:

  A `pdf_file`.

## Value

`NULL`, invisibly.

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_close(pdf)
pdf_close(pdf)
```
