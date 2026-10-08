# Draw paths

Draws a path and fills it, strokes it, or both. A path is either points,
joined by straight lines (a data frame or list with `x` and `y`), or a
data frame of operations: column `op` is one of `"move"`, `"line"`,
`"curve"`, `"close"` or `"rect"`; `"move"` and `"line"` use `x` and `y`;
`"curve"` draws a cubic Bezier curve through control points `x1`, `y1`
and `x2`, `y2` to `x`, `y`; `"rect"` draws a rectangle with corner `x`,
`y` and size `w`, `h`. Coordinates are PDF points from the bottom left.

## Usage

``` r
pdf_draw(
  page,
  path,
  fill = NULL,
  stroke = NULL,
  width = 1,
  ...,
  close = FALSE,
  rule = c("winding", "evenodd")
)
```

## Arguments

- page:

  A `pdf_page` from
  [`pdf_page_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md).

- path:

  The path, as above.

- fill, stroke:

  Colours, or `NULL` for none. With neither, the path is stroked in
  black.

- width:

  The line width in points.

- ...:

  Must be empty.

- close:

  `TRUE` to close a path given as points.

- rule:

  The fill rule, `"winding"` or `"evenodd"`.

## Value

`page`, invisibly.

## Examples

``` r
w <- pdf_new()
page <- pdf_page_new(w)
pdf_draw(page, list(x = c(72, 300, 186), y = c(600, 600, 750)),
  fill = "gold", stroke = "black", close = TRUE)
pdf_draw(page, data.frame(op = "rect", x = 72, y = 400, w = 200, h = 100),
  fill = "steelblue")
pdf_page_end(page)
bytes <- pdf_save(w)
```
