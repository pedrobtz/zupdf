# Assembling PDFs

Splitting, merging, reordering and rotating are one operation in zupdf:
copying pages from open files into a new one with
[`pdf_copy_pages()`](https://pedrobtz.github.io/zupdf/reference/pdf_copy_pages.md).
Each copied page brings the fonts, images and forms it uses, so the
result stands alone.

``` r

library(zupdf)
src <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
w <- pdf_new()
pdf_copy_pages(w, src, pages = c(2, 1))   # reverse the pages
pdf_copy_pages(w, src, pages = 1, rotate = 90)
out <- pdf_open(pdf_save(w))
pdf_pages(out)[, c("page", "rotate")]
#>   page rotate
#> 1    1      0
#> 2    2      0
#> 3    3     90
pdf_page_text(out)
#> [1] "Page two."         "Hello from zupdf." "Hello from zupdf."
#> attr(,"unmapped")
#> [1] 0 0 0
pdf_close(out)
```

## Metadata and encryption

[`pdf_set_meta()`](https://pedrobtz.github.io/zupdf/reference/pdf_set_meta.md)
sets the document information.
[`pdf_set_encryption()`](https://pedrobtz.github.io/zupdf/reference/pdf_set_encryption.md)
must come first, before any page: it fixes the keys.

``` r

w <- pdf_new()
pdf_set_encryption(w, user = "secret", permissions = c("print", "copy"))
pdf_set_meta(w, title = "Two pages", author = "zupdf")
pdf_copy_pages(w, src)
bytes <- pdf_save(w)
locked <- pdf_open(bytes, password = "secret")
pdf_meta(locked)[c("title", "encryption", "permissions")]
#> $title
#> [1] "Two pages"
#> 
#> $encryption
#> [1] "aes-128"
#> 
#> $permissions
#> [1] "print" "copy"
pdf_close(locked)
pdf_close(src)
```

## The qpdf way

The same operations exist under qpdf’s names and arguments, working on
files:

``` r

dir <- tempfile()
dir.create(dir)
file.copy(system.file("examples", "hello.pdf", package = "zupdf"), dir)
#> [1] TRUE
input <- file.path(dir, "hello.pdf")
basename(pdf_split(input))
#> [1] "hello_1.pdf" "hello_2.pdf"
pdf_length(pdf_combine(c(input, input)))
#> [1] 4
```
