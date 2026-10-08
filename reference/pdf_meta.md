# Document metadata

Reads the document's version, page count, information dictionary,
identifier, encryption and permissions.

## Usage

``` r
pdf_meta(pdf)
```

## Arguments

- pdf:

  A `pdf_file` from
  [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md).

## Value

A list with elements:

- `version`: the PDF version, such as `"1.7"`.

- `pages`: the page count.

- `title`, `author`, `subject`, `keywords`, `creator`, `producer`,
  `language`: strings, `NA` where absent.

- `created`, `modified`: `POSIXct` in UTC, `NA` where absent.

- `id`: the file identifier, two hexadecimal strings, or
  [`character()`](https://rdrr.io/r/base/character.html).

- `encryption`: one of `"none"`, `"rc4-40"`, `"rc4-128"`, `"aes-128"`,
  `"aes-256"`.

- `permissions`: what the file allows, a subset of `"print"`,
  `"modify"`, `"copy"`, `"annotate"`, `"forms"`, `"reading"`,
  `"assemble"`, `"print_high"`.

## Details

Strings are returned as UTF-8: pdfio converts UTF-16 strings as it reads
them, and a string that is not valid UTF-8 is read as PDFDocEncoding.

## Examples

``` r
pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
pdf_meta(pdf)
#> $version
#> [1] "1.4"
#> 
#> $pages
#> [1] 2
#> 
#> $title
#> [1] "Hello"
#> 
#> $author
#> [1] "zupdf"
#> 
#> $subject
#> [1] NA
#> 
#> $keywords
#> [1] NA
#> 
#> $creator
#> [1] NA
#> 
#> $producer
#> [1] NA
#> 
#> $language
#> [1] NA
#> 
#> $created
#> [1] NA
#> 
#> $modified
#> [1] NA
#> 
#> $id
#> character(0)
#> 
#> $encryption
#> [1] "none"
#> 
#> $permissions
#> [1] "print"      "modify"     "copy"       "annotate"   "forms"     
#> [6] "reading"    "assemble"   "print_high"
#> 
pdf_close(pdf)
```
