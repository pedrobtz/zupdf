# Copy pages between files

Copies pages of an open file into a writer, after the pages it already
has, each with everything it uses (fonts, images, forms), so the result
stands alone. Splitting, merging, reordering and rotating are all this:
copy the pages wanted, in the order wanted, from each file in turn.

## Usage

``` r
pdf_copy_pages(w, pdf, pages = NULL, rotate = 0)
```

## Arguments

- w:

  A `pdf_writer` from
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md).

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md);
  it must stay open until the writer is saved.

- pages:

  Page numbers, in the order to copy them (repeats allowed), or `NULL`
  for every page.

- rotate:

  Degrees to add to each copied page's rotation, a multiple of 90.

## Value

`w`, invisibly.

## Details

A page's own entries are copied, with the attributes it inherits from
the page tree (resources, boxes and rotation). A reference from a copied
page to another page, such as a link or an annotation's page, leads to
that page's copy when it is copied in the same call (to its first copy
when it is copied twice), and is null otherwise, so no page comes along
uninvited. A page whose references nest deeper than 2,048 values is
refused with `zupdf_write_error`.

## Examples

``` r
src <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
w <- pdf_new()
pdf_copy_pages(w, src, pages = c(2, 1), rotate = 90)
out <- pdf_open(pdf_save(w))
pdf_pages(out)$rotate
#> [1] 90 90
pdf_close(out)
pdf_close(src)
```
