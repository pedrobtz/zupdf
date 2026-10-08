# Draw images

Draws an image from
[`pdf_image_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_image_new.md)
into the rectangle with its lower left corner at (`x`, `y`), `width` by
`height` points.

## Usage

``` r
pdf_draw_image(page, image, x, y, width, height)
```

## Arguments

- page:

  A `pdf_page` from
  [`pdf_page_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md).

- image:

  A `pdf_writer_image`.

- x, y:

  The start of the baseline, in points.

- width, height:

  The size on the page, in points.

## Value

`page`, invisibly.

## Examples

``` r
w <- pdf_new()
img <- pdf_image_new(w, matrix(seq(0, 1, length.out = 16), 4))
page <- pdf_page_new(w)
pdf_draw_image(page, img, 72, 500, 144, 144)
pdf_page_end(page)
bytes <- pdf_save(w)
```
