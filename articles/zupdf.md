# Inspecting a PDF

zupdf reads PDF files through the bundled pdfio library. It never
renders a page to pixels; everything else a PDF holds, it can read.

``` r

library(zupdf)
path <- system.file("examples", "hello.pdf", package = "zupdf")
pdf <- pdf_open(path)
pdf
#> <pdf_file>
#>   /home/runner/work/_temp/Library/zupdf/examples/hello.pdf
#>   PDF 1.4, 2 pages, not encrypted
```

[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md)
reads only the cross-reference table, so opening is cheap; each function
then reads what it needs. A raw vector or a connection works as well as
a path.

## The document

``` r

str(pdf_meta(pdf))
#> List of 14
#>  $ version    : chr "1.4"
#>  $ pages      : int 2
#>  $ title      : chr "Hello"
#>  $ author     : chr "zupdf"
#>  $ subject    : chr NA
#>  $ keywords   : chr NA
#>  $ creator    : chr NA
#>  $ producer   : chr NA
#>  $ language   : chr NA
#>  $ created    : POSIXct[1:1], format: NA
#>  $ modified   : POSIXct[1:1], format: NA
#>  $ id         : chr(0) 
#>  $ encryption : chr "none"
#>  $ permissions: chr [1:8] "print" "modify" "copy" "annotate" ...
pdf_pages(pdf)
#>   page width height rotate      media_box       crop_box streams
#> 1    1   612    792      0 0, 0, 612, 792 0, 0, 612, 792       1
#> 2    2   612    792      0 0, 0, 612, 792 0, 0, 612, 792       1
```

## Text

[`pdf_page_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_text.md)
follows each page’s content stream, maps every character through its
font, and lays the text out in reading order, or in the order the stream
draws it:

``` r

pdf_page_text(pdf)
#> [1] "Hello from zupdf." "Page two."        
#> attr(,"unmapped")
#> [1] 0 0
pdf_page_text(pdf, pages = 1, layout = "raw")
#> [1] "Hello from zupdf."
#> attr(,"unmapped")
#> [1] 0
```

A character no font maps comes back as U+FFFD and is counted in the
`unmapped` attribute.

## Objects and streams

Every object is reachable, as R values: dictionaries are named lists,
names carry the class `pdf_name`, references `pdf_ref`.

``` r

pdf_objects(pdf)
#>   number generation    type subtype length
#> 1      1          0 Catalog    <NA>     NA
#> 2      2          0   Pages    <NA>     NA
#> 3      3          0    Font   Type1     NA
#> 4      4          0    Page    <NA>     NA
#> 5      5          0    <NA>    <NA>     48
#> 6      6          0    Page    <NA>     NA
#> 7      7          0    <NA>    <NA>     40
#> 8      8          0    <NA>    <NA>     NA
pdf_object(pdf, 4)
#> $Contents
#> 5 0 R
#> 
#> $MediaBox
#> $MediaBox[[1]]
#> [1] 0
#> 
#> $MediaBox[[2]]
#> [1] 0
#> 
#> $MediaBox[[3]]
#> [1] 612
#> 
#> $MediaBox[[4]]
#> [1] 792
#> 
#> 
#> $Parent
#> 2 0 R
#> 
#> $Resources
#> $Resources$Font
#> $Resources$Font$F1
#> 3 0 R
#> 
#> 
#> 
#> $Type
#> /Page
rawToChar(pdf_stream(pdf, 5))
#> [1] "BT /F1 12 Tf 72 720 Td (Hello from zupdf.) Tj ET"
pdf_page_tokens(pdf, 1)
#>        type             value
#> 1  operator                BT
#> 2      name                F1
#> 3    number                12
#> 4  operator                Tf
#> 5    number                72
#> 6    number               720
#> 7  operator                Td
#> 8    string Hello from zupdf.
#> 9  operator                Tj
#> 10 operator                ET
```

## Untrusted files

A PDF is a common carrier of hostile input.
[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md)
takes limits on the input size, the number of objects and pages, the
size of any decoded stream, and the depth of nesting; reaching one is a
`zupdf_limit_error`:

``` r

tryCatch(
  pdf_open(path, max_pages = 1),
  zupdf_limit_error = function(e) conditionMessage(e)
)
#> [1] "The PDF file has more pages than `max_pages` (1)."
pdf_close(pdf)
```
