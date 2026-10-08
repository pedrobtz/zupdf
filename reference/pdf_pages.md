# Page sizes and rotation

One row per page, from each page's dictionary and the attributes it
inherits from the page tree (`MediaBox`, `CropBox`, `Rotate`).

## Usage

``` r
pdf_pages(pdf)
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

## Value

A data frame with columns `page`, `width`, `height`, `rotate` (0, 90,
180 or 270, clockwise), `media_box` and `crop_box` (list columns of four
numbers, `NA` when the file gives none) and `streams` (the number of
content streams).

## Details

Boxes are `c(x1, y1, x2, y2)` in PDF points (1/72 inch), with the origin
at the bottom left. The crop box defaults to the media box and is
clipped to it. `width` and `height` are the crop box's, before rotation.

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_pages(pdf)
#>   page width height rotate      media_box       crop_box streams
#> 1    1   612    792      0 0, 0, 612, 792 0, 0, 612, 792       1
#> 2    2   612    792      0 0, 0, 612, 792 0, 0, 612, 792       1
pdf_close(pdf)
```
