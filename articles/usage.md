# A tour of zupdf

This article runs through the main things zupdf does, in one session:
write a PDF, read it back, take it apart and put it together again, lock
it, and use the pdftools and qpdf names. Each step has its own guide for
the details.

``` r

library(zupdf)
dir <- tempfile("tour-")
dir.create(dir)
```

## Write a PDF

A writer collects pages. Each page records what is drawn on it, text,
paths and images, and
[`pdf_page_end()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md)
writes it.
[`pdf_save()`](https://pedrobtz.github.io/zupdf/reference/pdf_save.md)
returns the bytes, or writes them to a file.

``` r

w <- pdf_new(media_box = pdf_paper("a4"))
pdf_set_meta(w, title = "Ring of Fire", author = "zupdf")

page <- pdf_page_new(w)
pdf_draw_text(page, 297.6, 780, "Maunga Whau", font = "Helvetica-Bold",
  size = 24, align = "centre")
pdf_draw_text(page, 72, 740, "Heights of a volcano in Auckland, from R's volcano data.",
  font = "Times-Roman", size = 12)

# An image from an R matrix of grey levels between 0 and 1, one row per line
# of pixels: 61 lines of 87 pixels, the shape of the box it is drawn into.
heights <- t(volcano - min(volcano)) / diff(range(volcano))
img <- pdf_image_new(w, heights)
pdf_draw_image(page, img, 72, 380, 451, 316)

# Paths: a frame round the image and a triangle.
pdf_draw(page, data.frame(op = "rect", x = 72, y = 380, w = 451, h = 316),
  stroke = "grey30")
pdf_draw(page, list(x = c(260, 335, 297.6), y = c(250, 250, 330)),
  fill = "firebrick", close = TRUE)
pdf_page_end(page)

page <- pdf_page_new(w)
pdf_draw_text(page, 72, 760, "Page two", size = 18)
pdf_draw_text(page, 72, 730, "A second page, to have something to rearrange.")
pdf_page_end(page)

report <- file.path(dir, "report.pdf")
pdf_save(w, report)
```

Fonts are the 14 standard PDF fonts by name, or a TrueType or OpenType
file given to
[`pdf_font()`](https://pedrobtz.github.io/zupdf/reference/pdf_font.md),
which embeds it.
[`pdf_text_width()`](https://pedrobtz.github.io/zupdf/reference/pdf_text_width.md)
measures text, for laying out lines:
[`vignette("writing")`](https://pedrobtz.github.io/zupdf/articles/writing.md)
builds a paged report from it.

## Read it back

[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md)
takes a path, a raw vector or a connection. It reads only the
cross-reference table; each function then reads what it needs.

``` r

pdf <- pdf_open(report)
pdf_meta(pdf)[c("version", "pages", "title", "author")]
#> $version
#> [1] "1.7"
#> 
#> $pages
#> [1] 2
#> 
#> $title
#> [1] "Ring of Fire"
#> 
#> $author
#> [1] "zupdf"
pdf_pages(pdf)[, c("page", "width", "height", "rotate")]
#>   page  width height rotate
#> 1    1 595.28 841.89      0
#> 2    2 595.28 841.89      0
```

Text comes back per page, in reading order:

``` r

cat(pdf_page_text(pdf, pages = 1))
#> Maunga Whau
#> Heights of a volcano in Auckland, from R's volcano data.
```

Fonts and images.
[`pdf_image()`](https://pedrobtz.github.io/zupdf/reference/pdf_image.md)
returns an image’s samples, or, for 8-bit grey and RGB, a `nativeRaster`
R can draw:

``` r

pdf_font_table(pdf)
#>   object           name  type embedded
#> 1      5 Helvetica-Bold Type1    FALSE
#> 2      6    Times-Roman Type1    FALSE
#> 3     14      Helvetica Type1    FALSE
imgs <- pdf_page_images(pdf, 1)
imgs
#>   object name width height bits color_space      filter
#> 1      7  Im3    87     61    8  DeviceGray FlateDecode
grey <- pdf_image(pdf, imgs$object[1], as = "native")
dim(grey)
#> [1] 61 87
grid::grid.raster(grey, interpolate = FALSE)
```

![The volcano image, read back from the
PDF](usage_files/figure-html/unnamed-chunk-6-1.png)

Underneath, every object is reachable as R values:
[`pdf_objects()`](https://pedrobtz.github.io/zupdf/reference/pdf_objects.md),
[`pdf_object()`](https://pedrobtz.github.io/zupdf/reference/pdf_object.md)
and
[`pdf_stream()`](https://pedrobtz.github.io/zupdf/reference/pdf_stream.md),
covered in
[`vignette("zupdf")`](https://pedrobtz.github.io/zupdf/articles/zupdf.md).

## Words and where they are

[`pdf_data()`](https://pedrobtz.github.io/zupdf/reference/pdf_data.md)
gives each word with its box, in points from the top left, as pdftools
does:

``` r

head(pdf_data(report)[[1]])
#>   width height   x  y space    text
#> 1    91     22 216 45  TRUE  Maunga
#> 2    65     22 314 45 FALSE    Whau
#> 3    37     11  72 94  TRUE Heights
#> 4    10     11 112 94  TRUE      of
#> 5     5     11 125 94  TRUE       a
#> 6    38     11 134 94  TRUE volcano
```

## Take it apart, put it together

Splitting, merging, reordering and rotating are all one operation:
copying pages from open files into a new writer. Each copied page brings
the fonts and images it uses.

``` r

w <- pdf_new()
pdf_copy_pages(w, pdf, pages = 2)               # page two first
pdf_copy_pages(w, pdf, pages = 1, rotate = 90)  # then page one, turned
pdf_set_meta(w, title = "Rearranged")
rearranged <- pdf_open(pdf_save(w))
pdf_pages(rearranged)[, c("page", "rotate")]
#>   page rotate
#> 1    1      0
#> 2    2     90
pdf_close(rearranged)
```

[`vignette("assembling")`](https://pedrobtz.github.io/zupdf/articles/assembling.md)
has more, including pages from several files.

## Lock it

Encryption is set on the writer before any page is added. Permissions
say what a reader that honours them may do.

``` r

w <- pdf_new()
pdf_set_encryption(w, user = "open sesame", owner = "admin",
  permissions = c("print", "copy"))
pdf_copy_pages(w, pdf)
locked <- file.path(dir, "locked.pdf")
pdf_save(w, locked)

tryCatch(pdf_open(locked), zupdf_password_error = function(e) "a password is needed")
#> [1] "a password is needed"
secret <- pdf_open(locked, password = "open sesame")
pdf_meta(secret)[c("encryption", "permissions")]
#> $encryption
#> [1] "aes-128"
#> 
#> $permissions
#> [1] "print" "copy"
pdf_close(secret)
pdf_close(pdf)
```

## The pdftools and qpdf names

Code written for pdftools or qpdf runs with
[`library(zupdf)`](https://github.com/pedrobtz/zupdf) in their place,
for everything but rendering: the same function names, arguments and
results.

``` r

pdf_info(report)$pages
#> [1] 2
substr(pdf_text(report)[1], 1, 40)
#> [1] "Maunga Whau\nHeights of a volcano in Auck"
pdf_length(report)
#> [1] 2

both <- pdf_combine(c(report, report), output = file.path(dir, "both.pdf"))
pdf_length(both)
#> [1] 4
first <- pdf_subset(both, pages = 1, output = file.path(dir, "first.pdf"))
pdf_length(first)
#> [1] 1
```

[`vignette("switching")`](https://pedrobtz.github.io/zupdf/articles/switching.md)
lists what is covered, where results differ, and what happens when both
packages are attached.

## Untrusted files

A PDF from elsewhere may be built to cause harm.
[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md)
bounds the input size, the numbers of objects and pages, the size of any
decoded stream and the depth of nesting. Going past a limit, a damaged
file and a wrong password are each their own condition class, under
`zupdf_error`:

``` r

tryCatch(
  pdf_open(report, max_pages = 1),
  zupdf_limit_error = function(e) class(e)
)
#> [1] "zupdf_limit_error" "zupdf_error"       "error"            
#> [4] "condition"
tryCatch(
  pdf_open(charToRaw("not a PDF")),
  zupdf_error = function(e) class(e)
)
#> [1] "zupdf_parse_error" "zupdf_error"       "error"            
#> [4] "condition"
```

`?zupdf-conditions` lists them all.
