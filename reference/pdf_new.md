# Start a new PDF file

Creates a writer. Add pages with
[`pdf_page_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md),
draw on them, end each with
[`pdf_page_end()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md),
and finish with
[`pdf_save()`](https://pedrobtz.github.io/zupdf/reference/pdf_save.md).
Fonts and images are made once with
[`pdf_font()`](https://pedrobtz.github.io/zupdf/reference/pdf_font.md)
and
[`pdf_image_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_image_new.md)
and drawn on any page.

## Usage

``` r
pdf_new(
  version = "2.0",
  media_box = pdf_paper("a4"),
  created = Sys.time(),
  deterministic = FALSE,
  ...
)
```

## Arguments

- version:

  The PDF version to write, such as `"1.7"` or `"2.0"`.

- media_box:

  The default page size, `c(x1, y1, x2, y2)` in points; see
  [`pdf_paper()`](https://pedrobtz.github.io/zupdf/reference/pdf_paper.md).

- created:

  The creation date, a `POSIXct`.

- deterministic:

  `TRUE` to derive the file identifier from the content.

- ...:

  Must be empty.

## Value

A `pdf_writer`.

## Details

Two things in a PDF normally come from the clock and the random source:
the creation date and the file identifier. The date is always `created`.
With `deterministic = TRUE` the identifier is a hash of the file's
content, so the same calls produce the same bytes, which tests and
reproducible builds can pin. Encrypted files are never byte-stable,
since their keys are random.

## See also

[`pdf_draw_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_text.md),
[`pdf_draw()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw.md),
[`pdf_draw_image()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_image.md).

## Examples

``` r
w <- pdf_new(media_box = pdf_paper("a5"))
page <- pdf_page_new(w)
pdf_draw_text(page, 72, 500, "Hello from zupdf.", size = 18)
pdf_page_end(page)
bytes <- pdf_save(w)
pdf <- pdf_open(bytes)
pdf_page_text(pdf)
#> [1] "Hello from zupdf."
#> attr(,"unmapped")
#> [1] 0
pdf_close(pdf)
```
