# Images on a page

Lists the images in a page's resources: the image XObjects it can draw.
Images inside Form XObjects and inline images are not listed.

## Usage

``` r
pdf_page_images(pdf, i)
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

- i:

  A page number.

## Value

A data frame with columns `object` (for
[`pdf_image()`](https://pedrobtz.github.io/zupdf/reference/pdf_image.md)),
`name` (the resource name the content stream uses), `width`, `height`,
`bits` (bits per component), `color_space` (such as `"DeviceRGB"`, or
the family of an array colour space, such as `"ICCBased"`) and `filter`
(the last filter, such as `"DCTDecode"` for JPEG, or `NA`).

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_page_images(pdf, 1)
#> [1] object      name        width       height      bits        color_space
#> [7] filter     
#> <0 rows> (or 0-length row.names)
pdf_close(pdf)
```
