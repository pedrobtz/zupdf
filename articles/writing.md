# Writing a report from R

zupdf writes PDF files page by page: text, paths and images where you
put them. It does no text layout of its own, which this vignette shows
is a short function away. The approach follows pdfio’s `md2pdf` example:
measure words, wrap them to the column, and start a new page when the
column is full.

``` r

library(zupdf)

# Splits a paragraph into lines no wider than `width` points.
wrap <- function(w, text, width, font, size) {
  words <- strsplit(text, " ", fixed = TRUE)[[1]]
  lines <- character()
  line <- ""
  for (word in words) {
    candidate <- if (nzchar(line)) paste(line, word) else word
    if (pdf_text_width(w, candidate, font = font, size = size) > width && nzchar(line)) {
      lines <- c(lines, line)
      line <- word
    } else {
      line <- candidate
    }
  }
  c(lines, line)
}

# A report: a list of headings and paragraphs, laid out on A4 pages.
report <- function(blocks, file = NULL) {
  w <- pdf_new(media_box = pdf_paper("a4"), deterministic = TRUE)
  margin <- 56
  width <- 595.28 - 2 * margin
  page <- NULL
  y <- 0
  new_page <- function() {
    if (!is.null(page)) pdf_page_end(page)
    page <<- pdf_page_new(w)
    y <<- 841.89 - margin
  }
  new_page()
  for (b in blocks) {
    heading <- identical(b$type, "heading")
    font <- if (heading) "Helvetica-Bold" else "Times-Roman"
    size <- if (heading) 16 else 11
    lines <- wrap(w, b$text, width, font, size)
    for (line in lines) {
      if (y - size < margin) new_page()
      y <- y - size * 1.4
      pdf_draw_text(page, margin, y, line, font = font, size = size)
    }
    y <- y - size * 0.6
  }
  pdf_page_end(page)
  pdf_save(w, file)
}

para <- paste(
  "PDF files are everywhere, and R users meet them at both ends: as input",
  "to extract from, and as output to share. zupdf reads and writes them",
  "through the pdfio library, with no system library beyond zlib."
)
blocks <- c(
  list(list(type = "heading", text = "A small report")),
  rep(list(list(type = "paragraph", text = para)), 30)
)
bytes <- report(blocks)
pdf <- pdf_open(bytes)
length(pdf)
#> [1] 2
substr(pdf_page_text(pdf, pages = 1), 1, 200)
#> [1] "A small report\nPDF files are everywhere, and R users meet them at both ends: as input to extract from, and as output to\nshare. zupdf reads and writes them through the pdfio library, with no system lib"
#> attr(,"unmapped")
#> [1] 0
pdf_close(pdf)
```

## Drawing

Paths are points, or operations; colours are any R colour.

``` r

w <- pdf_new(media_box = pdf_paper("a5"))
page <- pdf_page_new(w)
pdf_draw(page, list(x = c(60, 360, 210), y = c(300, 300, 520)),
  fill = "gold", stroke = "black", close = TRUE)
pdf_draw(page, data.frame(op = "rect", x = 60, y = 80, w = 300, h = 150),
  fill = "steelblue")
pdf_draw_text(page, 210, 560, "Shapes", size = 24, align = "centre")
pdf_draw_image(page, pdf_image_new(w, as.raster(matrix(c("red", "white", "white", "red"), 2))),
  320, 520, 40, 40)
pdf_page_end(page)
length(pdf_save(w))
#> [1] 11043
```

Fonts are the 14 standard ones by name, or a TrueType or OpenType file
by path, which is embedded with the glyphs used; there is no system font
lookup. `deterministic = TRUE` makes the same calls give the same bytes.
