# Document metadata for the writer

Sets the written file's information: title, author, subject, keywords,
creator, language and modification date. Text may be any Unicode; it is
written so that every reader decodes it. The creation date is
[`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md)'s
`created`.

## Usage

``` r
pdf_set_meta(w, ...)
```

## Arguments

- w:

  A `pdf_writer` from
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md).

- ...:

  Named values: `title`, `author`, `subject`, `keywords`, `creator` and
  `language` (such as `"en-GB"`) are strings; `modified` is a `POSIXct`.

## Value

`w`, invisibly.

## Examples

``` r
w <- pdf_new()
pdf_set_meta(w, title = "A report", author = "Me", language = "en-GB")
pdf_page_end(pdf_page_new(w))
out <- pdf_open(pdf_save(w))
pdf_meta(out)[c("title", "author", "language")]
#> $title
#> [1] "A report"
#> 
#> $author
#> [1] "Me"
#> 
#> $language
#> [1] "en-GB"
#> 
pdf_close(out)
```
