# Conditions raised by zupdf

Every error zupdf raises carries a condition class, so it can be caught
by kind rather than by matching the message, which may change. Every
class below inherits from `zupdf_error`, which inherits from `error`.
Each carries `detail`, pdfio's own message where there is one.

## Details

- `zupdf_invalid_argument`:

  An argument was unusable: an unknown page, a bad colour, a limit that
  is not a positive whole number. Carries `arg`, the argument at fault.

- `zupdf_parse_error`:

  pdfio refused the file or an object. Carries `object`, the object
  number, when pdfio named one.

- `zupdf_password_error`:

  The file is encrypted and no password given opened it.

- `zupdf_limit_error`:

  A limit was reached. Carries `limit`, the argument's name, such as
  `"max_stream"`, and `limit_value`.

- `zupdf_unsupported_input`:

  The input uses something zupdf does not support, such as a WebP image
  or AES-256 writing.

- `zupdf_write_error`:

  pdfio refused to write, or a closed writer was used.

- `zupdf_font_error`:

  A font file could not be read.

- `zupdf_io_error`:

  A file, temporary file or connection failed.

- `zupdf_encoding_error`:

  Extracted text is not valid UTF-8 after mapping.

Warnings carry the class `zupdf_warning`.

## Examples

``` r
tryCatch(
  stop(structure(
    class = c("zupdf_parse_error", "zupdf_error", "error", "condition"),
    list(message = "PDF parse error", call = NULL, detail = NULL)
  )),
  zupdf_error = function(e) class(e)[1]
)
#> [1] "zupdf_parse_error"
```
