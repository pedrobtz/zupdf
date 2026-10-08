# Measure text

The width of each string in points, as
[`pdf_draw_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_text.md)
would draw it in `font` at `size`: from the base-14 metrics or the
embedded font's glyphs. zupdf does no text layout; this is what layout
needs, such as wrapping a paragraph to a column.

## Usage

``` r
pdf_text_width(w, text, font = "Helvetica", size = 12)
```

## Arguments

- w:

  A `pdf_writer` from
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md).

- text:

  Strings, UTF-8.

- font:

  A base-14 font name, a font file path, or a font from
  [`pdf_font()`](https://pedrobtz.github.io/zupdf/reference/pdf_font.md).

- size:

  The font size in points.

## Value

A numeric vector of widths in points.

## Examples

``` r
w <- pdf_new()
pdf_text_width(w, c("narrow", "a much wider string"), size = 12)
#> [1]  36.672 104.028
```
