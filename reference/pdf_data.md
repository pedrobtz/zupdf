# Words and their positions

pdftools's `pdf_data()`: one data frame per page, a row per word, with
the word's box and whether a space follows it. Words come from zupdf's
text walk
([`pdf_page_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_text.md)):
glyphs on one baseline, in their writing direction, split at spaces and
at gaps of a word space or more, in reading order. Boxes are in points
from the top left, as pdftools gives them, each rounded to whole points:
the box around the word's glyphs, each glyph its advance from the font's
descent to its ascent (from the font descriptor, a Type 3 font's
bounding box, or the base-14 metrics). They agree with poppler's to
within a point or two.

## Usage

``` r
pdf_data(pdf, font_info = FALSE, opw = "", upw = "")
```

## Arguments

- pdf:

  A path, a raw vector, or an open `pdf_file`.

- font_info:

  `TRUE` to add each word's `font_name` and `font_size`.

- opw, upw:

  The owner and user passwords; `""` for none.

## Value

A list with a data frame per page, with columns `width`, `height`, `x`,
`y`, `space` and `text`, and with `font_info`, `font_name` and
`font_size`.

## Examples

``` r
path <- system.file("examples", "hello.pdf", package = "zupdf")
pdf_data(path)[[1]]
#> # A tibble: 3 × 6
#>   width height     x     y space text  
#>   <int>  <int> <int> <int> <lgl> <chr> 
#> 1    27     11    72    63 TRUE  Hello 
#> 2    24     11   103    63 TRUE  from  
#> 3    33     11   130    63 FALSE zupdf.
```
