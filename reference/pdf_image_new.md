# Images for the writer

Makes an image object a writer can draw with
[`pdf_draw_image()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_image.md):
from a PNG or JPEG file (JPEG data is copied as it is), or from an R
image: a `nativeRaster`, a `raster` or character matrix of colours, a
numeric matrix of grey levels in 0 to 1, or a numeric array of height x
width x 3 (RGB) or 4 (RGBA) channels in 0 to 1, such as `png::readPNG()`
returns. Transparency is kept.

## Usage

``` r
pdf_image_new(w, x, interpolate = TRUE)
```

## Arguments

- w:

  A `pdf_writer` from
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md).

- x:

  A path, or an image as above.

- interpolate:

  `TRUE` to let viewers smooth the image when scaling.

## Value

A `pdf_writer_image` with the image's `width` and `height` in pixels.

## Examples

``` r
w <- pdf_new()
img <- pdf_image_new(w, as.raster(matrix(c("red", "blue"), 1)))
page <- pdf_page_new(w)
pdf_draw_image(page, img, 72, 600, 200, 100)
pdf_page_end(page)
bytes <- pdf_save(w)
```
