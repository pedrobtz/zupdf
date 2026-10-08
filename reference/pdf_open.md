# Open a PDF file

Opens a PDF for reading. pdfio reads the file lazily, through its
cross-reference table, so opening is cheap and later calls go back to
the file. The handle keeps the file open until
[`pdf_close()`](https://pedrobtz.github.io/zupdf/reference/pdf_close.md)
or until it is garbage collected.

## Usage

``` r
pdf_open(
  x,
  password = NULL,
  ...,
  max_size = 1024^3,
  max_objects = 1e+06,
  max_stream = 256 * 1024^2,
  max_depth = 64,
  max_pages = 1e+05
)
```

## Arguments

- x:

  A path to a PDF file, a raw vector holding one, a connection to read
  one from, or an open `pdf_file`, which is returned unchanged. Raw
  vectors and connections are written to a temporary file, which the
  handle removes when it is closed.

- password:

  `NULL` for none, a string, or a function of the file name that returns
  one. A function is called only when the file turns out to need a
  password.

- ...:

  Must be empty.

- max_size:

  Largest input, in bytes.

- max_objects:

  Most objects in the cross-reference table.

- max_stream:

  Largest decoded stream, in bytes.

- max_depth:

  Deepest nesting of values, Form XObjects and the page tree.

- max_pages:

  Most pages.

## Value

A `pdf_file`. [`length()`](https://rdrr.io/r/base/length.html) gives its
page count.

## Details

A PDF is a common carrier of hostile input, so opening is bounded by
limits. `max_size` is checked before anything is read; `max_objects` and
`max_pages` right after the cross-reference table is read; `max_stream`
and `max_depth` by the functions that decode streams and walk nested
values. Each limit is a positive whole number or `Inf`.

## See also

[`pdf_meta()`](https://pedrobtz.github.io/zupdf/reference/pdf_meta.md),
[`pdf_pages()`](https://pedrobtz.github.io/zupdf/reference/pdf_pages.md),
[zupdf-conditions](https://pedrobtz.github.io/zupdf/reference/zupdf-conditions.md).

## Examples

``` r
path <- system.file("examples", "hello.pdf", package = "zupdf")
pdf <- pdf_open(path)
pdf
#> <pdf_file>
#>   /home/runner/work/_temp/Library/zupdf/examples/hello.pdf
#>   PDF 1.4, 2 pages, not encrypted
length(pdf)
#> [1] 2
pdf_close(pdf)
```
