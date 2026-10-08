# Fonts for the writer

Makes a font object a writer can draw text with. A base-14 font is named
(such as `"Helvetica"` or `"Times-Bold"`) and not embedded; it shows the
characters of Windows code page 1252 and prints `?` for others. A
TrueType or OpenType file is embedded, with the glyphs the text uses,
and shows any character it has. There is no system font lookup: give the
path.

## Usage

``` r
pdf_font(w, x)
```

## Arguments

- w:

  A `pdf_writer` from
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md).

- x:

  A base-14 font name or a path to a `.ttf` or `.otf` file.

## Value

A `pdf_writer_font`.

## Details

[`pdf_draw_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_text.md)
also takes a base-14 name or a path directly and makes the font the
first time.

## Examples

``` r
w <- pdf_new()
bold <- pdf_font(w, "Helvetica-Bold")
page <- pdf_page_new(w)
pdf_draw_text(page, 72, 750, "A heading", font = bold, size = 16)
pdf_page_end(page)
bytes <- pdf_save(w)
```
