# Test fixtures

Written by `tools/update-fixtures`; nothing here is edited by hand.

| File | Source | Licence |
|---|---|---|
| `afl-input/*.pdf` | pdfio's `afl-input/` at the commit pinned in `src/vendor/PROVENANCE`: PDFs from Apache PDFBox's issue tracker that pdfio fuzzes with. Some are malformed. | Apache-2.0, as distributed with pdfio |
| `testpdfio.pdf` | pdfio's `testfiles/testpdfio.pdf` from the pinned release tarball | Apache-2.0 with pdfio's exceptions |
| `OpenSans-Regular.ttf` | pdfio's `testfiles/`, the Open Sans font | Apache-2.0, `OpenSans-LICENSE.txt` beside it |
| `pdfio-color.png`, `pdfio-rgba.png`, `color.jpg` | pdfio's `testfiles/`, for the writer's image tests | Apache-2.0 with pdfio's exceptions |
| `encrypted-rc4-128.pdf`, `encrypted-aes-128.pdf` | Written by pdfio through `tools/fixtures/make-encrypted.c`: one page, no password, all permissions | MIT (zupdf) |
| `encrypted-rc4-128-pw.pdf`, `encrypted-aes-128-pw.pdf` | As above, with user password `user`, owner password `owner`, printing forbidden | MIT (zupdf) |
| `grdevices.pdf` | `grDevices::pdf()`, one plot | MIT (zupdf) |
| `cairo.pdf` | `grDevices::cairo_pdf()`, one plot, where cairo is available | MIT (zupdf) |

Encryption keys are random, so regenerating the encrypted files changes
their bytes but not what the tests read from them.
