# zupdf — Roadmap to 0.1.0 (first CRAN release)

Companion to [design.md](design.md). Section references (§) point there.

**Status:** adopted 2026-10-08 from [RFC 0008](https://github.com/pedrobtz/packages/blob/main/rfcs/0008-zupdf-pdf-files.md). Nothing below is implemented; the repository is the `usethis` skeleton (created 2026-10-08 with `create-pkg.sh -c`) plus these documents.

## Sequencing principles

1. **Portability is proven at Stage 0, not discovered at Stage 8.** Two vendored trees, zlib on three platforms and CRAN's compiled-code check are the schedule risk; the first stage is a three-platform build with `tools/check-symbols` passing and the patch set decided.
2. **Reading before writing, and the object layer before the text layer.** `pdf_object()` and `pdf_stream()` are what every later reader is built from and what the fuzz target drives; the text port (§8) is the largest piece of project C and lands only on a proven object layer.
3. **The limits land with `pdf_open()`.** `max_size`, `max_objects`, `max_pages` bound before the call and `max_stream`, `max_depth` during it, from the first stage that opens a file.
4. **Determinism by argument, proven when the writer lands.** Every writer test pins bytes under `deterministic = TRUE` from Stage 4 on.
5. **Every stage ends with something runnable and tested**, and is done when its exit criteria pass in CI on all three platforms.
6. **Gates need canaries.** `verify-vendor` on a one-byte edit, `check-symbols` on a plant, `fuzz_canary` crashing, a removed guard accepting its hostile file.
7. **Change the design in the same commit as the contract.**

Sizes are relative: **S** ≈ a sitting, **M** ≈ a few, **L** ≈ the stage is the week.

**Status never goes in a heading.** A heading is `## Stage N — Title · Size` and nothing else; the state is the **Status:** line under it.

**Tracking.** A `v0.1.0` parent issue and one `stage`-labelled sub-issue per stage, each linking to its heading here. None exists on 2026-10-08; Stage 0 opens them and `.github/scripts/stage-cards.sh` in `pedrobtz/packages` puts the parent on the board. Each stage gains a **What actually happened** block when it closes.

## The release order, and what it costs

`LinkingTo: zufast (>= 0.1.0)` is unconditional (UTF-8 validation of extracted text), so **zufast must be on CRAN before zupdf can be submitted** (alignment R10.2). On 2026-10-08 zufast is tagged 0.1.0 and not on CRAN; `Remotes: pedrobtz/zufast@main` carries development and Stage 8 removes it. pdfio's pin is 1.6.5 (D12); if 1.7.0 is tagged before Stage 8, the pin moves in its own pull request through `tools/update-pdfio`, and the 1.7.0-only features of §9 switch on with their tests.

Nothing waits on zupdf.

## Working rhythm

One pull request per stage: branch `stage-N-<slug>` from `main`; `devtools::document()`, `devtools::test()`, `devtools::test(shuffle = TRUE)` and `devtools::check(cran = TRUE)` clean at 0/0/0 locally before pushing; the PR body states the stage and its exit criteria as a checklist, carries `Closes #<n>` and the `full-ci` label (every stage touches `src/`); every CI leg green before merging; then update `.claude/CLAUDE.md`'s current-state paragraph and the **Status:** line.

Local traps the siblings hit: roxygen2 must be 8.1.0 or newer; `_R_CHECK_SYSTEM_CLOCK_=0` for offline checks; `tools/check-symbols` runs on an `R CMD INSTALL` build, never a `load_all()` one.

## Testing strategy, fixed once

- Self-sufficient tests: inputs built inside each `test_that()`, or read from `fixtures/`; files under `withr::local_tempdir()`; handles closed by `withr::defer()` or left for the finalizer test deliberately.
- Assert on condition classes and fields (`detail`, `object`, `limit`, `limit_value`), never message text.
- Serial testthat, no `Config/testthat/parallel`; `shuffle = TRUE` in every definition of done; shared code only in `helper-*.R`.
- Helpers: `helper-pdf.R` (`fixture(name)`; `minimal_pdf()` building a one-page file from a template; `encrypted_fixture(method)`), `helper-expect.R` (`expect_zupdf_error(expr, class, ...)`, `expect_pdf_bytes(w, hash)`, `expect_text_equal(a, b)` with whitespace normalisation), `helper-skip.R` (`skip_heavy()` on `ZUPDF_SKIP_HEAVY`, set by the gctorture and valgrind legs; `skip_if_no_slow_tests()` on `ZUPDF_SLOW_TESTS`; `skip_if_not_installed("pdftools")`, `("qpdf")`, `("jpeg")`).
- Fixtures: pdfio's small `testfiles/`, one PDF each from `grDevices::pdf()`, `cairo_pdf()`, LaTeX and LibreOffice, the `afl-input` cases, encrypted variants written by zupdf; `fixtures/README.md` with sources and licences; `hashes.tsv` of pinned writer bytes read with `colClasses = "character"`; fetched only by `tools/update-fixtures`.
- CRAN budget: under 15 s; the thousand-handle, Flate-bomb and million-object tests call `skip_heavy()`.

## CI, and the stage each workflow lands in

Reusable workflows from `pedrobtz/r-actions`; the scaffold's three exist at `@v1`, and Stage 0 pins `coverage.yaml` by commit (write token) and adds Dependabot (alignment R5).

| Workflow | Stage | What it checks |
|---|---|---|
| `R-CMD-check.yaml` (exists) | 0 | runners and the CRAN-like containers; quick on PRs, full on `main` and with `full-ci`; zufast from `Remotes`; zlib found on every leg |
| `coverage.yaml` (exists) | 0 | badge on `main`; pinned by commit; `native: true` |
| `pkgdown.yaml` (exists) | 0 | the site; `development: mode: auto` |
| `vendor.yaml` | 0 | r-actions `vendor.yml`: `tools/verify-vendor` on both trees plus patches; a `symbols` job running `tools/check-symbols` on an installed build |
| `vendor-upstream.yaml` | 0 | r-actions `vendor-upstream.yml`: a new pdfio or ttf tag opens an issue (this is how the 1.7.0 tag is noticed) |
| `native-checks.yaml` | 1 | sanitizers (with `-UNDEBUG`), valgrind, LTO, gctorture, blocking rchk |
| `hardening.yaml` | 6 | `tools/run-fuzz` through r-actions `fuzz.yml` (canary, then the open/object/text target seeded from `afl-input` with `afl-pdf.dict`; per-input timeout; cached corpus; nightly long run); `tools/run-lint`; `tools/run-mutation-check`; `tools/check-no-network` |
| `conformance.yaml` | 7 | `pdftools::pdf_text()` agreement after normalisation; `qpdf` and `pdftools` open every written fixture; `qpdf --check`; bytes identical across runners; `tools/run-benchmarks` informational |

## Stage map

| Stage | Size | Needs | Delivers |
|---|---|---|---|
| 0 — Vendor trees, patch set, tools, first build | L | — | pdfio 1.6.5 and ttf compiled into a 0/0/0 package on three platforms; `verify-vendor`, `check-symbols`, `PROVENANCE`; the licence decision; the audience survey; tracking issues |
| 1 — `pdf_open()`, `pdf_close()`, `pdf_meta()`, `pdf_pages()`, limits | M | 0 | the `pdf_file` handle, temporary-file spill, the error and password callbacks, the §11 classes, `max_size`/`max_objects`/`max_pages` |
| 2 — Objects: `pdf_objects()`, `pdf_object()`, `pdf_stream()`, values | M | 1 | the §6 mapping both ways, `max_stream`, `max_depth` in conversion |
| 3 — Text: `pdf_page_text()`, `pdf_page_tokens()`, `pdf_font_table()`, images | L | 2 | the `pdf2text` port, the font and CMap cache, `pdf_page_images()`, `pdf_image()` |
| 4 — Writer: `pdf_new()`, pages, text, paths, images, fonts, `pdf_save()` | L | 2 | the `pdf_writer` and `pdf_page` handles, output callback, `deterministic = TRUE` |
| 5 — `pdf_copy_pages()`, metadata, encryption, compatibility layer | L | 3, 4 | assembly, `pdf_set_meta()`, `pdf_set_encryption()`, encrypted fixtures, the §5.1 wrappers |
| 6 — Fuzz target, mutation check, hardening CI | M | 3, 5 | `fuzz_pdf`, `fuzz_canary`, `hardening.yaml`, every `/* GUARD */` mutation-checked |
| 7 — Conformance, benchmarks, `pdf_data()`? | M | 6 | `conformance.yaml`; benchmarks recorded; §18 Q1 decided |
| 8 — Site, vignettes, CRAN | S | 7, and zufast on CRAN | the submission |

---

## Stage 0 — Vendor trees, patch set, update and verify tools, first build · L

**Status:** done, 2026-10-08. One deviation: the parent issue is not yet on the board, because `stage-cards.sh` lives in `pedrobtz/packages` and needs `zupdf:1` added there.

**Goal:** pdfio 1.6.5 and its `ttf` library compile into `zupdf.so` on Linux, macOS and Windows against each platform's zlib, byte-identical to their tags plus a recorded patch set, with no forbidden symbol, and the package checks 0/0/0 before any `pdf_*` function exists.

**Do**

- **Re-check upstream first**: the latest pdfio release on 2026-10-08 is v1.6.5 and there is no 1.7.0 tag; if that has changed, pin 1.7.0 and strike the 1.6.5 caveats from design §9.
- **Decide §18 Q7** (the `License:` field) and write `LICENSE`, `LICENSE.md`, `inst/COPYRIGHTS` (both `NOTICE` files with their exception text) and `LICENSE.note` accordingly; `Authors@R` Pedro Baltazar (`aut`, `cre`, `cph`) plus Michael R Sweet as `cph` with a comment naming pdfio and ttf (re-check the vendored file headers).
- `DESCRIPTION`: `Title: Read, Assemble and Write 'PDF' Files`; a `Description` naming pdfio, what is read, assembled and written, and that nothing is rendered; `Depends: R (>= 4.1)`; `LinkingTo: zufast (>= 0.1.0)`; `Remotes: pedrobtz/zufast@main` (development only); `Suggests: pdftools, qpdf, jpeg, png, testthat (>= 3.0.0), withr, knitr, rmarkdown`; `VignetteBuilder: knitr`; `Language: en-GB`; `Config/roxygen2/version: 8.1.0`; `URL`, `BugReports`; `Config/testthat/edition: 3`, no `parallel`; empty `SystemRequirements`.
- `tools/update-pdfio <pdfio-tag>`: fetch the pdfio release tarball and the ttf tree at the submodule commit, record SHA-256s, copy the listed files (`tools/pdfio-files.txt`, `tools/ttf-files.txt`: the library sources and headers, `LICENSE`, `NOTICE`; no examples, tests, `Makefile.in`, IDE projects or documentation) into `src/vendor/pdfio/` and `src/vendor/ttf/`, apply `tools/patches/*.patch` in order, write `src/vendor/PROVENANCE`. `tools/verify-vendor` re-derives both trees and fails on any difference; seen to fail on a one-byte edit, a stray file and a dropped patch.
- `src/Makevars` as §14: hand-listed objects (count 1.6.5's), `-I vendor/pdfio -I vendor/ttf -DPDFIO_STATIC`, `$(C_VISIBILITY)`, `PKG_LIBS = -lz`; no `Makevars.win`. `src/init.c` registering an empty table; delete `src/zupdf.c`.
- **The first build under `-Wall -Wextra -pedantic`** on all three platforms, zlib's header found on each (Rtools on Windows; R's own tree on macOS); record every vendor warning in `PROVENANCE`; patch what CRAN's flags would print.
- `tools/check-symbols` on an installed build (no `stdout`, `stderr`, `printf`, `fprintf`, `fputs`, `puts`, `abort`, `exit`, `assert`, `rand`; stream symbols as well as functions); seen to fail on a planted `fprintf(stderr, ...)`. Every hit in the vendor trees (the default error callback's `stderr` write, `copy_png()`'s `fputs`, the `DEBUG` printers, `ttf-cache.c`'s path if present at the pin) becomes a patch in `tools/patches/`, never a justification.
- **Decide §18 Q8** (LZW at 1.6.5) by reading `pdfio-stream.c` at the pin; record in §9.
- `zupdf_info()` as the first `.Call`: pdfio and ttf version strings, zlib's version (`zlibVersion()`), the patch identifiers (asserted by `test-info.R`), the features the pin lacks.
- `vendor.yaml` and `vendor-upstream.yaml` from r-actions.
- **The audience survey** (§20): the reverse dependencies of `pdftools` and `qpdf` on CRAN and which of their functions each calls; record in design §3 whether a non-rendering package serves most of them.
- `.Rbuildignore` (`^\.agents$`, `^\.claude$` added with these documents; `^tools$`, `^fuzz$`, `^cran-comments\.md$`, object patterns), `.gitignore`, `NEWS.md` `# zupdf 0.0.0.9000`, `tests/testthat/test-init.R` (written before the template test is removed), `R/conditions.R` with the §11 hierarchy, `coverage.yaml` pinned by commit, `.github/dependabot.yml`, `_pkgdown.yml` with `development: mode: auto`.
- Verify `zpd_` is free against every sibling's `src/` and `inst/include/`.
- Open the tracking issues; create the `stage` and `full-ci` labels.

**Exit**

- `devtools::check(cran = TRUE)` 0/0/0 locally; `R-CMD-check.yaml` green on every leg including Windows and the clang containers; R-devel in C23, oldrel with its default standard.
- `tools/verify-vendor` reproduces both trees and has been seen to fail; `tools/check-symbols` passes on the installed build and has been seen to fail; `vendor.yaml` green.
- `zupdf_info()` reports versions, patches and the absent features; `PROVENANCE` complete.
- §18 Q7 and Q8 decided and recorded; the survey's result in design §3.
- The tracking issues exist and the parent is on the board.

**Trap:** if a platform fights the build, fix configuration in `Makevars` or a project-owned header first; a vendor patch is the last resort, through `tools/patches/` and `PROVENANCE`.

**Not this stage:** any `pdf_*` function beyond `zupdf_info()`.

**What actually happened**

- **One tree, not two.** From 1.6.0, ttf ships inside pdfio's own release tarball (`ttf.c`, `ttf.h`), so there is one vendor tree, `src/vendor/pdfio/`, one pin and one checksum. Design D1 and §9 amended.
- **The patch set is three patches**, each adding a modification notice. `0003-date-buffer` came from the first gcc run in CI (`-Wformat-truncation` on two date buffers); the other two: `0001-visibility-override` (pdfio marks its API `visibility("default")`, which would export it past `$(C_VISIBILITY)`; not foreseen by the design) and `0002-no-stdio` (`PDFIO_NO_STDIO`: the default error callback, ttf's `errorf()` fallback, and the three debug printers, which are compiled in every build, not only under `DEBUG`). `copy_png()`'s `fputs` is under `HAVE_LIBPNG` and never compiled.
- **`check-symbols` checks exports too**: only `R_init_zupdf` may be an exported text symbol. Its canary plants both a `fprintf(stderr)` and an extra export.
- **Warnings**: none under clang `-Wall -pedantic -Wstrict-prototypes`; `-Wextra` adds function-type casts and one null-pointer subtraction, recorded in `PROVENANCE`.
- **§18 Q7** decided as D15 (`MIT + file LICENSE`, `Copyright: file inst/COPYRIGHTS`). **§18 Q8**: no LZW at 1.6.5.
- **`afl-input`** is in the git tag but not in the release tarball, so Stage 1's `tools/update-fixtures` fetches it from the tag's commit. The tarball's `testfiles/` has only one PDF.
- **The audience survey** is in design §3: of 79 CRAN packages calling pdftools or qpdf functions, 50 use only what 0.1.0 provides and 24 render or OCR.
- `zupdf_info()` gained a self-test (`smoke_ok`) that writes a one-page PDF in memory through pdfio and zlib.
- Test infrastructure (helpers, conditions, `minimal_pdf()`) landed first, in #11.

---

## Stage 1 — `pdf_open()`, `pdf_close()`, `pdf_meta()`, `pdf_pages()`, limits · M

**Status:** done, 2026-10-08. Deviations: the LaTeX and LibreOffice fixtures wait for a machine with those tools (`cairo.pdf` is written where cairo loads); the `afl-input` exit criterion reads "read or refused", since all 23 cases open at 1.6.5.

**Do**

- `src/zpd_file.c`: the `pdf_file` external pointer owning the `pdfio_file_t *`, the temporary-file path, the recorded error message and the password string; the error callback that records and returns (D5); the password callback answering from the handle; `pdfioFileClose()` in the finalizer and in `pdf_close()`; a closed handle refused everywhere.
- `R/open.R`: path, raw vector (spilled to `tempfile(fileext = ".pdf")` under `max_size`) and connection (read in blocks to the same, under `max_size`) inputs; `password` as a string or a function called in R; `max_objects` checked after the xref (`pdfioFileGetNumObjs()`), `max_pages` after the page count.
- `pdf_meta()` from the `pdfioFileGet*` getters; encryption and permissions as §5; `pdf_pages()` from each page's dictionary (media box, crop box, rotate, stream count), since the 1.6.5 pin lacks `pdfioPageGet*`.
- `print.pdf_file`, `length.pdf_file`.
- `R/conditions.R`: every §11 class; the message-prefix map and the test that enumerates it.
- Tests: open each fixture by path, raw and connection; wrong and right passwords on the encrypted fixtures (written at Stage 5; until then pdfio's own encrypted `testfiles`); the `afl-input` cases each refused with a classed condition and no stderr output (captured); a thousand opens without close leave no descriptors or temp files after `gc()` (`skip_heavy()`).
- `native-checks.yaml` lands.

**Exit**

- Every `afl-input` case is read or refused cleanly under ASan; every §11 reading class has a test; `native-checks.yaml` green.


**What actually happened**

- **Password functions** are called only when needed: zupdf opens without a password first and calls the function after pdfio reports "Unable to unlock PDF file.", then opens again. pdfio itself tries the empty password, then asks the callback up to three times; the callback answers once and then `NULL`. Design §5 and §13 amended.
- **A failed open keeps the spilled copy** until R gives up, so the retry with a password from a function can read it; R removes it then.
- **Encrypted fixtures** come from `tools/fixtures/make-encrypted.c`, compiled by `tools/update-fixtures` against the vendored pdfio (pdfio's own `testpdfio` writes 5 MB files, embedding a CJK font). They exist now, not at Stage 5.
- **All 23 `afl-input` cases open and read** at 1.6.5, and nothing reaches stderr (a child-process test, `skip_heavy()`).
- **Strings**: pdfio converts UTF-16BE to UTF-8 as it reads; zupdf keeps valid UTF-8 and reads anything else as PDFDocEncoding (`src/zpd_string.c`), which design §6 already called for at Stage 2.
- **UBSan in CI found undefined behaviour in pdfio**: calls through function pointers of another type (the token, crypt and comparator callbacks) and a `memcpy()` from NULL. Patch `0004-undefined-behaviour` fixes them, with the MD5 code's pointer arithmetic on NULL.
- **`pdf_pages()`** follows inherited `MediaBox`, `CropBox` and `Rotate` through `/Parent` under `max_depth` (a `/Parent` cycle is a `zupdf_limit_error`), normalises boxes and rotation, and clips the crop box to the media box. pdfio's dictionary getters do not follow indirect references, so the walk resolves them itself.

---

## Stage 2 — Objects: `pdf_objects()`, `pdf_object()`, `pdf_stream()`, values · M

**Status:** done, 2026-10-08.

**Do**

- `src/zpd_value.c`: the §6 mapping from pdfio values to R, recursion bounded by `max_depth`, `pdf_name`, `pdf_ref`, `pdf_binary` marker classes, dates to `POSIXct` UTC, strings from PDFDoc or UTF-16BE to UTF-8 then `zuf_utf8_valid()`.
- `pdf_objects()` over `pdfioFileFindObj()` by number; `pdf_object()`; `pdf_stream()` through `pdfioObjOpenStream()` and a `pdfioStreamRead()` loop bounded by `max_stream` (the Flate-bomb guard), decoded or raw.
- The reverse mapping (R to pdfio values) for Stage 4's `dict =` and `pdf_set_meta()`, with the same depth bound.
- Tests: every §6 row both ways; the Flate bomb (`skip_heavy()`); a self-referencing object stream and a deep dictionary for `max_depth`; `pdf_objects()` pinned per fixture.

**Exit**

- Every §6 row has a test both ways; the bombs trip their classes; rchk and gctorture clean.


**What actually happened**

- **pdfio 1.6.5 decodes only FlateDecode.** ASCII85, RunLength and ASCIIHex are refused as unsupported, like DCT. `pdf_stream(decode = TRUE)` falls back to the stored bytes with `decoded = FALSE` and the filter names. Design §9 and §5 corrected.
- **Hex strings with a UTF-16 byte-order mark are text**, decoded by zupdf, since pdfio keeps hex strings as bytes; non-ASCII strings are written as UTF-16BE hex, because pdfio would write raw UTF-8 that other readers misread. Design §6.
- **Dictionary keys come out sorted**: pdfio inserts keys in sorted order, so the design's "R's order on the way in" cannot hold. Design §6.
- **`zpd_value.c` reads `pdfio-private.h`**, for references to missing objects, non-dictionary object values and appending `null` to an array.
- **The reverse mapping is tested through an internal `zpd_value_roundtrip()`**, which writes a list as an object of a one-page PDF in memory; every §6 row is tested both ways, ahead of the writer.
- **Streams are read into a handle-owned `malloc()` buffer** with no R call while the stream is open (design §13).

---

## Stage 3 — Text: `pdf_page_text()`, `pdf_page_tokens()`, `pdf_font_table()`, images · L

**Status:** done, 2026-10-08.

**Do**

- `pdf_page_tokens()` over `pdfioStreamGetToken()` for each of the page's content streams.
- `src/zpd_text.c`: the `pdf2text.c` port (§8): text and line matrices, the operators, ToUnicode CMaps and base-14 encodings, a per-`pdf_file` font and CMap cache in an R-owned table, Form XObject recursion bounded by `max_depth` with cycle refusal, U+FFFD for unmapped bytes with the count as an attribute, `R_CheckUserInterrupt()` every 4 096 tokens between pdfio calls, output into an R-owned growable buffer; `layout = "raw"` as the shows in stream order.
- `pdf_font_table()` (D13; it records each font's embedded file name, which §5.1's `pdf_fonts()` reports in `file`), `pdf_page_images()`, `pdf_image()` (raw with attributes; `nativeRaster` for 8-bit DeviceRGB/DeviceGray Flate or unfiltered; DCT as JPEG bytes).
- Tests: `pdf_page_text()` pinned exactly per fixture; the fixture set covers base-14 text, an embedded TrueType font with ToUnicode, UTF-16 strings, a Form XObject, a Form XObject cycle; `pdf_image()` round trip through `png::readPNG()` and `jpeg::readJPEG()` where installed.

**Exit**

- Every text fixture pinned; a 2 000-page synthetic file's `pdf_page_text(pages = 1)` runs in milliseconds; the cycle is refused with `zupdf_limit_error`.


**What actually happened**

- **`pdf2text.c` was too simple to port**: no text matrix, no ToUnicode, hex strings as UTF-16. The extractor is new project code (design §8) that keeps the example's glyph table and encodings: its own lexer (pdfio's tokenizer cannot skip inline images or keep NUL bytes), the full text state, ToUnicode CMaps, simple-font encodings with `/Differences`, Type0 two-byte codes, widths from `/Widths`, `/W` or pdfio's base-14 metrics, Type 3 font matrices.
- **Content streams are read whole and closed before the walk**, so no pdfio stream is open while it runs; interrupts are polled between pages. Design §8 and §13.
- **The reading layout** joins glyphs along their own direction, so rotated axis labels stay whole, and groups spans into lines by baseline.
- **Annotation appearances are not read**; poppler reads them, which is the one systematic difference from `pdftools::pdf_text()` found on the fixtures.
- **`pdf_font_table()`** (D13) and **`pdf_image()`, `pdf_page_images()`** are R over `pdf_object()` and `pdf_stream()`, with a C helper for the page's XObject resources and one for packing a `nativeRaster`.
- **UBSan** (local, `-fsanitize=undefined,function`) is clean over the whole suite.

---

## Stage 4 — Writer: `pdf_new()`, pages, text, paths, images, fonts, `pdf_save()` · L

**Status:** done, 2026-10-08. Deviation: the `md2pdf.c` port was not drafted; the drawing API was settled on what the tests and the examples need (D16), and the port moves to the Stage 8 vignette.

**Do**

- `src/zpd_writer.c`: the `pdf_writer` external pointer over `pdfioFileCreate()` (path) or `pdfioFileCreateOutput()` (callback appending to a growable R-owned buffer); `pdf_page` handles with open content streams closed by `pdf_page_end()` or the writer's finalizer, streams before file; `created =` and `deterministic = TRUE` (the ID from a hash of the content) as §7.
- `pdf_draw_text()` (D14), `pdf_font()` (base-14 and file through `ttf`, with the error callback installed on every `ttfCreate*()`), `pdf_draw()` with the path data frame, `pdf_image_new()` from PNG and JPEG files and from R rasters, `pdf_draw_image()`, `pdf_paper()`, `pdf_save()` to raw, path or connection.
- **Settle the drawing API's shape** (§20) by porting `md2pdf.c`'s page-building loop into the vignette draft and seeing what it needs; record in §17.
- Tests: every writer function's bytes pinned under `deterministic = TRUE` (`hashes.tsv`); every written file reopened with `pdf_open()` and its text read back; `zupdf_write_error` on a closed writer; `zupdf_font_error` on a non-font file; an abandoned page closed by the finalizer without a crash.

**Exit**

- Written bytes identical across every CI platform under `deterministic = TRUE`; every written fixture reopens and round-trips its text.


**What actually happened**

- **Pages are recorded, then written whole (D16).** pdfio refuses to create an object while a content stream is open, and writes a page's dictionary when the page is created, so drawing straight into an open stream would forbid making a font or image after the first page starts. `pdf_page_end()` creates the page with exactly the resources its operations use and replays them through pdfio's content API.
- **Output always goes through memory**; `pdf_save()` returns the bytes or writes them to a path or connection.
- **Determinism**: the ID is a hash of the bytes written before the trailer, set through pdfio's private `id_array`; deflate output depends on the zlib build, so pinned hashes are per zlib version (`fixtures/hashes.tsv`), and encrypted output is never byte-stable. Design §7 and §19 amended.
- **pdfio's Unicode fonts carry an `Identity-UCS2` ToUnicode CMap with no entries**; the text extractor now reads it as identity (poppler does the same), so text written in an embedded font reads back.
- **Patch `0005-unsigned-shifts`**: UBSan (local) reported `byte << 24` overflowing an int in ttf.c's big-endian reads when a TrueType font was embedded; the same pattern in pdfio's PNG reader is fixed with it.
- Fixtures gained OpenSans-Regular.ttf (with its licence), two PNGs and a JPEG from pdfio's `testfiles/`.

---

## Stage 5 — `pdf_copy_pages()`, metadata, encryption, compatibility layer · L

**Status:** done, 2026-10-08.

**Do**

- `pdf_copy_pages()` through `pdfioPageCopy()` with `rotate`; `pdf_set_meta()` through the §6 reverse mapping; `pdf_set_encryption()` with `rc4128` and `aes128`, user and owner passwords, permissions as `PDFIO_PERMISSION_*` names.
- Encrypted fixtures written by zupdf itself at each method, committed through `tools/update-fixtures`, and read back in Stage 1's password tests.
- **Settle §18 Q10** by reading whether `pdfioPageCopy()` copies page streams as stored, and record the answer in design §5.1.
- `R/compat.R`, the §5.1 compatibility layer, with pdftools 3.9.0's and qpdf 1.4.1's formals copied exactly:
  - from pdftools: `pdf_info()`, `pdf_text()`, `pdf_fonts()`, `pdf_pagesize()`, `pdf_toc()` (the outline walk, under `max_depth`), `pdf_attachments()` (the `EmbeddedFiles` name tree);
  - from qpdf: `pdf_length()`, `pdf_split()`, `pdf_subset()`, `pdf_combine()`, `pdf_rotate_pages()`.

  Each wrapper accepts what its original accepts, plus a `pdf_file`; closes what it opened; maps `opw` and `upw` to pdfio's password callback; and returns the original's shape, with `tbl_df` classes set without depending on tibble. `pdf_data()` waits for §18 Q1 at Stage 7, `pdf_overlay_stamp()` for Q3 and `pdf_compress()` for Q10; until then none of them is exported, not even as a stub.
- `helper-compat.R`: `expect_same_formals(f, pkg)`, and `expect_same_shape(ours, theirs)` comparing names, column names and classes.
- Tests: copy every fixture into a new file and compare text and boxes; split and merge; encrypted output reopens with the right password and is refused with the wrong one; `pdf_meta()` on the output reports the method. For each wrapper, `expect_same_formals()` under `skip_if_not_installed()`, and on every fixture, shape plus the values design §5.1 says agree. The wrappers' own outputs are pinned without needing the originals installed.

**Exit**

- Every §5 writer function exists and is tested; the encrypted fixtures are committed.
- Every §5.1 wrapper not waiting on Q1, Q3 or Q10 is exported, and its formals and shape tests pass against the installed pdftools and qpdf; §18 Q10 has its answer.


**What actually happened**

- **`pdf_copy_pages()` uses zupdf's own copy of `pdfioPageCopy()`**, which writes the page as it copies it; the port sets `/Rotate` first (adding, or setting for `pdf_rotate_pages(relative = FALSE)`).
- **PDF 2.0 drops the Info dictionary's entries**: pdfio writes title, author and the rest only into XMP for 2.0, so `pdf_new()` defaults to 1.7 and 2.0 output sets them as UTF-8 for the XMP.
- **pdfio rewrote UTF-16 text as UTF-8 when it read it**: `pdfioDictGetString()` retyped a binary value in place, and pdfio reads the title at close for the XMP. Patch `0006-dict-getstring` leaves the value alone.
- **Encryption and determinism**: the key comes from the file ID, so an encrypted file keeps pdfio's random ID under `deterministic = TRUE`; replacing it made the file unreadable.
- **§18 Q10 decided**: no `pdf_compress()`; pdfio copies streams as stored.
- **The compatibility layer** (`R/compat.R`) matches pdftools's and qpdf's formals exactly (tested), and their values on the fixtures where design §5.1 says they agree; `pdf_toc()` gained `is_open` from that comparison.
- CI on Stage 2 found PROTECT issues (rchk) in the value conversion and an R-internal libdeflate allocation (valgrind), fixed and suppressed (`tools/valgrind.supp`).

---

## Stage 6 — Fuzz target, mutation check, hardening CI · M

**Status:** done, 2026-10-08.

**Do**

- `fuzz/fuzz_pdf.c`: write the input to a temporary file, `pdfioFileOpen()` with the recording callback, walk every object and stream under the limits, extract every page's text, close; seeded from `afl-input` with `afl-pdf.dict`; a per-input timeout; invariants of §15. `fuzz/fuzz_canary.c` must crash first; `tools/run-fuzz`; `hardening.yaml` with r-actions `fuzz.yml`.
- `tools/run-mutation-check` over every `/* GUARD */` (limits, cycle refusal, closed-handle checks); `tools/run-lint`; `tools/check-no-network`.
- Hangs the fuzzer finds inside one pdfio call go upstream as issues and into the corpus as known inputs.

**Exit**

- The canary has crashed; the PR fuzz budget is clean; every guard has a mutation case; `hardening.yaml` green.


**What actually happened**

- **An R-free core** for the fuzz target: the error callback and dictionary helpers moved to `zpd_core.c`, the text walk got an R-free `zpd_text_extract()`, and `zpd.h` splits at `ZPD_STANDALONE`. The target opens, loads every object, reads every stream and extracts every page's text in both layouts.
- **The first five minutes of fuzzing found undefined behaviour in pdfio**: a negative `/W` entry cast to `size_t`. Patch `0007-number-casts` clamps all 23 conversions of file numbers to integers; the input is a regression fixture (`fixtures/fuzz/`).
- **The next ten minutes found the same bug in zupdf's own font loader** (a huge `/FirstChar` cast to `long`); an audit moved every conversion of a file-derived number in project C (rotation, `/W`, `/Differences`, `/FirstChar`) to `zpd_clamp_int()`.
- **Fifteen more minutes found a hang**: pdfio's cross-reference repair skipped its offset update when it could not read an object and could loop for ever (a 716-byte file). Patch `0008-repair-loop`; the input is a regression fixture.
- **Thirty more minutes found two more**: an `/Index` entry cast to `intmax_t` that 0007 missed (patch `0009-index-cast`), and an empty name in a ToUnicode CMap crashing the parser's `strstr()` on a NULL lexer buffer (fixed in the lexer, Stage 4's code). Both inputs are regression fixtures.
- **CI's first fuzz run found a leak** that macOS cannot see (no LeakSanitizer there): an object whose own value is a hex string was never freed, at close or when the repair scan read it again. Patch `0011-object-value-leak`; the input is a regression fixture.
- **The mutation check runs through R**, not a C probe: the limits live on both sides of `.Call`, so each guard is disabled in a scratch copy, the copy is reinstalled, and an R probe must change outcome. All ten guards are load-bearing (about 80 seconds); a disabled `max_depth_inherit` hangs on a `/Parent` cycle, caught by a timeout. A form cycle now reports its own message, so its guard is distinguishable from the depth limit's.
- **`tools/run-lint`** passes at `-Werror` for the R and standalone builds; `tools/check-no-network` copied from zucbor.

---

## Stage 7 — Conformance against pdftools and qpdf, benchmarks, `pdf_data()`? · M

**Status:** done, 2026-10-08. Deviation: cross-runner byte identity is printed (MD5 and zlib version per runner), not asserted, since deflate output depends on the zlib build (design §7).

**Do**

- `conformance.yaml`: `pdf_page_text()` against `pdftools::pdf_text()` after whitespace normalisation on every text fixture; every written fixture opened by `qpdf::pdf_length()` and `pdftools::pdf_text()`; `qpdf --check` where the binary exists; written bytes compared across runners.
- The compatibility comparison in `conformance.yaml`: each §5.1 wrapper's output set against its original's on the full fixture set, with `pdf_text()` compared after whitespace normalisation, and the differences recorded in design §5.1's table. Signatures are checked against the CRAN releases current at the time, so upstream drift shows up in CI (§18 Q11).
- `tools/run-benchmarks` against `pdftools` and `qpdf`; results recorded in design §16.
- **Decide §18 Q1** (`pdf_data()` with positions): if the text port is solid and its word boxes match pdftools's columns, add it here from the matrices the walk already tracks, with pdftools's formals; otherwise record it as deferred and leave it unexported.

**Exit**

- Conformance green; benchmarks recorded; §18 Q1 decided.


**What actually happened**

- **`pdf_data()` ships (§18 Q1).** The text walk's glyphs are exposed per page; R groups them into words along each glyph's direction and boxes them with the font's real ascent and descent. Every pdftools word is found with `x` within 2 points; `y` matches except for poppler's Type 3 heights.
- **Conformance** passes on the fixtures: word recall 0.9 to 1.0 wherever pdftools reads text (two afl cases keep their text in form-field appearances, which zupdf does not read); every written file is read by pdftools with the same words and passes `qpdf --check`.
- **Benchmarks** (design §16): open + metadata 1 ms, text 5× faster than pdftools, merging at 1.1× qpdf, a 100-page report in 168 ms.

---

## Stage 8 — pkgdown site, vignettes, CRAN · S

**Status:** not started. Waits for zufast on CRAN.

**Do**

- Every export documented with `@return` and runnable `@examples`; the package help page's first paragraph says zupdf does not render; four vignettes, *Inspecting a PDF*, *Assembling PDFs*, *Writing a report from R* (the `md2pdf` port) and *Switching from pdftools and qpdf* (what §5.1 covers, where its output differs, what is missing, and masking); the README states the masking too; `_pkgdown.yml`; README rewritten; `inst/WORDLIST`; `cran-comments.md` listing the CI legs.
- Remove `Remotes:`; rebuild against zufast's CRAN tarball; if 1.7.0 is tagged, decide whether the pin moves before or after the first release (D12).
- Verify each §19 acceptance criterion in a table naming what verifies it.
- `Version: 0.1.0` and the NEWS heading; `R CMD check --as-cran --run-donttest` 0/0/0; the tarball under 5 MB; the `cran-extrachecks` and `review-cran-submission` skills.
- Submit. After acceptance: tag `v0.1.0`, GitHub release, bump to `0.1.0.9000`, close the parent issue.

**Exit:** on CRAN.

---

## Acceptance criteria against stages

| § 19 | Criterion | Stage |
|---|---|---|
| 1 | installs everywhere with only R's zlib; clean `--as-cran` | 0, 8 |
| 2 | every `afl-input` case read or refused cleanly | 1, 6 |
| 3 | text matches `pdftools`; written files open elsewhere | 3, 7 |
| 4 | deterministic bytes across runners | 4, 7 |
| 5 | every class tested; every guard mutation-checked | 1, 2, 6 |
| 6 | 30 minutes of nightly fuzzing clean; canary seen | 6 |
| 7 | vendor trees verified; only the init symbol exported | 0 |
| 8 | compatibility wrappers match their originals' formals and shapes | 5, 7 |

## Explicitly not in 0.1.0

Rendering · OCR · forms · annotations as a model · signatures · redaction · linearisation · incremental update · JPX, JBIG2, CCITT decoding · colour management · a graphics device · text layout · AES-256 writing · WebP · system fonts · the 1.7.0-only features while the pin is 1.6.5 · pdftools's `pdf_render_page()`, `pdf_convert()`, `pdf_ocr_*()` and `poppler_config()` · `pdf_compress()` unless §18 Q10 allows it.

## Risk register

| Risk | Stage | Mitigation |
|---|---|---|
| zlib's header not found on a platform | 0 | the first build runs on every leg; `-lz` is what every zlib-using CRAN package does |
| a forbidden symbol in the vendor trees | 0 | `tools/check-symbols` on the installed build; patch, never justify; `vendor.yaml` on every push |
| the pin moves to 1.7.0 mid-roadmap | any | its own PR through `tools/update-pdfio`; `vendor-upstream.yaml` raises the issue; D12 |
| a pdfio call follows a cycle unboundedly | 1, 6 | the fuzz timeout finds it; upstream issue; `max_depth` where zupdf controls recursion |
| the text port diverges from `pdftools` on real files | 3, 7 | pinned fixtures across producers; the conformance job's normalised comparison |
| raising from inside pdfio leaks descriptors | all | D5: the callback records and returns; the thousand-handle test |
| the temp-file spill leaves files behind | 1 | the finalizer unlinks; the thousand-handle test checks `tempdir()` |
| the tarball exceeds 5 MB from fonts and fixtures | 8 | only `OpenSans-Regular.ttf` and small PDFs ship; the rest lives under `tools/` |
| the audience mostly needs rendering (§20) | 0 | the survey before any reading code |
| switching users notice that `pdf_text()` differs from pdftools's layout text | 3, 5, 7 | design §5.1 and the switching vignette say so; conformance measures it; the native `pdf_page_text()` is unaffected |
| pdftools or qpdf change a signature | any | the formals test fails in CI against the current CRAN release; §18 Q11 |
## After 0.1.0

1. The 1.7.0 pin if it did not land before release, switching on LZW (if 1.6.5 lacks it), GIF, object streams.
2. `pdf_data()` if §18 Q1 deferred it; `pdf_overlay_stamp()` (§18 Q3) and `pdf_compress()` (§18 Q10) if they did not make 0.1.0; streaming output (§18 Q2).
3. `zusvg` paths into content streams (§18 Q4), once both packages exist.
4. AES-256 writing when pdfio lifts its exclusion (§18 Q5).
