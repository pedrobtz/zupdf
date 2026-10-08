# One image's samples

Reads an image XObject. With `as = "raw"` the samples come back as
bytes: decoded when the filter is `FlateDecode` or none, and as stored
otherwise, so a JPEG (`DCTDecode`) image is its JPEG file, for
`jpeg::readJPEG()`. zupdf decodes no JPEG itself. With `as = "native"`,
an 8-bit `DeviceRGB` or `DeviceGray` image (or `ICCBased` with 3 or 1
components) that zupdf can decode comes back as a `nativeRaster`, for
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
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
imgs <- pdf_page_images(pdf, 1)
imgs
#> [1] object      name        width       height      bits        color_space
#> [7] filter     
#> <0 rows> (or 0-length row.names)
pdf_close(pdf)
```
