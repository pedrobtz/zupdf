# zupdf — Design

**Status:** Draft, 2026-10-08. Adopted from [RFC 0008](https://github.com/pedrobtz/packages/blob/main/rfcs/0008-zupdf-pdf-files.md) (2026-10-07) as the package's own specification. Nothing here is implemented: the repository is the `usethis` skeleton plus these documents. Every statement here is a decision; things not yet decided live in §18 and nowhere else. Amend this file in the same commit as the code that changes it. [roadmap.md](roadmap.md) sequences the work; its section references (§) point here.
**Package:** `zupdf`
**One line:** PDF files opened, inspected, extracted from, assembled and written through vendored pdfio and its `ttf` library, with zlib the only system library, limits for hostile input, and no renderer.

What changed between the RFC and this document: the RFC read pdfio's `master` at commit `5841fd0` (version string 1.7.0, unreleased) and designed the API for 1.7.0. On 2026-10-08 the upstream release page still shows **v1.6.5 as the latest release and no 1.7.0 tag** (*verified 2026-10-08*), so Stage 0 pins 1.6.5 as the RFC's own contingency says, and this document marks what arrives only with 1.7.0 (§9). The RFC's roadmap table (its §19) became [roadmap.md](roadmap.md).

---

## 1. What zupdf is

`zupdf` opens, inspects, extracts from, assembles and writes PDF files through pdfio, Michael Sweet's C library for PDF reading and writing, compiled into the package with only zlib from the system. It answers the questions R users take to `pdftools` and `qpdf` today without a renderer: how many pages, what metadata, what text is on page three, which images, which fonts; split this file, merge those, rotate, reorder, set permissions, encrypt; and it makes new PDFs from R, page by page, with text, paths and images, for reports that `grDevices::pdf()` cannot make because they are not plots.

For people already using those packages, zupdf also provides the pdftools and qpdf functions that need no renderer, under the same names and with the same arguments and return values (§5.1). Where zupdf can do the job, switching is a matter of replacing the `library()` call.

It does not render pages to pixels. The only C renderer that could be vendored is MuPDF, whose AGPL licence rules it out, and poppler is a system library with a C++ API. `pdftools::pdf_render_page()` stays the answer for pixels, and §3 says so plainly.

---

## 2. Scope

**In, for v0.1.0:**

- Opening a PDF from a file, a raw vector or a connection, with a password; reading its version, page count, metadata, ID, permissions and encryption.
- Pages: media and crop boxes, rotation, the page dictionary as an R list, the content stream's tokens and its text in reading order (the algorithm of pdfio's `pdf2text` example, ported into the package as project C).
- Objects: every object by number, its type, dictionary or array as an R list, its stream decoded (the filters pdfio decodes, §9) or raw; images as raw bytes with their dictionary.
- Assembling: copying pages from one or more open files into a new one, in any order, with rotation; splitting; setting metadata, permissions and encryption (RC4 128, AES 128; AES 256 reading only where pdfio allows it) on the output.
- Creating: a new file with pages drawn from R with pdfio's content API (paths, fills, strokes, text in the base-14 fonts or an embedded TrueType or OpenType file, images from PNG and JPEG files or R rasters), written to a file, a raw vector or a connection.
- Limits on input size, object count, stream size and recursion for untrusted input, since a PDF is the canonical hostile document.
- A compatibility layer: the pdftools and qpdf functions that need no renderer, under their names, with their formal arguments and return shapes (§5.1).

**Out:**

- Rendering, OCR, form filling, annotations as objects (they are plain objects, reachable through the object API, not modelled), digital signatures, redaction, linearisation, incremental update, JBIG2 and JPX decoding, colour management.
- pdftools's rendering and OCR functions (`pdf_render_page()`, `pdf_convert()`, `pdf_ocr_text()`, `pdf_ocr_data()`) and `poppler_config()`; qpdf's `pdf_compress()` until §18 Q10 says otherwise (§5.1).
- A graphics device: `grDevices::pdf()` and `cairo_pdf()` exist. zupdf's drawing API is for documents, not plots; a plot goes in as a page from `pdf()` through `pdf_copy_pages()`.
- Text layout: zupdf shows text where told, as pdfio does; wrapping, justification across lines and tables are the caller's, as in pdfio's `md2pdf` example, which a vignette ports.

---

## 3. Position in the `zu*` family and beside pdftools and qpdf

| Package | Library | Install needs | Renders | Writes |
|---|---|---|---|---|
| `pdftools` (3.9.1, 2026-09-01; *verified 2026-10-08*) | poppler (C++) | `libpoppler-cpp-dev`, `poppler-data` | yes | no |
| `qpdf` | qpdf (C++) | bundled, a large C++ build | no | assemble |
| `zupdf` | pdfio (C) | zlib | no | yes |

`pdftools` extracts text, metadata, fonts and images and renders pages through poppler, which needs `libpoppler-cpp-dev` or the CRAN binary; `qpdf` splits, merges, rotates, encrypts and compresses through the qpdf library, which the R package bundles as a large C++ build. zupdf covers both packages' non-rendering halves from one 19 000-line C library that builds in seconds, and adds what neither has: writing pages from R. It depends on zlib only, which R's own build already needs, so `SystemRequirements` is empty on every platform CRAN builds for.

These are zupdf's cells for the family table that alignment rule R1 of [`zu-family-alignment.md`](https://github.com/pedrobtz/packages/blob/main/zu-family-alignment.md) places in `pedrobtz/packages` as `zu-family.md` (not yet written on 2026-10-08):

| | zupdf |
|---|---|
| Role | format |
| R prefix | `pdf_` (the compatibility layer, §5.1, uses pdftools's and qpdf's names) |
| Info function | `zupdf_info()` |
| Root condition class | `zupdf_error`; warnings `zupdf_warning` |
| Public C prefix | none; internal `zpd_` / `ZPD_` |
| From C | no C API |
| Hides symbols (`$(C_VISIBILITY)`) | yes, from Stage 0 (R3); pdfio's and ttf's symbols included |
| Vendored code | pdfio 1.6.5 (then 1.7.0 when tagged), with its ttf library in the same tree (§9) |
| `LinkingTo` | `zufast (>= 0.1.0)` |
| `Depends: R` | 4.1 (R2) |
| Language | en-GB (R2) |

Its names follow two rules (D8). The compatibility layer (§5.1) reuses pdftools's and qpdf's names with exactly their formal arguments and return shapes, so code written for those packages runs when `library(zupdf)` replaces `library(pdftools)` or `library(qpdf)`. Every other export uses a name that neither package exports. A shared name never means something different: no zupdf function uses a pdftools or qpdf name for a different job. pdftools 3.9.0 exports `pdf_attachments`, `pdf_convert`, `pdf_data`, `pdf_fonts`, `pdf_info`, `pdf_ocr_data`, `pdf_ocr_text`, `pdf_pagesize`, `pdf_render_page`, `pdf_text`, `pdf_toc` and `poppler_config`, and re-exports all seven of qpdf 1.4.1's: `pdf_combine`, `pdf_compress`, `pdf_length`, `pdf_overlay_stamp`, `pdf_rotate_pages`, `pdf_split`, `pdf_subset` (*verified 2026-10-08* from installed copies; the RFC also listed a qpdf `pdf_encrypt` and `pdf_decrypt`, which do not exist). It consumes `zufast` for UTF-8 validation of extracted text (`zuf_utf8_valid()`, *verified 2026-10-08*) and number formatting, and could later hand `zusvg`'s (RFC 0007) paths into content streams (§18). Stage 0 verifies `zpd_` is free against every sibling.

**Consumers.** None named. Nothing in 0.1.0 is shaped around a sibling.

**Audience** (*Stage 0 survey, 2026-10-08*). CRAN has 166 packages that depend on pdftools or qpdf (pdftools: 39 hard, 55 in `Suggests`; qpdf: 28 hard, 49 in `Suggests`). In their R code and vignettes, excluding tests, 79 call a pdftools or qpdf function. 50 of those (63 %) call only functions that §5.1 provides in 0.1.0; 55 (70 %) once `pdf_data()`, `pdf_overlay_stamp()` and `pdf_compress()` are decided (§18 Q1, Q3, Q10); 24 (30 %) call `pdf_render_page()`, `pdf_convert()` or `pdf_ocr_*()` and need pdftools anyway. The most-called functions are `pdf_text()` (38 packages), `pdf_info()` (17), `pdf_combine()` and `pdf_convert()` (16 each), `pdf_render_page()` (8), `pdf_length()` (7), `pdf_data()` and `pdf_subset()` (5 each). So most users of these packages do not render, and the text extractor and the compatibility layer are what they would use. The count matches function names as calls, so it can include a package's own function of the same name.

---

## 4. Architecture

Two kinds of handle and a stateless layer between them:

1. **`pdf_file`**: an open pdfio file for reading, a finalized external pointer over `pdfio_file_t *`, holding the path (or the temporary file a raw vector or connection was spilled to, §10), the password callback's answer and the error callback's record. pdfio reads lazily by cross-reference, so opening is cheap and page and object access go back to the file descriptor; the handle keeps the file open until `pdf_close()` or the finalizer.
2. **`pdf_writer`**: a pdfio file being created, over `pdfioFileCreate()` (to a path) or `pdfioFileCreateOutput()` (to a callback that appends to a growable buffer owned by the handle, for raw and connection output). Pages are added through `pdf_page_new()`, which returns a `pdf_page` handle whose content stream is open until `pdf_page_end()`; `pdf_save()` closes the file and yields the bytes.
3. **Conversion** (`src/zpd_value.c`): pdfio values (`pdfio_dict_t`, `pdfio_array_t`, names, strings, numbers, booleans, dates, binary strings, indirect references) to and from R lists with the mapping of §6, with recursion bounded by `max_depth`.

**The error callback never longjmps.** `pdfio_error_cb_t` copies the message into the handle and returns `false` for errors and `true` for `WARNING:` messages, as pdfio's default does without the `stderr` write; after the pdfio call returns, the R side raises the recorded message as a classed condition. This is the rule that keeps pdfio's frames clean, since pdfio holds `malloc()`ed state and open descriptors across its calls and R's error path would leak them. The password callback likewise returns a string the handle already owns.

Every `.Call` entry point is registered, symbols hidden (`C_VISIBILITY`), and `tools/check-symbols` verifies only `R_init_zupdf` is exported. No static state beyond pdfio's own `const` tables and one non-`const` SHA-256 temporary (`addTemp` in `pdfio-sha256.c`), which is harmless in R's single thread and is noted for upstream.

---

## 5. Public R API (complete v0.1.0 surface)

The native API is below; §5.1 adds the compatibility layer built on top of it.

```r
# reading
pdf_open(x, password = NULL, ..., max_size = 1024^3, max_objects = 1e6,
         max_stream = 256 * 1024^2, max_depth = 64, max_pages = 1e5)
pdf_close(pdf)
pdf_meta(pdf)              # version, pages, title, author, ..., id,
                           # encryption, permissions, creation, modified
pdf_pages(pdf)             # data frame: page, width, height, rotate,
                           # media_box, crop_box, streams
pdf_page(pdf, i)           # the page dictionary as a list
pdf_page_text(pdf, pages = NULL, layout = c("reading", "raw"))
pdf_page_tokens(pdf, i)    # the content stream as a token data frame
pdf_page_images(pdf, i)    # data frame: object, width, height, filter,
                           # color_space, bits
pdf_font_table(pdf)        # data frame: object, name, type, embedded
pdf_objects(pdf)           # data frame: number, generation, type,
                           # subtype, length
pdf_object(pdf, n)         # dictionary or array as a list
pdf_stream(pdf, n, decode = TRUE)   # raw
pdf_image(pdf, n, as = c("raw", "native"))

# writing
pdf_new(version = "2.0", media_box = pdf_paper("a4"), created = Sys.time(),
        deterministic = FALSE, ...)
pdf_page_new(w, media_box = NULL, crop_box = NULL, dict = NULL)
pdf_page_end(page)
pdf_draw_text(page, x, y, text, font = "Helvetica", size = 12, ...)
pdf_font(w, x)             # base-14 name or a .ttf/.otf path
pdf_draw(page, path, fill = NULL, stroke = NULL, width = 1, ...)
pdf_image_new(w, x)        # a file path or a raster/nativeRaster
pdf_draw_image(page, image, x, y, width, height)
pdf_copy_pages(w, pdf, pages = NULL, rotate = 0)
pdf_set_meta(w, ...)
pdf_set_encryption(w, user = NULL, owner = NULL,
                   method = c("aes128", "rc4128"), permissions = "all")
pdf_save(w, file = NULL)   # raw, or writes file / connection

pdf_paper(name, landscape = FALSE)
zupdf_info()
```

- `pdf_open()`: `x` is a path, a raw vector or a connection; `password` is a string or a function of the file name returning one, called in R before the C call so that no R code runs inside pdfio's password callback. A wrong password is `zupdf_password_error`.
- `pdf_meta()`: the `pdfioFileGet*` metadata fields, the encryption as `"none"`, `"rc4-40"`, `"rc4-128"`, `"aes-128"`, `"aes-256"` and the permission bits as a character vector of the `PDFIO_PERMISSION_*` names in lower case.
- `pdf_page_text()`: text per page, one string each, in reading order by the `pdf2text` algorithm (text matrix tracking; `Td`/`TD`/`T*`/`'`/`"` as line breaks; `Tj`/`TJ`/`'`/`"` as shows; ToUnicode and the base-14 encodings for bytes to characters); `"raw"` is the shows concatenated in stream order. Both validate UTF-8 before making a CHARSXP (`zuf_utf8_valid()`), replacing invalid bytes with U+FFFD and warning once.
- `pdf_page_tokens()`: `pdfioStreamGetToken()` over the page's streams, one row per token with its type (operator, number, name, string, array or dict delimiter) and value; the raw material for anyone who needs more than `pdf_page_text()`.
- `pdf_stream()`: the object's stream, decoded through pdfio's filters (`decode = TRUE`) or the stored bytes; bounded by `max_stream`.
- `pdf_image()`: the image's samples as stored, with `width`, `height`, `bits`, `color_space` and `filter` attributes, or as a `nativeRaster` when the image is DeviceRGB or DeviceGray at 8 bits with Flate or no filter; DCT (JPEG) images come back as the JPEG bytes with `filter = "DCTDecode"`, for `jpeg::readJPEG()`, since pdfio does not decode JPEG and zupdf does not vendor a decoder (D6).
- The writer takes R colours for `fill` and `stroke` through `col2rgb()`; `path` is a data frame of `x`, `y` and an operation (`move`, `line`, `curve`, `close`, `rect`) or a `grid`-style list; coordinates are PDF points with the origin at the bottom left.
- `pdf_font()`: a base-14 name (`pdfioFileCreateFontObjFromBase()`) or a font file path (`pdfioFileCreateFontObjFromFile()`, Unicode CID font). There is no system font lookup (D7).
- `pdf_copy_pages()`: `pdfioPageCopy()` per page, which copies the page object and everything it references, so the result is self-contained.
- `pdf_save()` with `file = NULL` returns a raw vector; a connection is written in blocks as pdfio's output callback delivers them.
- `pdf_paper()`: ISO A and B series, US letter, legal, tabloid, in points, landscape if asked.
- `zupdf_info()`: the pdfio version (ttf ships inside it), the patch identifiers, zlib's version, which features the pin lacks (§9), the limits' defaults, and a self-test that writes a one-page file in memory.

Printing a `pdf_file` shows the path, version, page count and encryption; `length()` is the page count. `pdf_page_text()` has a `pages` argument because text extraction walks every token of each page and a 2 000-page file should not be forced whole.

### 5.1 Compatibility layer

These are the pdftools and qpdf functions that need no renderer, under the same names and with exactly the same formal arguments. Each is a thin R wrapper over the native API. Each accepts what the original accepts (a path or raw vector for pdftools's `pdf`, a character vector of paths for qpdf's `input`) and also a `pdf_file`. A wrapper opens its input with the default limits, closes whatever it opened before returning, and returns what the original returns, column for column and class for class (pdftools's data frames carry the `tbl_df` class without depending on tibble, and so do these). `opw` and `upw` both go to pdfio's password callback, the user password first. Conditions are zupdf's classes (§11). They inherit `error`, so `tryCatch(..., error = )` code written for the originals still catches them.

```r
# pdftools 3.9.0
pdf_info(pdf, opw = "", upw = "")
pdf_text(pdf, opw = "", upw = "", raw = FALSE)
pdf_fonts(pdf, opw = "", upw = "")
pdf_pagesize(pdf, opw = "", upw = "")
pdf_toc(pdf, opw = "", upw = "")
pdf_attachments(pdf, opw = "", upw = "")
pdf_data(pdf, font_info = FALSE, opw = "", upw = "")              # §18 Q1

# qpdf 1.4.1, also re-exported by pdftools
pdf_length(input, password = "")
pdf_split(input, output = NULL, password = "")
pdf_subset(input, pages = 1, output = NULL, password = "")
pdf_combine(input, output = NULL, password = "")
pdf_rotate_pages(input, pages, angle = 90, relative = FALSE,
                 output = NULL, password = "")
pdf_overlay_stamp(input, stamp, output = NULL, password = "")    # §18 Q3
```

| Function | Built on | Where it differs from the original |
|---|---|---|
| `pdf_info()` | `pdf_meta()`, the catalog | The same eleven fields. `metadata` is the text of the XMP stream; `linearized` comes from the first object's `/Linearized`. |
| `pdf_text()` | `pdf_page_text()` | pdftools returns poppler's physical layout, padded with spaces to page positions. zupdf returns the `pdf2text` reading order (§8). Pages and words match, but spacing differs and line order sometimes does. `raw = TRUE` is `layout = "raw"`, which is stream order in both packages. |
| `pdf_fonts()` | `pdf_font_table()` | For a non-embedded font, pdftools reports the system substitute fontconfig chose in `file`. zupdf reports `NA`, because it has no system font lookup (D7). |
| `pdf_pagesize()` | `pdf_pages()` | Same six columns (`top`, `right`, `bottom`, `left`, `width`, `height`). |
| `pdf_toc()` | the outline tree, walked under `max_depth` | Same nested `title` / `children` list. |
| `pdf_attachments()` | the `EmbeddedFiles` name tree | Same list of entries with their data. |
| `pdf_data()` | the text walk's matrices | Exported only once §18 Q1 is decided. |
| qpdf's six | `pdf_open()`, `pdf_copy_pages()`, `pdf_save()` | pdfio writes the output, so the bytes differ from qpdf's. Pages, their content and their order are the same. `pdf_overlay_stamp()` waits for §18 Q3. |

Not provided: `pdf_render_page()`, `pdf_convert()`, `pdf_ocr_text()` and `pdf_ocr_data()` (they need a renderer), `poppler_config()` (there is no poppler), and `pdf_compress()` (§18 Q10). None of these is defined as a stub that always fails. A user who switches packages gets "could not find function" on the first call, and that message already names what is missing.

The originals' signatures are pinned at pdftools 3.9.0 and qpdf 1.4.1. Whenever an original is installed, a test compares each wrapper's `formals()` with it, so a signature change upstream fails a check before it reaches a user (§18 Q11). Attaching zupdf after pdftools or qpdf masks their functions, and R's attach message lists them. The package help page and the README say so.

---

## 6. PDF values to R and back

| PDF | R | Back |
|---|---|---|
| null | `NULL` | `NULL` |
| boolean | logical | logical |
| number | double, or integer when whole and in range | numeric |
| string | character, PDFDoc or UTF-16BE to UTF-8 | character |
| binary string | raw, class `pdf_binary` | that class |
| name | character, class `pdf_name` | that class |
| date | `POSIXct`, UTC | `POSIXct` |
| array | unnamed list | unnamed list |
| dictionary | named list, keys without `/` | named list |
| indirect ref | integer, class `pdf_ref`, with `generation` | that class |
| stream | `pdf_ref` to its object; bytes by `pdf_stream()` | not written |

Names and strings must be distinguishable in both directions, hence the `pdf_name` class on a character scalar; a plain character in a dictionary given to the writer is a string. Dictionaries keep pdfio's key order on the way out and R's on the way in. The writer accepts the same mapping for `pdf_set_meta()` and for the `dict =` of `pdf_page_new()`, which is how a caller sets what the API does not model, and refuses a value whose depth exceeds `max_depth`; an R `NULL` inside a list is written as PDF `null`.

---

## 7. Writing

pdfio writes objects as they close, cross-reference and trailer at `pdfioFileClose()`, compressing content streams with Flate; 1.7.0 adds object streams, which zupdf enables by default for 1.5 or later versions once that pin lands. Output is deterministic per input and arguments except for two fields pdfio fills from the clock and the environment: the creation date (`CreationDate`) and the file ID, which pdfio seeds from the time and the file name. zupdf sets both from arguments (`created =` on `pdf_new()`, defaulting to `Sys.time()`; the ID from a hash of the content when `deterministic = TRUE`), so a test can pin bytes and a build can reproduce a report. The conformance job writes each fixture twice and compares.

Encryption uses pdfio's own RC4, MD5, AES and SHA-256 (`pdfio-rc4.c`, `pdfio-md5.c`, `pdfio-aes.c`, `pdfio-sha256.c`): no OpenSSL, no `zucrypt`. These are the PDF standard's algorithms for its security handler, not a general-purpose crypto offering; zupdf's documentation says RC4 is there for compatibility and AES 128 is the one to use, and does not offer AES 256 for writing while pdfio marks it excluded.

---

## 8. Text extraction

The `pdf2text` example is 1 420 lines of C that walk a page's content tokens, track the text and line matrices, decode strings through the font's encoding or ToUnicode CMap, and emit lines in order. zupdf ports it into `src/zpd_text.c` as project code, with these changes: every output goes to a growable buffer rather than `stdout`; fonts and CMaps are cached per `pdf_file` (not per page) in an R-owned table; `R_CheckUserInterrupt()` runs every 4 096 tokens, between pdfio calls; the recursion into Form XObjects (`Do`) is bounded by `max_depth` and refuses a cycle; and bytes a font cannot map become U+FFFD rather than being dropped, so the count of them is reportable (`attr(, "unmapped")`). It is the largest piece of project C and the one the text fixtures (§15) pin against `pdftools::pdf_text()` output.

---

## 9. The vendored libraries, as zupdf uses them

| Library | Pin | Files | Lines | Licence |
|---|---|---|---|---|
| pdfio, with ttf | **v1.6.5**, commit `5102edd` (*verified 2026-10-08*: upstream's latest release; no 1.7.0 tag) | 17 `.c` (16 pdfio, `ttf.c`), 6 `.h` | 21 k | Apache-2.0 with exceptions |

From 1.6.0 the ttf library ships inside pdfio's own tree (`ttf.c`, `ttf.h`), not as a submodule, so one release tarball and one vendor tree cover both (*found at Stage 0*; the RFC planned two trees with two pins).

Facts read from the source that shape the design (the RFC read `master` at `5841fd0`; where a fact is 1.7.0-only it says so):

- **Input is a file name.** `pdfioFileOpen()` takes a path and reads through a descriptor with `open()`, `read()` and `lseek()`; there is no memory or callback input. A raw vector or connection is spilled to a temporary file under `tempdir()` that the handle owns and the finalizer unlinks (§10). Output has both: `pdfioFileCreate()` to a path and `pdfioFileCreateOutput()` to a callback.
- **Errors.** The default error callback writes `filename: message` to `stderr` and returns `false` unless the message starts with `WARNING:`. zupdf always installs its own callback (§4), so the default is never reached, but it is still a `stdio` write in compiled code, which R CMD check flags. So are ttf's `errorf()` fallback to `stderr` and the three debug printers (`_pdfioArrayDebug()`, `_pdfioDictDebug()`, `_pdfioValueDebug()`), which are compiled in every build, not only under `DEBUG` (*found at Stage 0*). Patch 0002 puts all of them behind a `PDFIO_NO_STDIO` build option, which `Makevars` defines; it is offered upstream. `copy_png()`'s `fputs(stderr)` is inside `HAVE_LIBPNG`, which zupdf never defines, so it is never compiled and needs no patch.
- **Visibility** (*found at Stage 0*). `pdfio.h` marks the whole API `visibility("default")` and `pdfio-private.h` does the same for `_PDFIO_PRIVATE`, which would export every pdfio function from `zupdf.so` past `$(C_VISIBILITY)`. Patch 0001 lets both macros be defined on the command line, and `Makevars` defines them empty.
- **zlib.** `pdfio-private.h` includes `zlib.h` and streams hold a `z_stream`; `Makevars` links `-lz`. The pdfio manual requires zlib 1.0 or later and a C99 compiler (*verified 2026-10-08*). R on every CRAN platform ships zlib (R itself needs it), so this is not a system requirement in CRAN's sense; the build matrix at Stage 0 proves the header is found on Windows (Rtools) and macOS (the R installation's `opt/R` tree).
- **Images.** `pdfioFileCreateImageObjFromFile()` reads JPEG (header only; DCT bytes are copied through), PNG through libpng when `HAVE_LIBPNG` or through its own decoder otherwise, GIF (1.7.0 only) and WebP only with `HAVE_LIBWEBP`. zupdf defines neither `HAVE_*`, so PNG uses pdfio's built-in reader and WebP is `zupdf_unsupported_input`. The built-in PNG reader has its own zlib inflate and a `setjmp` error path that writes to `stderr` (patched out, above).
- **Fonts.** `pdfio-content.c` uses the `ttf` library (in pdfio's own tree) for embedded TrueType and OpenType fonts: `ttfCreate()` from a path, `ttfCreateData()` from memory. 1.7.0's `pdfioFileCreateFontObjFromSystem()` scans system font directories through `ttfCacheCreate()`, and `ttf-cache.c` has a `fprintf(stderr)` default error path; 1.6.5 has neither. zupdf does not call any system lookup (D7), installs the error callback on every `ttfCreate*()` call, and the stdio patch must cover `ttf-cache.c` when the pin moves. Base-14 fonts use `pdfio-base-font-widths.h` for metrics, so `pdf_draw_text()` can measure without any font file.
- **Filters.** Flate (zlib), ASCII85, RunLength, ASCIIHex in 1.6.5; LZW and compound filters only from 1.7.0. `pdfio-stream.c` at 1.6.5 has no LZW code (*settled at Stage 0*, §18 Q8), so `zupdf_info()` lists `lzw` as absent. Not DCT, JPX, JBIG2 or CCITT, whose streams come back undecoded with their filter name.
- **Encryption.** RC4 40 (reading), RC4 128, AES 128 read and write; AES 256 marked `@exclude all@` with a buffer-overflow fix in 1.7.0's change log, so zupdf exposes it for reading only when pdfio does and never for writing. The 1.6.5 release fixed an invalid-empty-string read in AES (GHSA-527h-2p2v-g388), which puts a floor on the pin.
- **1.7.0-only features**, absent from the 1.6.5 pin and stated as absent by `zupdf_info()` until the pin moves: LZW (if Stage 0 confirms), GIF images, object streams on write, the `pdfioPageGet*` accessors (zupdf reads the page dictionary directly instead), Unicode file names on Windows, the system font lookup (which zupdf does not use anyway).
- **Corpus.** `afl-input/` holds the PDFBox-derived crash cases and `afl-pdf.dict` a fuzzing dictionary; both are in the git tag but not in the release tarball (*found at Stage 0*), so `tools/update-fixtures` fetches them from the tag's commit. `testfiles/` in 1.6.5 holds fonts (Noto Sans JP, Open Sans, with their licences), images and ICC profiles, but only one PDF (`testpdfio.pdf`), so the reading fixtures come mostly from other producers (§15). zupdf's fuzz job seeds from `afl-input` and the dictionary; the test fixtures take the small files from `testfiles` and the licences with them.
- **Standard and warnings.** C99 with `ssize_t`, `open()`, `lseek()` and `unistd.h` on POSIX and the Windows CRT equivalents under `_WIN32`; no threads. Random bytes for encryption come from `arc4random()` on macOS, `CryptGenRandom()` on Windows and `/dev/urandom` elsewhere (`HAVE_GETRANDOM` is not defined), with a time-seeded fallback; none is the C library's `rand()`. The first build (*Stage 0*) is clean under clang's `-Wall -pedantic -Wstrict-prototypes`; `-Wextra` adds function-type-cast and null-pointer-subtraction warnings, recorded in `PROVENANCE` and not patched, since CRAN's flags do not print them. gcc's `-Wformat-truncation` (on by default with `-Wall`) flagged two 32-byte date buffers, which patch 0003 enlarges. Anything CRAN's flags print is patched, not silenced, and never by a diagnostic-suppressing pragma.

Vendoring follows zucbor §13 and the template: `src/vendor/pdfio/` is byte-identical to the files `tools/pdfio-files.txt` lists from the release tarball, plus the recorded patch set in `tools/patches/`, applied by `tools/update-pdfio` and verified by `tools/verify-vendor` in CI (`vendor.yaml`); `src/vendor/PROVENANCE` records the tag, its commit, the tarball checksum, every patch with its reason, and the warnings seen. Each patch adds a modification notice to the files it changes (Apache-2.0 §4(b)). `inst/COPYRIGHTS` reproduces pdfio's `NOTICE` with its exception text; `LICENSE.note` records provenance; the fixtures' font licences ride along. The `License:` field is D15.

---

## 10. Input sources and temporary files

| Input | Handling |
|---|---|
| path | `pdfioFileOpen()` on it; kept open by the handle |
| raw vector | written to a temporary file the handle owns |
| connection | read in blocks to a temporary file, under `max_size` |
| `pdf_file` | passed through |

The temporary file is made with `tempfile(fileext = ".pdf")` under R's session directory, which R removes at exit; the handle's finalizer unlinks it earlier. `pdfioFileCreateTemporary()` is not used because its location is pdfio's choice, not R's. A raw vector longer than `max_size` is refused before writing.

---

## 11. Errors

| Class | When |
|---|---|
| `zupdf_invalid_argument` | parameters, an unknown page, a bad colour |
| `zupdf_parse_error` | pdfio refused the file or an object |
| `zupdf_password_error` | the file is encrypted and no password opened it |
| `zupdf_limit_error` | a limit of §12; `limit`, `limit_value` fields |
| `zupdf_unsupported_input` | WebP, JPX, JBIG2, AES-256 writing, a 1.7.0-only feature under the 1.6.5 pin |
| `zupdf_write_error` | pdfio refused to write; a closed writer reused |
| `zupdf_font_error` | a font file `ttf` could not read |
| `zupdf_io_error` | a file, temporary file or connection failed |
| `zupdf_encoding_error` | extracted text that is not UTF-8 after mapping |

Every condition inherits `zupdf_error` and carries pdfio's message verbatim as `detail`; a parse error carries `object` when pdfio named one. Warnings (`zupdf_warning`) carry pdfio's `WARNING:` messages, once per call with the count. pdfio's errors are strings, so R maps known message prefixes to classes and anything else is a bare `zupdf_parse_error` or `zupdf_write_error`; a test enumerates the prefixes (§15). Tests assert on class.

---

## 12. Limits and hostile input

| Limit | Default | Guards |
|---|---|---|
| `max_size` | 1 GiB | bytes spilled or read from any source |
| `max_objects` | 1e6 | `pdfioFileGetNumObjs()` after the xref is read |
| `max_stream` | 256 MiB | decoded bytes of one stream (a Flate bomb) |
| `max_depth` | 64 | value nesting, Form XObject nesting, page tree |
| `max_pages` | 1e5 | pages, before `pdf_pages()` builds its frame |

pdfio is a hardened parser (its own AFL corpus, four security advisories fixed in 2025 and 2026) but it has no limits of its own: a cross-reference loop, an object stream referring to itself, a page tree with a cycle, a 1 GB Flate stream from 1 MB of input are its callers' to bound. zupdf bounds what it can before the call (`max_size`, `max_objects`, `max_pages`) and during it (`max_stream` in its own `pdfioStreamRead()` loop, `max_depth` in its conversion and text walk). What it cannot bound is time inside one pdfio call that follows a cycle, which the fuzz job's timeout finds and which goes to upstream as a bug; `R_CheckUserInterrupt()` runs between pdfio calls, not inside them.

A limit is a positive whole number or `Inf` where that makes sense; anything else is `zupdf_invalid_argument`. Each guard carries a `/* GUARD: name */` marker and `tools/run-mutation-check` proves it load-bearing.

---

## 13. Memory model

A `pdf_file` owns its `pdfio_file_t`, its temporary file and its text caches in one external pointer; `pdfioFileClose()` runs in the finalizer if `pdf_close()` did not, and a closed handle is refused by every function. A `pdf_writer` owns the file or the output buffer; an open `pdf_page` holds a stream pointer that `pdf_page_end()` closes and that the writer's finalizer closes if the page was abandoned, in the right order (streams before the file). Nothing pdfio allocates is ever held outside an external pointer, and no R allocation happens while a pdfio stream is open for reading except the growable result buffer, which is R-owned. User code never runs inside pdfio: the password callback answers from a string the handle holds (a function `password` is called in R before `pdf_open()` reaches C).

---

## 14. Build, portability and CRAN

- `src/Makevars` lists the vendored and project object files by hand (17 vendored at 1.6.5), portable make only; `PKG_CPPFLAGS = -I vendor/pdfio -DPDFIO_NO_STDIO -D_PDFIO_PUBLIC= -D_PDFIO_PRIVATE=` (patches 0001 and 0002), `PKG_CFLAGS = $(C_VISIBILITY)`, `PKG_LIBS = -lz`. No `Makevars.win`: Rtools provides zlib and the `unistd.h` equivalents the sources already handle under `_WIN32`, and MinGW links `advapi32` (for `CryptGenRandom()`) by default.
- `tools/check-symbols` on an installed build (`R_init_zupdf` the only exported text symbol; no stdio, `abort`, `exit`, `assert`, `rand`; its canary plants both a `fprintf(stderr)` and an extra export); `tools/check-status-table` has no equivalent, since pdfio's errors are strings, so the test of §15 that maps each known message prefix to a class stands in for it.
- The native-checks matrix as zucbor: ASan, UBSan (with `-UNDEBUG`), valgrind, LTO, gctorture, rchk; the fuzz job builds `pdf_open()` and the text and object walks under libFuzzer with the `afl-input` seed and dictionary.
- `R CMD check` NOTE hazards: `stdio` writes (patched), `abort()` or `exit()` (none found), file-system access outside temp (the system font scan, never called), and the vendored font files in fixtures (licences included; the tarball stays under 5 MB by taking only `OpenSans-Regular.ttf` and the small PDFs).
- `LinkingTo: zufast (>= 0.1.0)` with `Remotes: pedrobtz/zufast@main` during development only (R10.2); CRAN order: after `zufast`. `Suggests: pdftools, qpdf, jpeg, png, testthat (>= 3.0.0), withr, knitr, rmarkdown`.
- `Language: en-GB`; `.Rbuildignore` covers `.agents/`, `.claude/`, `tools/`, `fuzz/`.

---

## 15. Testing

- **Fixtures.** The small files of pdfio's `testfiles/`, PDFs written by `grDevices::pdf()`, `cairo_pdf()`, LaTeX and LibreOffice (one each, CC0 content), encrypted variants made by zupdf itself at each method, and the `afl-input` crash cases, which must all be refused cleanly. `tools/update-fixtures` pulls them; nothing is hand-edited; `tests/testthat/fixtures/README.md` lists sources and licences.
- **Reading.** `pdf_meta()`, `pdf_pages()`, `pdf_objects()` pinned per fixture; `pdf_page_text()` compared with `pdftools::pdf_text()` after whitespace normalisation in the conformance job (a `Suggests`), pinned exactly in the package tests.
- **Writing.** Each writer function's bytes pinned under `deterministic = TRUE`; every written file reopened with `pdf_open()` and, in the conformance job, with `qpdf::pdf_length()` and `pdftools::pdf_text()` to prove other readers accept it; `qpdf --check` where the binary exists.
- **Round trips.** `pdf_copy_pages()` of every fixture into a new file, then text and page boxes equal.
- **Compatibility.** Whenever the original is installed, each §5.1 wrapper's `formals()` must be identical to its original's. On every fixture, return values are compared with the originals' for names, columns and classes, and for values wherever the §5.1 table says they agree: `pdf_info()` fields, `pdf_pagesize()`, `pdf_length()`, and the page counts and text of split, subset, combined and rotated output. `pdf_text()` is compared after whitespace normalisation, like `pdf_page_text()`.
- **Limits and faults.** Each §11 class with a crafted file: a Flate bomb for `max_stream`, a self-referencing object stream and a page tree cycle for `max_depth`, a million-object xref for `max_objects`, a wrong password, a WebP image. A test enumerates every pdfio message prefix the class map knows and asserts the map; an unknown prefix falls to the bare class deliberately.
- **Memory.** A thousand `pdf_open()` calls without `pdf_close()` leave no descriptors (checked by `ls /proc/self/fd` on Linux) and no temporary files once `gc()` runs; gctorture and valgrind as zucbor.
- **Fuzzing.** Nightly 30 minutes on the seeded corpus; invariants: no crash, leak, hang past the timeout, or stderr output; every refusal is a classed condition. `fuzz_canary` must crash first.
- Tests are self-sufficient, pass under `shuffle = TRUE`, stay serial, and the CRAN suite runs in under 15 s; the thousand-handle test and the bombs call `skip_heavy()`.

---

## 16. Performance targets

Measured by `tools/run-benchmarks` against `pdftools` and `qpdf` where installed, and recorded here when Stage 7 runs them:

- `pdf_open()` plus `pdf_meta()` on a 100-page file: under 5 ms, since pdfio reads the xref and nothing else.
- `pdf_page_text()` on a 100-page text document: within 2× of `pdftools::pdf_text()`; poppler's layout engine does more and is not the bar.
- Merging 100 one-page files: within 2× of `qpdf::pdf_combine()`.
- Writing a 100-page report of text and paths: under 200 ms.

---

## 17. Decisions

| # | Question | Decision |
|---|---|---|
| D1 | Libraries | pdfio vendored, not linked, with its ttf library, which ships in the same release tarball and tree from 1.6.0 |
| D2 | Rendering | never, from this package; the API has no `render` slot to fill |
| D3 | Raw and connection input | spilled to a temporary file, not a patch adding memory input; an upstream input callback is requested and would replace it |
| D4 | Vendor tree | byte-identical plus a recorded patch set, applied by the update script, verified in CI, offered upstream. At 1.6.5: 0001 makes the visibility macros overridable, 0002 adds `PDFIO_NO_STDIO`, 0003 enlarges two date buffers gcc's `-Wformat-truncation` flagged; none changes behaviour |
| D5 | Error callback | records and returns; never raises inside pdfio |
| D6 | JPEG | no decoder; DCT streams come back as JPEG bytes for `jpeg::readJPEG()` |
| D7 | Fonts | base-14 names or a file path; no system font lookup |
| D8 | Names | Two layers. §5.1 reuses pdftools's and qpdf's names with exactly their formals and return shapes. Every other export uses a name neither package exports. A shared name never means something else. |
| D9 | Determinism | by argument (`deterministic = TRUE`, `created =`), not by default |
| D10 | Text extraction | project code ported from `pdf2text.c`; pdfio has no text API |
| D11 | Values | R lists with marker classes `pdf_name`, `pdf_ref`, `pdf_binary`; not a parallel object model |
| D12 | The pin | 1.6.5 at Stage 0 (*verified 2026-10-08*: still the latest release); move to 1.7.0 when it is tagged, at which point the 1.7.0-only features of §9 switch on and `zupdf_info()` stops listing them as absent |
| D13 | Font table | The native table, with object numbers, is `pdf_font_table()`. `pdf_fonts()` is the pdftools-compatible view in §5.1. (This was §18 Q9.) |
| D14 | Writer text | `pdf_draw_text()`, alongside `pdf_draw()` and `pdf_draw_image()`. The RFC's `pdf_text()` is pdftools's extractor and belongs to §5.1. |
| D15 | Licence | `License: MIT + file LICENSE` with `Copyright: file inst/COPYRIGHTS`, Michael R Sweet as `cph`, pdfio's `NOTICE` reproduced (the zuhtml and data.sketches precedent; was §18 Q7, decided at Stage 0) |

Reasons where they are not in the section cited:

- **D1.** Neither library is in any distribution's package set that CRAN's builders have, and vendoring is what makes the install trivial.
- **D3.** A patch to the reader's I/O layer would be large and diverge from upstream; a temporary file is what `pdftools` also does for raw input.
- **D5.** Raising from inside pdfio would longjmp over open descriptors and heap state pdfio frees on its normal return.
- **D6.** The `jpeg` package decodes them in two lines, and vendoring a decoder (stb_image, libjpeg-turbo) would add a security surface to a package whose input is hostile.
- **D7.** The family's packages do not read the file system except where asked by path.
- **D8.** Decided 2026-10-08, reversing the RFC's rule of avoiding both packages' names. For non-rendering work, switching from pdftools or qpdf should only mean changing the `library()` call. That works only if a shared name keeps its arguments and its return value. A name reused for a different job, like the RFC's writer `pdf_text()`, would break exactly the code it was meant to carry over. When the packages are attached together, the one attached last masks the others' shared names. That is harmless only because the shared functions do the same thing.
- **D12.** The RFC wrote the API for 1.7.0 because `master` had it; a tarball must pin a release (the template's vendoring rule), and 1.6.5 carries the AES fix that puts a floor on the pin.

---

## 18. Open questions

Each stays the maintainer's until recorded above; the recommendation is the RFC's unless marked otherwise.

1. **`pdf_data()`** (words with positions), pdftools's function in §5.1, built from the text walk. The matrices are already tracked. The questions are whether the walk's word boxes can match pdftools's columns (`width`, `height`, `x`, `y`, `space`, `text`, plus the font columns under `font_info = TRUE`) closely enough to share the name, and what it costs. Not exported until decided; likely Stage 7 if the text port is solid.
2. **Streaming output** for very large reports: `pdfioFileCreateOutput()` delivers blocks, so a connection could receive them as pages close instead of at `pdf_save()`; the question is whether the writer can be reopened by R after an error mid-stream.
3. **Overlays and stamps**: §5.1 fixes the API as qpdf's `pdf_overlay_stamp(input, stamp, output, password)`. Copying a page as a Form XObject and drawing it onto another page is within pdfio's model. The open question is whether the result matches qpdf's closely enough (stamp scaling, which pages get stamped) to ship under that name.
4. **`zusvg` paths into content streams** (RFC 0007 §18), which would give SVG to PDF without a renderer.
5. **AES-256 writing** once pdfio removes its exclusion.
6. **Upstream acceptance** of an input callback (D3) and a no-stdio option (D4), which would empty the patch set.
7. *(Decided at Stage 0 as D15.)*
8. *(Settled at Stage 0: LZW is decoded only from 1.7.0; §9.)*
9. *(Decided 2026-10-08 as D13.)*
10. **`pdf_compress()`** (*new*). qpdf's version recompresses a file. If pdfio's `pdfioPageCopy()` copies page streams as stored, which Stage 5 confirms from the pinned source, then a zupdf rewrite would not compress an uncompressed file. A function named "compress" must not ship until it measurably compresses, for example by re-encoding unfiltered streams with Flate on copy. Object streams in 1.7.0 would help further. `linearize = TRUE` is `zupdf_unsupported_input` either way. Recommended: leave it out of 0.1.0 unless Stage 5 finds the re-encoding cheap.
11. **Following upstream signatures** (*new*). When pdftools or qpdf change a signature, zupdf has to decide whether to follow in its next release, and whether a shared name may ever gain arguments of its own. Recommended: follow within one release, and never add arguments to a shared name. Extra arguments belong on the native function, and the wrapper stays a wrapper.

---

## 19. Acceptance criteria for v0.1.0

1. Installs from source on Linux, macOS (x86-64, arm64) and Windows with no system package beyond R's own zlib, under `R CMD check --as-cran` with no NOTE beyond the new-submission one.
2. Every `afl-input` case is refused with a classed condition, no output on stderr, no leak under ASan.
3. Every fixture's text matches `pdftools` after normalisation in the conformance job; every written fixture opens in `qpdf` and `pdftools`.
4. Written bytes are identical across runners under `deterministic = TRUE`.
5. Every §11 class has a test; every §12 guard survives the mutation check.
6. No crash, leak, hang or stderr output in 30 minutes of nightly fuzzing; the canary has been seen to crash.
7. `tools/verify-vendor` passes against both pins plus the patches, and `tools/check-symbols` finds only the init symbol.
8. Every exported §5.1 wrapper has the same `formals()` as its original at the pinned versions, and returns the original's names, columns and classes on every fixture.

---

## 20. What this design does not decide

- Whether people who do not render will switch from pdftools for a smaller install. The Stage 0 survey (§3) shows that most reverse dependencies do not render; it cannot show whether they will switch.
- The drawing API's final shape (data frame paths versus a `grid`-like grammar), which Stage 4 settles by porting `md2pdf.c` and seeing what an R author needs.
- Whether upstream takes the patch set (D4).
- When 1.7.0 is tagged and the pin moves (D12).
