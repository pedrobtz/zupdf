# Pages for the writer

`pdf_page_new()` starts a page; drawing functions record onto it; and
`pdf_page_end()` writes it, after the pages already ended. Several pages
may be open at once.
[`pdf_save()`](https://pedrobtz.github.io/zupdf/reference/pdf_save.md)
refuses a writer with a page not ended.

## Usage

``` r
pdf_page_new(w, media_box = NULL, crop_box = NULL, dict = NULL)

pdf_page_end(page)
```

## Arguments

- w:

  A `pdf_writer` from
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md).

- media_box, crop_box:

  The page's boxes, `c(x1, y1, x2, y2)` in points, or `NULL` for the
  writer's default size.

- dict:

  `NULL`, or a named list of further page dictionary entries as R values
  (see
  [`pdf_object()`](https://pedrobtz.github.io/zupdf/reference/pdf_object.md)
  for the mapping), such as `list(Rotate = 90L)`. A `pdf_ref` is an
  object number in the file being written: one read from another file
  names whatever object has its number here. Use
  [`pdf_copy_pages()`](https://pedrobtz.github.io/zupdf/reference/pdf_copy_pages.md)
  to bring pages across.

- page:

  A `pdf_page`.

## Value

`pdf_page_new()`: a `pdf_page`. `pdf_page_end()`: the page, invisibly.

## Details

A page ends even when `pdf_page_end()` raises an error: it is then
missing from the file, or in it only in part, and cannot be ended again,
but the writer can still be saved.

## Examples

``` r
w <- pdf_new()
page <- pdf_page_new(w, media_box = pdf_paper("a6"))
pdf_draw_text(page, 20, 380, "A small page")
pdf_page_end(page)
bytes <- pdf_save(w)
```
