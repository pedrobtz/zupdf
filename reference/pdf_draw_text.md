# Draw text

Draws text on a page with its baseline starting at (`x`, `y`), in PDF
points from the bottom left. `x`, `y` and `text` are recycled, so one
call can draw many strings; a string with line breaks is drawn as lines
`line_height` times the size apart. zupdf does not wrap text.

## Usage

``` r
pdf_draw_text(
  page,
  x,
  y,
  text,
  font = "Helvetica",
  size = 12,
  ...,
  colour = "black",
  align = c("left", "centre", "right"),
  line_height = 1.2
)
```

## Arguments

- page:

  A `pdf_page` from
  [`pdf_page_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md).

- x, y:

  The start of the baseline, in points.

- text:

  The text, UTF-8.

- font:

  A base-14 font name, a font file path, or a font from
  [`pdf_font()`](https://pedrobtz.github.io/zupdf/reference/pdf_font.md).

- size:

  The font size in points.

- ...:

  Must be empty.

- colour:

  The text colour, any colour R knows.

- align:

  `"left"`, `"centre"` or `"right"`: where `x` is on the line.

- line_height:

  The distance between lines, in multiples of `size`.

## Value

`page`, invisibly.

## Examples

``` r
w <- pdf_new()
page <- pdf_page_new(w)
pdf_draw_text(page, 297, 800, "Centred", size = 20, align = "centre")
pdf_draw_text(page, 72, 700, "Two\nlines", colour = "navy")
pdf_page_end(page)
bytes <- pdf_save(w)
```
