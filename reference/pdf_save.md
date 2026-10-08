# Finish a PDF file

Writes the trailer and returns the file's bytes, or writes them to a
file or connection. Every page must have been ended. The writer cannot
be used afterwards.

## Usage

``` r
pdf_save(w, file = NULL)
```

## Arguments

- w:

  A `pdf_writer` from
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md).

- file:

  `NULL` to return the bytes, a path, or a connection.

## Value

The bytes as a raw vector when `file` is `NULL`, else `file`, invisibly.

## Examples

``` r
w <- pdf_new()
pdf_page_end(pdf_page_new(w))
length(pdf_save(w))
#> [1] 9996
```
