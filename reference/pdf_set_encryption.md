# Encrypt the written file

Encrypts the file the writer will produce and sets what readers may do
with it. Call it first, before any page, font or image: pdfio fixes the
keys before the first object is written.

## Usage

``` r
pdf_set_encryption(
  w,
  user = NULL,
  owner = NULL,
  method = c("aes128", "rc4128"),
  permissions = "all"
)
```

## Arguments

- w:

  A `pdf_writer` from
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md).

- user, owner:

  Passwords, or `NULL`.

- method:

  `"aes128"` or `"rc4128"`.

- permissions:

  `"all"`, or any of `"print"`, `"modify"`, `"copy"`, `"annotate"`,
  `"forms"`, `"reading"`, `"assemble"`, `"print_high"`;
  [`character()`](https://rdrr.io/r/base/character.html) for none.

## Value

`w`, invisibly.

## Details

AES-128 is the method to use; RC4-128 is there for readers that know
nothing newer. AES-256 is not offered for writing (design section 7).
With no user password anyone can open the file and the permissions ask
readers to behave; with one, it is needed to open the file, and the
owner password (which defaults to a random one) unlocks everything.

## Examples

``` r
w <- pdf_new()
pdf_set_encryption(w, user = "secret", permissions = c("print", "copy"))
page <- pdf_page_new(w)
pdf_draw_text(page, 72, 700, "For your eyes only")
pdf_page_end(page)
bytes <- pdf_save(w)
pdf <- pdf_open(bytes, password = "secret")
pdf_meta(pdf)[c("encryption", "permissions")]
#> $encryption
#> [1] "aes-128"
#> 
#> $permissions
#> [1] "print" "copy" 
#> 
pdf_close(pdf)
```
