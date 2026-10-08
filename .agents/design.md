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
2. **`pdf_writer`**: a pdfio file being created with `pdfioFileCreateOutput()`, into a growable buffer the handle owns; `pdf_save()` closes it and returns the bytes or writes them to a path or connection (*Stage 4*: always through memory, since a path gains nothing but a second code path; streaming output is §18 Q2). pdfio writes a page's dictionary when the page is created and refuses to create any object while a content stream is open ("Another object is already open"), so a `pdf_page` from `pdf_page_new()` **records** its drawing operations in R, and `pdf_page_end()` writes the page in one call: it creates the page with the resources the operations use, opens the content stream, replays the operations through pdfio's content API (which encodes text for each font) and closes it (D16). No pdfio stream is open between calls, so fonts and images can be made at any time and an abandoned page needs no cleanup.
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
pdf_new(version = "1.7", media_box = pdf_paper("a4"), created = Sys.time(),
        deterministic = FALSE, ...)
pdf_page_new(w, media_box = NULL, crop_box = NULL, dict = NULL)
pdf_page_end(page)
pdf_draw_text(page, x, y, text, font = "Helvetica", size = 12, ...,
              colour = "black", align = c("left", "centre", "right"),
              line_height = 1.2)
pdf_font(w, x)             # base-14 name or a .ttf/.otf path
pdf_draw(page, path, fill = NULL, stroke = NULL, width = 1, ...,
         close = FALSE, rule = c("winding", "evenodd"))
pdf_image_new(w, x, interpolate = TRUE)   # a PNG/JPEG path or an R image
pdf_draw_image(page, image, x, y, width, height)
pdf_copy_pages(w, pdf, pages = NULL, rotate = 0)
pdf_set_meta(w, ...)
pdf_set_encryption(w, user = NULL, owner = NULL,
                   method = c("aes128", "rc4128"), permissions = "all")
pdf_save(w, file = NULL)   # raw, or writes file / connection

pdf_paper(name, landscape = FALSE)
zupdf_info()
```

- `pdf_open()`: `x` is a path, a raw vector or a connection; `password` is a string or a function of the file name returning one. A function is called only when the file needs a password: zupdf opens without one first, and if pdfio reports "Unable to unlock PDF file.", calls the function in R and opens again, so no R code runs inside pdfio's password callback and nobody is asked for a password an unencrypted file does not need (*Stage 1*). pdfio tries the empty password itself, then asks the callback, which answers once with the handle's password and then `NULL`. A wrong password is `zupdf_password_error`.
- `pdf_meta()`: the `pdfioFileGet*` metadata fields, the encryption as `"none"`, `"rc4-40"`, `"rc4-128"`, `"aes-128"`, `"aes-256"` and the permission bits as a character vector of the `PDFIO_PERMISSION_*` names in lower case.
- `pdf_page_text()`: text per page, one string each, by the extractor of §8, in `"reading"` order (lines by baseline, top to bottom) or `"raw"` stream order; U+FFFD for a code no mapping covers, counted in the `unmapped` attribute. The extractor builds UTF-8 itself, so its output is always valid.
- `pdf_page_tokens()`: zupdf's content lexer (§8) over the page's streams, one row per token with its type (`operator`, `number`, `name`, `string`, `array_open`, `array_close`, `dict_open`, `dict_close`, `inline_image`) and value; the raw material for anyone who needs more than `pdf_page_text()`.
- `pdf_stream()`: the object's stream, decoded through pdfio's filters (`decode = TRUE`) or the stored bytes, as a raw vector with attributes `decoded` (whether the filters were applied) and `filter` (the filter names); a filter pdfio cannot decode falls back to the stored bytes with `decoded = FALSE` (§9). Bounded by `max_stream`, checked as the bytes arrive, so a Flate bomb stops at the limit. The bytes go into a buffer the handle owns, and no R code runs while the stream is open (§13).
- `pdf_objects()`: `number`, `generation`, `type`, `subtype`, `length` (the stored stream length, `NA` without a stream). An object pdfio cannot load is listed with `NA`s, and its error becomes part of one `zupdf_warning`, so one broken object does not hide a million good ones.
- `pdf_image()`: the image's samples, decoded when the filter is Flate or none, with `width`, `height`, `bits`, `color_space`, `filter` and `decoded` attributes, or as a `nativeRaster` when the image is DeviceRGB or DeviceGray (or ICCBased with 3 or 1 components) at 8 bits that zupdf can decode, else `zupdf_unsupported_input`. DCT (JPEG), JPX and JBIG2 images come back as stored, so a JPEG is its JPEG file, for `jpeg::readJPEG()`, since pdfio does not decode JPEG and zupdf does not vendor a decoder (D6). An SMask (alpha) is not applied.
- `pdf_page_images()`: the image XObjects in a page's resources (inherited), with `object`, `name`, `width`, `height`, `bits`, `color_space` and `filter`; images inside forms and inline images are not listed.
- `pdf_font_table()`: every font object but CID descendants, which their Type0 parent stands for, with `object`, `name` (`/BaseFont`), `type` (`/Subtype`) and `embedded` (a `FontFile`, `FontFile2` or `FontFile3` in its descriptor, or its descendant's).
- The writer takes R colours for `fill`, `stroke` and `colour` through `col2rgb()`, without alpha; `NA` and `"transparent"` mean none. `path` is points (`x`, `y`), joined by lines, or a data frame of operations: `op` in `move`, `line`, `curve` (control points `x1`, `y1`, `x2`, `y2`, end `x`, `y`), `close`, `rect` (`x`, `y`, `w`, `h`). Coordinates are PDF points with the origin at the bottom left. `pdf_draw_text()` recycles `x`, `y` and `text`, splits text at line breaks, and aligns with `pdfioContentTextMeasure()` at replay; base-14 fonts show Windows code page 1252 and print `?` for other characters (pdfio's encoding).
- `pdf_image_new()`: a PNG or JPEG file (pdfio's own readers; JPEG is copied through), or a `nativeRaster`, a `raster` or colour matrix, a grey matrix in 0 to 1, or an RGB or RGBA array (as `png::readPNG()` returns); alpha becomes a soft mask.
- `pdf_font()`: a base-14 name (`pdfioFileCreateFontObjFromBase()`) or a font file path (`pdfioFileCreateFontObjFromFile()`, Unicode CID font). There is no system font lookup (D7).
- `pdf_copy_pages()`: zupdf's port of `pdfioPageCopy()` (*Stage 5*): the page dictionary and every attribute it inherits are copied, with every object they reference, through pdfio's object map (`_pdfioValueCopy()`), so the result is self-contained; `/Rotate` is then advanced by `rotate`, or set (the qpdf layer's absolute mode), before the page is written. `pdfioPageCopy()` itself writes the page as it copies it, leaving no way to rotate it. Streams are copied as stored, not re-encoded. Document-level parts (outlines, forms, named destinations) are not carried over.
- `pdf_set_meta()`: title, author, subject, keywords, creator (the Info dictionary, ASCII as literals and anything else as UTF-16BE), language (the catalog's `/Lang`) and modification date. In PDF 2.0 pdfio drops the Info entries at close and writes them only into the XMP metadata, which is UTF-8, so for 2.0 output they are set as UTF-8 (*Stage 5*); `pdf_new()` defaults to 1.7 for that reason, since many readers, `pdf_meta()` included, read only the Info dictionary.
- `pdf_set_encryption()`: must come before any page, font or image, since pdfio fixes the keys before the first object (anything later is `zupdf_write_error`). The encryption key is derived from the file ID, so `deterministic = TRUE` leaves the ID random for an encrypted file (§7).
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
pdf_data(pdf, font_info = FALSE, opw = "", upw = "")

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
| `pdf_info()` | `pdf_meta()`, the Info dictionary, the catalog | The same eleven fields. `keys` is the Info dictionary's text entries; `metadata` the XMP stream's text; `linearized` comes from a `/Linearized` among the first objects; `locked` is always `FALSE`, since a file zupdf could not unlock is an error. |
| `pdf_text()` | `pdf_page_text()` | pdftools returns poppler's physical layout, padded with spaces to page positions. zupdf returns the `pdf2text` reading order (§8). Pages and words match, but spacing differs and line order sometimes does. `raw = TRUE` is `layout = "raw"`, which is stream order in both packages. |
| `pdf_fonts()` | `pdf_font_table()` | For a non-embedded font, pdftools reports the system substitute fontconfig chose in `file`. zupdf reports `NA`, because it has no system font lookup (D7). |
| `pdf_pagesize()` | `pdf_pages()` | Same six columns (`top`, `right`, `bottom`, `left`, `width`, `height`). |
| `pdf_toc()` | the outline tree, walked under `max_depth` | Same nested `title` / `children` list. |
| `pdf_attachments()` | the `EmbeddedFiles` name tree | Same list of entries with their data. |
| `pdf_data()` | the text walk's glyphs (`zupdf_page_glyphs`) | Words split at spaces and word gaps along each glyph's writing direction; each box is the page-aligned box around its glyphs, from the font's descent to its ascent (descriptor, Type 3 bounding box or base-14 metrics), rounded to points, in reading order. On the Stage 7 fixtures every pdftools word is found and `x` agrees within 2 points; `y` agrees exactly except where poppler takes a font's ascent from elsewhere (a Type 3 font's height near twice its size). `space` can differ after rotated words. |
| qpdf's six | `pdf_open()`, `pdf_copy_pages()`, `pdf_save()` | pdfio writes the output, so the bytes differ from qpdf's. Pages, their content and their order are the same. `pdf_overlay_stamp()` waits for §18 Q3. |

Not provided: `pdf_render_page()`, `pdf_convert()`, `pdf_ocr_text()` and `pdf_ocr_data()` (they need a renderer), `poppler_config()` (there is no poppler), and `pdf_compress()` (§18 Q10: pdfio copies streams as stored, so a rewrite does not compress).

Found when the layer was built and compared with the originals (*Stage 5*): `pdf_toc()` items carry `is_open` (pdftools's third field; a positive `/Count`); `pdf_text()` ends every page's text with a line break, as poppler does; `pdf_fonts()` reports poppler's type names (`type1`, `type1c`, `truetype`, `type3`, `cid_type0`, `cid_type0c`, `cid_truetype`) and counts Type 3 fonts as embedded; `pdf_info()` reports an absent date as `NA` where pdftools reports one second before 1970; and the qpdf functions take any R index for `pages` (`-1` included) and report `"Selected pages out of range"` as qpdf does, but as a `zupdf_invalid_argument`. None of these is defined as a stub that always fails. A user who switches packages gets "could not find function" on the first call, and that message already names what is missing.

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

Names and strings must be distinguishable in both directions, hence the `pdf_name` class on a character scalar; a plain character in a dictionary given to the writer is a string. pdfio keeps every dictionary's keys sorted (it inserts with a binary search), so keys come out in sorted order whatever order they went in (*Stage 2*).

Text strings (*Stage 2*). pdfio converts a literal string with a UTF-16 byte-order mark to UTF-8 as it reads, but keeps a hex string as bytes, so zupdf decodes a byte string that begins `FE FF` as UTF-16BE text; any other byte string is `pdf_binary`. A string that is not valid UTF-8 is read as PDFDocEncoding. On the way out, pdfio would write a string's UTF-8 bytes into a literal, which other readers take as PDFDocEncoding, so zupdf writes an ASCII string as a literal and any other as UTF-16BE with its byte-order mark, which every reader decodes. pdfio's strings are C strings, so a literal string containing a NUL byte is cut at it.

The conversion (`src/zpd_value.c`) reads pdfio's value structures through `pdfio-private.h`: the public API cannot give an indirect reference's numbers when its target is missing, nor the value of an object that is neither a dictionary nor an array, and has no way to append `null` to an array. That ties zupdf to pdfio's internals, which `tools/update-pdfio` must re-check on every pin move. The writer accepts the same mapping for `pdf_set_meta()` and for the `dict =` of `pdf_page_new()`, which is how a caller sets what the API does not model, and refuses a value whose depth exceeds `max_depth`; an R `NULL` inside a list is written as PDF `null`.

---

## 7. Writing

pdfio writes objects as they close, cross-reference and trailer at `pdfioFileClose()`, compressing content streams with Flate; 1.7.0 adds object streams, which zupdf enables by default for 1.5 or later versions once that pin lands. Output is deterministic per input and arguments except for what pdfio takes from the clock and the random source: the creation date (`CreationDate`), the file ID, which pdfio 1.6.5 makes from random bytes (*found at Stage 4*; the RFC said time and file name), and, for encrypted files, the keys. zupdf sets the date from `created =` on `pdf_new()` (defaulting to `Sys.time()`) and, when `deterministic = TRUE`, replaces the ID with the first 16 bytes of the SHA-256 of everything written before the trailer, through pdfio's private `id_array` (no public setter exists). So the same calls give the same bytes with the same zupdf, pdfio and **zlib**: deflate output differs between zlib builds (zlib-ng, Apple's), so pinned bytes are recorded per zlib version in `tests/testthat/fixtures/hashes.tsv`, and a version without a row skips the pin. **Encrypted output is never byte-stable**: its keys are random (§18 has no plan to change that).

Encryption uses pdfio's own RC4, MD5, AES and SHA-256 (`pdfio-rc4.c`, `pdfio-md5.c`, `pdfio-aes.c`, `pdfio-sha256.c`): no OpenSSL, no `zucrypt`. These are the PDF standard's algorithms for its security handler, not a general-purpose crypto offering; zupdf's documentation says RC4 is there for compatibility and AES 128 is the one to use, and does not offer AES 256 for writing while pdfio marks it excluded.

---

## 8. Text extraction

pdfio has no text API, so the extractor is project C (D10): `src/zpd_lex.c`, `src/zpd_font.c` and `src/zpd_text.c`. It began as a port of pdfio's `examples/pdf2text.c`, but that example is far simpler than the RFC described (*found at Stage 3*): it tracks no text matrix, reads no ToUnicode CMap, treats every hex string as UTF-16 and starts a line at every `Td`, which works for pdfio's own output and garbles most other files. zupdf keeps its glyph-name table and encodings (`src/zpd_glyphs.h`, attributed in `inst/COPYRIGHTS`) and does the rest itself:

- **Reading.** A page's content streams are read whole through pdfio's Flate decoder, each bounded by `max_stream`, and closed before the walk starts, so no pdfio stream is open while the walk runs. A Form XObject's stream is read the same way when the walk reaches it.
- **Tokens.** zupdf's own lexer (`zpd_lex.c`), not `pdfioStreamGetToken()`. pdfio's tokenizer turns a literal string holding a NUL into hex, rewrites a string that begins with a UTF-16 byte-order mark, and cannot skip an inline image's binary data, all of which content streams contain. `pdf_page_tokens()` shows the same tokens.
- **State.** The CTM (`cm`, `q`/`Q`), the text and line matrices (`BT`, `Td`, `TD`, `Tm`, `T*`, `'`, `"`), font and size (`Tf`), character and word spacing, horizontal scaling, leading and rise. Each glyph's start and end are placed on the page through the text rendering matrix.
- **Fonts** (`zpd_font.c`), loaded once per file and cached by object number in the handle. Unicode comes from the ToUnicode CMap (`bfchar`, `bfrange` with a destination string or an array), else, for a simple font, from its encoding: `/Encoding` as a name, or a dictionary of `/BaseEncoding` and `/Differences`, with StandardEncoding as the default for a font with neither, and glyph names through the table, `uniXXXX` and `uXXXX[XX]`, with suffixes such as `.sc` dropped. A Type0 font reads two-byte codes, or one-byte codes when its CMap's code space says so. Widths come from `/FirstChar` and `/Widths`, or `/W` and `/DW` for a CID font, else pdfio's base-14 metrics, else an estimate. Type 3 fonts use their `/FontMatrix`. A CMap is bounded at a million entries (`GUARD: cmap_size`).
- **Unmapped codes** become U+FFFD, counted per page in the `unmapped` attribute. Control codes become spaces.
- **Form XObjects** (`Do`) are walked under their `/Matrix` and `/Resources`, to `max_depth` levels; a form drawn inside itself is refused as a `zupdf_limit_error` on `max_depth` (`GUARD: form_cycle`). Annotation appearance streams (form fields, stamps) are not page content and are not read; poppler reads them, so `pdftools::pdf_text()` can find text zupdf does not.
- **Inline images** (`BI` ... `ID` ... `EI`) are skipped by the lexer.
- **"raw" layout**: the glyphs' text in stream order, a line break where an operator moves to a new line (`T*`, `'`, `"`, a `Td`/`TD` with a vertical move, a `Tm` to a new baseline, `ET`), and a space for a `TJ` adjustment of a fifth of an em or more, or a horizontal-only `Td`.
- **"reading" layout**: glyphs (in stream order) are joined into spans along their own writing direction, so rotated text such as a plot's axis labels stays whole, with a space where the gap is 0.15 em or more and a new span after a gap of 3 em or a change of baseline. Spans are grouped into lines by the baseline of their start (within half the font size), top to bottom, and each line's spans left to right with a space between. Columns that share baselines come out side by side on one line, as in poppler's physical layout.
- **Memory and interrupts.** Everything the walk allocates (content buffers, glyphs, operand strings, fonts from direct dictionaries) hangs off one context the `pdf_file` owns (`text`), freed at the end of the call, at the start of the next, or by the finalizer; the font cache is the handle's too. `R_CheckUserInterrupt()` runs between pages, when only that context is in flight, not every 4 096 tokens as the RFC said; a single page is bounded by `max_stream` instead.

The text fixtures pin its output exactly in the package tests, and the conformance job compares it with `pdftools::pdf_text()` after whitespace normalisation. On the Stage 3 fixtures and the `afl-input` corpus the words agree, except where poppler reads annotation appearances or drops a glyph zupdf shows as U+FFFD.
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
- **Filters.** pdfio 1.6.5 decodes **only FlateDecode** (with PNG predictors): `_pdfioStreamOpen()` refuses every other filter with "Unsupported stream filter", and compound filters with "Unsupported compound stream filter" (*found at Stage 2*; the RFC also listed ASCII85, RunLength and ASCIIHex). LZW and compound filters arrive with 1.7.0; `pdfio-stream.c` at 1.6.5 has no LZW code (§18 Q8), so `zupdf_info()` lists `lzw` as absent. `pdf_stream(decode = TRUE)` on a stream pdfio cannot decode returns the stored bytes with `decoded = FALSE` and the filter names, for the caller to decode. Not DCT, JPX, JBIG2 or CCITT, whose streams come back undecoded with their filter name.
- **Encryption.** RC4 40 (reading), RC4 128, AES 128 read and write; AES 256 marked `@exclude all@` with a buffer-overflow fix in 1.7.0's change log, so zupdf exposes it for reading only when pdfio does and never for writing. The 1.6.5 release fixed an invalid-empty-string read in AES (GHSA-527h-2p2v-g388), which puts a floor on the pin.
- **1.7.0-only features**, absent from the 1.6.5 pin and stated as absent by `zupdf_info()` until the pin moves: LZW (if Stage 0 confirms), GIF images, object streams on write, the `pdfioPageGet*` accessors (zupdf reads the page dictionary directly instead), Unicode file names on Windows, the system font lookup (which zupdf does not use anyway).
- **Corpus.** `afl-input/` holds the PDFBox-derived crash cases and `afl-pdf.dict` a fuzzing dictionary; both are in the git tag but not in the release tarball (*found at Stage 0*), so `tools/update-fixtures` fetches them from the tag's commit. `testfiles/` in 1.6.5 holds fonts (Noto Sans JP, Open Sans, with their licences), images and ICC profiles, but only one PDF (`testpdfio.pdf`), so the reading fixtures come mostly from other producers (§15). zupdf's fuzz job seeds from `afl-input` and the dictionary; the test fixtures take the small files from `testfiles` and the licences with them.
- **Standard and warnings.** C99 with `ssize_t`, `open()`, `lseek()` and `unistd.h` on POSIX and the Windows CRT equivalents under `_WIN32`; no threads. Random bytes for encryption come from `arc4random()` on macOS, `CryptGenRandom()` on Windows and `/dev/urandom` elsewhere (`HAVE_GETRANDOM` is not defined), with a time-seeded fallback; none is the C library's `rand()`. The first build (*Stage 0*) is clean under clang's `-Wall -pedantic -Wstrict-prototypes`; `-Wextra` adds function-type-cast and null-pointer-subtraction warnings; at first they were recorded and not patched, since CRAN's flags do not print them, until UBSan in CI (Stage 1) reported the same sites as undefined behaviour at run time, and patch 0004 fixed them. gcc's `-Wformat-truncation` (on by default with `-Wall`) flagged two 32-byte date buffers, which patch 0003 enlarges. Anything CRAN's flags print is patched, not silenced, and never by a diagnostic-suppressing pragma.

Vendoring follows zucbor §13 and the template: `src/vendor/pdfio/` is byte-identical to the files `tools/pdfio-files.txt` lists from the release tarball, plus the recorded patch set in `tools/patches/`, applied by `tools/update-pdfio` and verified by `tools/verify-vendor` in CI (`vendor.yaml`); `src/vendor/PROVENANCE` records the tag, its commit, the tarball checksum, every patch with its reason, and the warnings seen. Each patch adds a modification notice to the files it changes (Apache-2.0 §4(b)). `inst/COPYRIGHTS` reproduces pdfio's `NOTICE` with its exception text; `LICENSE.note` records provenance; the fixtures' font licences ride along. The `License:` field is D15.

---

## 10. Input sources and temporary files

| Input | Handling |
|---|---|
| path | `pdfioFileOpen()` on it; kept open by the handle |
| raw vector | written to a temporary file the handle owns |
| connection | read in blocks to a temporary file, under `max_size` |
| `pdf_file` | passed through |

The temporary file is made with `tempfile("zupdf-", fileext = ".pdf")` under R's session directory, which R removes at exit; the handle's finalizer unlinks it earlier. `pdfioFileCreateTemporary()` is not used because its location is pdfio's choice, not R's. A raw vector longer than `max_size` is refused before writing.

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

Every condition inherits `zupdf_error` and carries pdfio's message verbatim as `detail`; a parse error carries `object` when pdfio named one. Warnings (`zupdf_warning`) carry pdfio's first `WARNING:` message as `detail` and the number of warnings as `count`, once per call. pdfio's errors are strings, so R maps known message prefixes to classes and anything else is a bare `zupdf_parse_error` or `zupdf_write_error`; a test enumerates the prefixes (§15). Tests assert on class.

| pdfio's message begins | Class |
|---|---|
| `Unable to unlock PDF file.` | `zupdf_password_error` |
| `Unable to unlock AES-256` | `zupdf_unsupported_input` |
| `Unable to open file` | `zupdf_io_error` |

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

A `pdf_file` owns its `pdfio_file_t`, its temporary file and its text caches in one external pointer; `pdfioFileClose()` runs in the finalizer if `pdf_close()` did not, and a closed handle is refused by every function. A `pdf_writer` owns the pdfio file, the output buffer and its font and image objects; a `pdf_page` is an R environment of recorded operations and holds nothing of pdfio's, so an abandoned page leaks nothing and the writer's finalizer only closes the file (*Stage 4*). Nothing pdfio allocates is ever held outside an external pointer, and no R allocation happens while a pdfio stream is open: a stream is read into a `malloc()` buffer the `pdf_file` owns (`scratch`), the stream is closed, and only then does R allocate the result and copy (*Stage 2*). The buffer is freed after the copy, by the next read, or by the finalizer, so an R allocation failure cannot leak it. User code never runs inside pdfio: the password callback answers from a string the handle holds (a function `password` is called in R between two attempts to open, §5).

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

- **Fixtures.** pdfio's `testpdfio.pdf`, PDFs written by `grDevices::pdf()`, `cairo_pdf()`, LaTeX and LibreOffice (one each, CC0 content), encrypted files written by pdfio itself at each method (`tools/fixtures/make-encrypted.c`, compiled against the vendored tree), and the `afl-input` cases. Each `afl-input` case must open and read, or be refused with a classed condition, with nothing on stderr. At 1.6.5 all 23 open, since pdfio has fixed the crashes they came from (*Stage 1*; the RFC said they must all be refused). The LaTeX and LibreOffice fixtures wait for a machine that has those tools. `tools/update-fixtures` pulls them; nothing is hand-edited; `tests/testthat/fixtures/README.md` lists sources and licences.
- **Reading.** `pdf_meta()`, `pdf_pages()`, `pdf_objects()` pinned per fixture; `pdf_page_text()` pinned exactly in the package tests.
- **Conformance** (`tools/run-conformance`, `conformance.yaml`, *Stage 7*). Word recall against `pdftools::pdf_text()` of at least 0.9 on every fixture pdftools reads, except those whose text is in annotation appearances; every pdftools word found by `pdf_data()` with `x` within 2 points; `pdf_info()`, `pdf_pagesize()` and `pdf_length()` equal to the originals' on the fixtures; every kind of file zupdf writes (base-14 and embedded text, shapes, PNG, JPEG and R images, copied and rotated pages, encryption) read by pdftools with the same words, counted by qpdf, and passed by `qpdf --check`; deterministic bytes identical twice over, with their MD5 and zlib version printed per runner.
- **Writing.** Each writer function's bytes pinned under `deterministic = TRUE`; every written file reopened with `pdf_open()` and, in the conformance job, with `qpdf::pdf_length()` and `pdftools::pdf_text()` to prove other readers accept it; `qpdf --check` where the binary exists.
- **Round trips.** `pdf_copy_pages()` of every fixture into a new file, then text and page boxes equal.
- **Compatibility.** Whenever the original is installed, each §5.1 wrapper's `formals()` must be identical to its original's. On every fixture, return values are compared with the originals' for names, columns and classes, and for values wherever the §5.1 table says they agree: `pdf_info()` fields, `pdf_pagesize()`, `pdf_length()`, and the page counts and text of split, subset, combined and rotated output. `pdf_text()` is compared after whitespace normalisation, like `pdf_page_text()`.
- **Limits and faults.** Each §11 class with a crafted file: a Flate bomb for `max_stream`, a self-referencing object stream and a page tree cycle for `max_depth`, a million-object xref for `max_objects`, a wrong password, a WebP image. A test enumerates every pdfio message prefix the class map knows and asserts the map; an unknown prefix falls to the bare class deliberately.
- **Memory.** A thousand `pdf_open()` calls without `pdf_close()` leave no descriptors (checked by `ls /proc/self/fd` on Linux) and no temporary files once `gc()` runs; gctorture and valgrind as zucbor.
- **Fuzzing** (`fuzz/fuzz_pdf.c`, `tools/run-fuzz`). libFuzzer with ASan and UBSan over the R-free core (*Stage 6*: `zpd_core.c`, `zpd_lex.c`, `zpd_font.c` and the text walk compile with `-DZPD_STANDALONE`): open with zupdf's error callback, load every object and read every stream under a bound, extract every page's text in both layouts. Seeds are the fixtures (the `afl-input` corpus among them), the dictionary pdfio's `afl-pdf.dict`. Two minutes per pull-request push and 30 nightly, the corpus cached between runs; invariants: no crash, leak, hang past the timeout, or undefined behaviour. `fuzz_canary` must crash first. Every input the fuzzer finds is fixed and kept in `tests/testthat/fixtures/fuzz/`, which the suite reads. The first five-minute run found a negative `/W` entry cast to `size_t` in pdfio's cross-reference reader, which led to patch 0007 for all 23 such casts; the next found the same in zupdf's font loader (a huge `/FirstChar`), after which every file-derived number in project C goes through `zpd_clamp_int()`.
- **Mutation** (`tools/run-mutation-check`). Every guard on a limit carries a unique `GUARD: name` marker: `max_size`, `max_objects`, `max_pages` (R), `max_depth_inherit`, `max_depth_read`, `max_depth_write`, `max_stream`, `max_stream_content`, `form_cycle`, `max_depth_form` (C). Each is disabled in turn in a scratch copy of the built package, which is reinstalled (only the changed file recompiles), and its R probe must then get a different answer: another result, a crash, or a hang past a timeout. The CMap bounds (`cmap_entries`, `cmap_cps`, `cid_widths`) are fixed at a million entries and are not mutation-checked: only a 30 MB font reaches them.
- Tests are self-sufficient, pass under `shuffle = TRUE`, stay serial, and the CRAN suite runs in under 15 s; the thousand-handle test and the bombs call `skip_heavy()`.

---

## 16. Performance targets

Measured by `tools/run-benchmarks` against `pdftools` and `qpdf` on files it builds, the median of several runs. Targets, and the first measurement (*Stage 7*, 2026-10-08, Apple M-series, R 4.6.1, pdftools 3.9.0, qpdf 1.4.1):

| Task | Target | zupdf | Other |
|---|---|---|---|
| `pdf_open()` + `pdf_meta()`, 100 pages | under 5 ms | 1 ms | `pdftools::pdf_info()` 1 ms |
| `pdf_page_text()`, 100 pages of text | within 2× of pdftools | 12 ms | `pdftools::pdf_text()` 62 ms (zupdf 0.19×) |
| merging 100 one-page files | within 2× of qpdf | 10 ms | `qpdf::pdf_combine()` 9 ms (1.1×) |
| writing a 100-page report of text and paths | under 200 ms | 168 ms | |

The conformance job on CI runs the same script after its checks, on Linux and macOS, for comparison; it is informational.
---

## 17. Decisions

| # | Question | Decision |
|---|---|---|
| D1 | Libraries | pdfio vendored, not linked, with its ttf library, which ships in the same release tarball and tree from 1.6.0 |
| D2 | Rendering | never, from this package; the API has no `render` slot to fill |
| D3 | Raw and connection input | spilled to a temporary file, not a patch adding memory input; an upstream input callback is requested and would replace it |
| D4 | Vendor tree | byte-identical plus a recorded patch set, applied by the update script, verified in CI, offered upstream. At 1.6.5: 0001 makes the visibility macros overridable, 0002 adds `PDFIO_NO_STDIO`, 0003 enlarges two date buffers gcc's `-Wformat-truncation` flagged, 0004 removes the undefined behaviour UBSan found (calls through mistyped function pointers, `memcpy()` from NULL, pointer arithmetic on NULL), 0005 the signed overflow in big-endian byte reads (Stage 4, reading a TrueType font), 0010 the ttf callbacks' mistyped function pointers (Stage 4), 0006 stops `pdfioDictGetString()` rewriting a UTF-16 value as UTF-8 when it reads it (Stage 5, metadata), 0007 clamps every number read from a file before converting it to an integer, 0008 stops the cross-reference repair looping for ever on a damaged file, 0009 clamps the one cast 0007 missed and 0011 frees an object's own hex-string value, which leaked (Stage 6, all found by fuzzing), and 0012 frees a trailer that is not a dictionary before refusing it (Stage 7, fuzzing); none changes how well-formed files are read |
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
| D16 | Writing pages | A `pdf_page` records operations in R; `pdf_page_end()` creates the page and replays them through pdfio's content API in one call, so no content stream is open between calls (*Stage 4*: pdfio refuses to create objects while one is open) |
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

1. *(Decided at Stage 7: `pdf_data()` ships; its boxes agree with poppler's closely enough to share the name, §5.1.)*
2. **Streaming output** for very large reports: `pdfioFileCreateOutput()` delivers blocks, so a connection could receive them as pages close instead of at `pdf_save()`; the question is whether the writer can be reopened by R after an error mid-stream.
3. **Overlays and stamps**: §5.1 fixes the API as qpdf's `pdf_overlay_stamp(input, stamp, output, password)`. Copying a page as a Form XObject and drawing it onto another page is within pdfio's model. The open question is whether the result matches qpdf's closely enough (stamp scaling, which pages get stamped) to ship under that name.
4. **`zusvg` paths into content streams** (RFC 0007 §18), which would give SVG to PDF without a renderer.
5. **AES-256 writing** once pdfio removes its exclusion.
6. **Upstream acceptance** of an input callback (D3) and a no-stdio option (D4), which would empty the patch set.
7. *(Decided at Stage 0 as D15.)*
8. *(Settled at Stage 0: LZW is decoded only from 1.7.0; §9.)*
9. *(Decided 2026-10-08 as D13.)*
10. *(Decided at Stage 5: `pdf_compress()` is not in 0.1.0. pdfio's object copy writes streams as stored (`pdfioObjCopy()` opens the source with `decode = false`), so a rewrite compresses nothing; re-encoding unfiltered streams is future work.)*
11. **Following upstream signatures** (*new*). When pdftools or qpdf change a signature, zupdf has to decide whether to follow in its next release, and whether a shared name may ever gain arguments of its own. Recommended: follow within one release, and never add arguments to a shared name. Extra arguments belong on the native function, and the wrapper stays a wrapper.

---

## 19. Acceptance criteria for v0.1.0

1. Installs from source on Linux, macOS (x86-64, arm64) and Windows with no system package beyond R's own zlib, under `R CMD check --as-cran` with no NOTE beyond the new-submission one.
2. Every `afl-input` case opens and reads or is refused with a classed condition, with no output on stderr and no leak under ASan.
3. Every fixture's text matches `pdftools` after normalisation in the conformance job; every written fixture opens in `qpdf` and `pdftools`.
4. Written bytes are identical across runs and across runners with the same zlib under `deterministic = TRUE`, for unencrypted files (§7).
5. Every §11 class has a test; every §12 guard survives the mutation check.
6. No crash, leak, hang or stderr output in 30 minutes of nightly fuzzing; the canary has been seen to crash.
7. `tools/verify-vendor` passes against both pins plus the patches, and `tools/check-symbols` finds only the init symbol.
8. Every exported §5.1 wrapper has the same `formals()` as its original at the pinned versions, and returns the original's names, columns and classes on every fixture.

---

## 20. What this design does not decide

- Whether people who do not render will switch from pdftools for a smaller install. The Stage 0 survey (§3) shows that most reverse dependencies do not render; it cannot show whether they will switch.
- Whether upstream takes the patch set (D4).
- When 1.7.0 is tagged and the pin moves (D12).
