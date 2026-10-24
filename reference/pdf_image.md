# One image's samples

Reads an image XObject. With `as = "raw"` the samples come back as
bytes: decoded when the filter is `FlateDecode` or none, and as stored
otherwise, so a JPEG (`DCTDecode`) image is its JPEG file, for
[`jpeg::readJPEG()`](https://rdrr.io/pkg/jpeg/man/readJPEG.html). zupdf
decodes no JPEG itself. With `as = "native"`, an 8-bit `DeviceRGB` or
`DeviceGray` image (or `ICCBased` with 3 or 1 components) that zupdf can
decode comes back as a `nativeRaster`, for
[`grid::grid.raster()`](https://rdrr.io/r/grid/grid.raster.html) or
[`graphics::rasterImage()`](https://rdrr.io/r/graphics/rasterImage.html).

## Usage

``` r
pdf_image(pdf, n, as = c("raw", "native"))
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

- n:

  An object number, as in
  [`pdf_objects()`](https://pedrobtz.github.io/zupdf/reference/pdf_objects.md)'s
  `number` column.

- as:

  `"raw"` or `"native"`.

## Value

For `"raw"`, a raw vector with attributes `width`, `height`, `bits`,
`color_space`, `filter` and `decoded`. For `"native"`, a `nativeRaster`.

## Examples

``` r
w <- pdf_new()
img <- pdf_image_new(w, as.raster(matrix(c("red", "blue"), 1)))
page <- pdf_page_new(w)
pdf_draw_image(page, img, 72, 600, 200, 100)
pdf_page_end(page)
pdf <- pdf_open(pdf_save(w))
n <- pdf_page_images(pdf, 1)$object
pdf_image(pdf, n, as = "raw")
#> [1] ff 00 00 00 00 ff
#> attr(,"width")
#> [1] 2
#> attr(,"height")
#> [1] 1
#> attr(,"bits")
#> [1] 8
#> attr(,"color_space")
#> [1] "DeviceRGB"
#> attr(,"filter")
#> [1] "FlateDecode"
#> attr(,"decoded")
#> [1] TRUE
pdf_image(pdf, n, as = "native")
#>           [,1]   [,2]
#> [1,] -16776961 -65536
#> attr(,"class")
#> [1] "nativeRaster"
#> attr(,"channels")
#> [1] 4
pdf_close(pdf)
```
