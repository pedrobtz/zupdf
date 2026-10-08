# Build information

Reports the bundled pdfio version, the patches applied to it, the zlib
it was linked against, the pdfio features this build lacks, and the
default limits.

## Usage

``` r
zupdf_info()
```

## Value

A list of class `zupdf_info` with elements:

- `pdfio_version`: version of the bundled pdfio, e.g. `"1.6.5"`. Its
  `ttf` library ships inside the same release.

- `patches`: the local patches applied to it, in order.

- `zlib_version`: version of the zlib linked at build time.

- `absent`: features of later pdfio releases this build lacks, such as
  `"lzw"` decoding.

- `limits`: the default `max_size`, `max_objects`, `max_stream`,
  `max_depth` and `max_pages` of
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

- `smoke_ok`: `TRUE` if the bundled pdfio wrote a one-page file in
  memory.

## Examples

``` r
zupdf_info()
#> <zupdf_info>
#> pdfio:       1.6.5
#> patches:     0001-visibility-override, 0002-no-stdio, 0003-date-buffer, 0004-undefined-behaviour
#> zlib:        1.3
#> absent:      lzw, gif, object_streams, page_accessors, windows_unicode_paths
#> max_size:    1073741824 bytes
#> max_objects: 1000000
#> max_stream:  268435456 bytes
#> max_depth:   64
#> max_pages:   100000
#> self-test:   ok
```
