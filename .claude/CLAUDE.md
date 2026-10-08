# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`zupdf` is an R package that opens, inspects, extracts from, assembles and writes PDF files through a **vendored copy of pdfio** (Michael Sweet's C library, Apache-2.0 with exceptions) and its `ttf` font library, with zlib the only system library, which R itself already needs. It reads metadata, pages, objects, streams, images, fonts and text in reading order; it copies pages between files, sets metadata, permissions and encryption; and it writes new PDFs from R with text, paths and images. Zero hard runtime dependencies (`zufast` is build-time only). It deliberately never renders pages to pixels (that is `pdftools`'s job and design D2 says there is no slot for it), never decodes JPEG, never looks up system fonts, and models no forms, annotations or signatures.

Two documents outrank this file. [.agents/design.md](../.agents/design.md) is the specification, numbered §1–§20: every statement in it is a decision, and open questions live only in its §18. [.agents/roadmap.md](../.agents/roadmap.md) sequences it into Stages 0–8, each with a **Status:** line under its heading. Both were adopted on 2026-10-08 from [RFC 0008](https://github.com/pedrobtz/packages/blob/main/rfcs/0008-zupdf-pdf-files.md) in `pedrobtz/packages`. `CLAUDE.md` orients, the design decides, the roadmap sequences.

It is a member of the `zu*` family (sibling checkouts in `../`). `zucbor` and `zuhtml` are the models for vendoring, `PROVENANCE`, the patch series, `verify-vendor` and `check-symbols`; `zucbor` for classed conditions and the `/* GUARD */` mutation check; `zuhtml` for an external-pointer-owned document and the "patch, never justify" lesson.

## Current state

**2026-10-08: Stage 7 done.** pdfio 1.6.5 is vendored in `src/vendor/pdfio/` (its ttf library ships in the same tree) with twelve patches (`0001` to `0012`). Readers: `pdf_open()`, `pdf_close()`, `pdf_meta()`, `pdf_pages()`, `pdf_objects()`, `pdf_object()`, `pdf_stream()`, `pdf_page_text()`, `pdf_page_tokens()`, `pdf_font_table()`, `pdf_page_images()`, `pdf_image()`. Writer: `pdf_new()`, `pdf_page_new()`, `pdf_page_end()`, `pdf_draw_text()`, `pdf_draw()`, `pdf_draw_image()`, `pdf_font()`, `pdf_image_new()`, `pdf_copy_pages()`, `pdf_set_meta()`, `pdf_set_encryption()`, `pdf_save()`, `pdf_paper()`. Compatibility layer (`R/compat.R`, design §5.1): pdftools's `pdf_info()`, `pdf_text()`, `pdf_fonts()`, `pdf_pagesize()`, `pdf_toc()`, `pdf_attachments()`, `pdf_data()` and qpdf's `pdf_length()`, `pdf_split()`, `pdf_subset()`, `pdf_combine()`, `pdf_rotate_pages()`. Hardening: `fuzz/fuzz_pdf.c` over the R-free core (`-DZPD_STANDALONE`), `tools/run-fuzz`, `tools/run-mutation-check` (R probes; every guard load-bearing), `tools/run-lint`, `tools/check-no-network`, in `hardening.yaml`. Conformance: `tools/run-conformance` (`conformance.yaml`) against pdftools and qpdf; `tools/run-benchmarks`, results in design §16. Next: Stage 8, the site, vignettes and CRAN (waits for zufast on CRAN).

Update this paragraph at the end of every stage.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the parent issue shows a progress bar such as "6 of 7".

- **One parent issue per target version**, `v0.1.0`. Not yet opened (2026-10-08); Stage 0 opens it and `.github/scripts/stage-cards.sh` in `pedrobtz/packages` puts it on the board.
- **One sub-issue per roadmap stage**, titled as the roadmap titles it, for example `Stage 3 — Text: pdf_page_text(), pdf_page_tokens(), pdf_font_table(), images`, linking to that section's anchor. The roadmap has nine stages, 0 to 8.
- **Every tracking issue carries the `stage` label.**
- **Close a stage by merging its pull request.** Put `Closes #<n>` in the body. Never close a stage whose exit criteria are not met; record a deviation in its **Status:** line first.
- **The roadmap stays authoritative.** Adding, removing or renaming a stage means editing the roadmap and the sub-issues in the same change. Status never goes in a heading.
- Close the parent issue when CRAN accepts the version and it is tagged.

## Versioning

The package develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN release. Set `Version: 0.1.0` and the matching `NEWS.md` heading when the package enters `Pre-flight` (Stage 8). Bump to `0.1.0.9000` only after CRAN accepts it.

Until the first release the R API may change freely. zupdf depends on a sibling before CRAN does: `LinkingTo: zufast (>= 0.1.0)` from `Remotes: pedrobtz/zufast@main` during development. **zufast must be on CRAN before zupdf is submitted**; `Remotes:` goes at Stage 8. No package depends on zupdf. The pdfio pin moves from 1.6.5 to 1.7.0 in its own pull request when upstream tags it (design D12); `vendor-upstream.yaml` raises the issue.

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ and load; after changing a header,
                                                 # rm src/*.o first: pkgbuild does not track headers
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
_R_CHECK_SYSTEM_CLOCK_=0 Rscript -e 'devtools::check(cran = TRUE)'
air format .                                     # format R sources
```

zufast is not on CRAN: install it from `../zufast` or `pak::pak("pedrobtz/zufast")`. roxygen2 must be 8.1.0 or newer.

Gate scripts, each arriving at the roadmap stage named:

```sh
tools/update-pdfio <version>               # Stage 0: re-vendor pdfio (ttf included), apply tools/patches/, write PROVENANCE
tools/verify-vendor                        # Stage 0: trees == tags + patches; PROVENANCE agrees   (CI: vendor)
R CMD INSTALL -l <lib> . && tools/check-symbols <lib>/zupdf/libs/zupdf.so
                                           # Stage 0: only R_init_zupdf exported; no stdio/abort/exit/assert/rand
tools/update-fixtures                      # Stage 1: pdfio testfiles, producer PDFs, afl-input, encrypted variants
tools/run-fuzz [secs]                      # Stage 6: canary first, then fuzz_pdf seeded from afl-input (CI: hardening)
tools/run-lint                             # Stage 6: strict warnings on project C
tools/run-mutation-check                   # Stage 6: every guard seen to be load-bearing
tools/check-no-network                     # Stage 6
tools/run-benchmarks                       # Stage 7: vs pdftools and qpdf where installed; not a gate
```

Run `tools/check-symbols` on an `R CMD INSTALL` build, never a `load_all()` one (`-UNDEBUG` keeps `assert()`s in).

## Architecture

Planned layout, from design §4, §9 and §14. Nothing under `src/` beyond the template exists yet.

```text
R/            open.R, meta.R, pages.R, objects.R, text.R, images.R, fonts.R,
              writer.R, draw.R, assemble.R, encrypt.R, paper.R, values.R,
              conditions.R, args.R, info.R, zupdf-package.R
src/          init.c                          registration only
              zpd_file.c                      pdf_file external pointer; error and password callbacks; temp-file spill
              zpd_value.c                     pdfio values <-> R lists (§6), depth-bounded
              zpd_lex.c                       the content-stream lexer (§8), shared with pdf_page_tokens()
              zpd_font.c, zpd_glyphs.h        fonts: ToUnicode CMaps, encodings, widths, the per-file cache
              zpd_text.c                      the text walk (§8): graphics and text state, forms, layouts
              zpd_writer.c                    pdf_writer: memory output, fonts, images, page replay (D16), determinism
              zpd_r.c                         .Call glue; statuses by name
              Makevars                        hand-listed objects; -I vendor/pdfio -DPDFIO_NO_STDIO -D_PDFIO_PUBLIC= -D_PDFIO_PRIVATE=; -lz
              vendor/pdfio/                   pdfio 1.6.5 and its ttf, byte-identical to the tarball plus tools/patches/
              vendor/PROVENANCE
tools/        update-pdfio, verify-vendor, check-symbols, patches/, file lists, gate scripts
fuzz/         fuzz_pdf.c, fuzz_canary.c (not in the tarball)
tests/testthat/fixtures/   pdfio testfiles subset, producer PDFs, afl-input, encrypted variants,
                           hashes.tsv, README.md (sources, licences); OpenSans-Regular.ttf only
inst/COPYRIGHTS, LICENSE.note
.agents/      design.md, roadmap.md
```

Reading: R resolves the input (a path, or a raw vector or connection spilled to a temporary file the handle owns) → `pdfioFileOpen()` with zupdf's recording error callback and the password the handle holds → a `pdf_file` external pointer → every reader goes back to it (pdfio reads lazily by xref), bounded by the limits → pdfio values converted in `zpd_value.c`, text extracted in `zpd_text.c`. Writing: `pdf_new()` → `pdfioFileCreate()` or `pdfioFileCreateOutput()` into an R-owned buffer → `pdf_page` handles with open content streams → `pdf_save()` closes streams, then the file. Only `zpd_*.c` include pdfio headers.

## Invariants that are easy to break

- **The error callback records and returns; it never raises** (design D5). pdfio holds `malloc()`ed state and open descriptors across its calls; an `Rf_error()` inside the callback longjmps over them. Raise from R after the pdfio call returns, from the recorded message. The same for the password callback: it answers from a string the handle already holds, and a `password` function is called in R before `.Call`.
- **No R code runs inside pdfio.** No `R_CheckUserInterrupt()` or R allocation while a pdfio stream is open except into the R-owned result buffer; interrupts are polled between pdfio calls (every 4 096 tokens in the text walk).
- **Nothing pdfio allocates lives outside an external pointer.** `pdf_file` owns the `pdfio_file_t`, its temporary file and its caches; `pdf_writer` owns the file or buffer and closes abandoned page streams before the file in its finalizer. A closed handle is refused by every function.
- **The vendor trees are upstream plus exactly the patch series.** `tools/verify-vendor` re-derives both from the pinned tarballs and `tools/patches/`; any other edit fails it. Each patch is minimal, named in `PROVENANCE`, listed in `zupdf_info()`, asserted by `test-info.R`, and sent upstream (with the `PDFIO_NO_STDIO` proposal).
- **CRAN's compiled-code check applies to vendored code too.** pdfio's default error callback writes to `stderr`, `copy_png()`'s `setjmp` handler calls `fputs(stderr)`, and the `DEBUG` printers reference `fprintf`; all are patched out even though zupdf never reaches them. Never justify such a symbol in `cran-comments.md` (zuxml's first upload was archived for that) and never silence a warning with a pragma. `tools/check-symbols` lists stream symbols as well as functions.
- **Limits are checked where they can be.** `max_size` before the spill, `max_objects` and `max_pages` after the xref, `max_stream` in zupdf's own `pdfioStreamRead()` loop, `max_depth` in conversion and the text walk's Form XObject recursion (with cycle refusal). pdfio has no limits of its own. Guards carry `/* GUARD: name */` and a mutation case.
- **Names and strings are different types** (design §6): a `pdf_name` is a character scalar with a class; a plain character written to a dictionary is a string. Dropping the class turns `/Type /Page` into `(Page)`.
- **Determinism is by argument.** `deterministic = TRUE` fixes the file ID and `created =` the date; the writer tests pin bytes only under it, and a test that pins bytes without it is flaky by construction. Pins are per zlib version (`fixtures/hashes.tsv`), since deflate output differs between zlib builds; encrypted output is never byte-stable.
- **No pdfio content stream is open between calls** (design D16): a `pdf_page` records operations in R and `pdf_page_end()` writes the page whole. pdfio refuses to create an object while a stream is open.
- **The text extractor is project code** (`zpd_text.c`, D10), not a pdfio call: changes there are the main maintenance cost and are pinned against `pdftools` in the conformance job and exactly in the package tests.
- **DCT streams are returned as JPEG bytes, never decoded** (D6); do not vendor a JPEG decoder.
- **No system font lookup** (D7): `pdf_font()` takes a base-14 name or a file path; `pdfioFileCreateFontObjFromSystem()` is never called.
- **Portable make only** in `src/Makevars`: hand-listed objects, `-lz`, no `$(wildcard)`, no `$(shell)`, no `Makevars.win`.
- **C never calls `Rf_error()`**; statuses by enumerator name, `R/conditions.R` raises, pdfio's message prefixes map to classes and anything unknown falls to the bare class deliberately.

## Naming

| Layer | Prefix | Examples |
|---|---|---|
| R exports, native | `pdf_` plus `zupdf_info()`, never a `pdftools` or `qpdf` export name | `pdf_open()`, `pdf_page_text()`, `pdf_draw_text()` |
| R exports, compatibility (design §5.1) | exactly `pdftools`'s and `qpdf`'s names, formals and return shapes | `pdf_text()`, `pdf_info()`, `pdf_combine()` |
| R classes | `pdf_` | `pdf_file`, `pdf_writer`, `pdf_page`, `pdf_name`, `pdf_ref`, `pdf_binary` |
| R condition classes | `zupdf_` | `zupdf_error`, `zupdf_password_error`, `zupdf_warning` |
| R and C internals | `zpd_` / `ZPD_` | `zpd_text_extract()`, `ZPD_STANDALONE` |
| `.Call` entry points | `zupdf_` | `zupdf_open` |
| Test-switching variables | `ZUPDF_` | `ZUPDF_SKIP_HEAVY`, `ZUPDF_SLOW_TESTS` |

Names follow design D8. The compatibility layer (§5.1, `R/compat.R`) reuses `pdftools`'s and `qpdf`'s names with their exact formals and return shapes, so `library(zupdf)` can replace `library(pdftools)` for non-rendering work; a test compares `formals()` with the originals. Every other export uses a name neither package exports, and a shared name never means something different: the writer's text function is `pdf_draw_text()`, the native font table `pdf_font_table()`. Never define a stub for a function zupdf cannot provide (`pdf_render_page()`, `pdf_convert()`, `pdf_ocr_*()`, `poppler_config()`).

## Testing conventions

- **Self-sufficient.** Inputs built inside each `test_that()` (`minimal_pdf()` in `helper-pdf.R`) or read from `fixtures/`. No file-scope objects; shared code in `helper-*.R`.
- **Self-contained.** Files under `withr::local_tempdir()`; handles closed with `withr::defer()` except in the finalizer tests, which leave them deliberately and call `gc()`.
- **Assert on condition classes and fields (`detail`, `object`, `limit`, `limit_value`), never message text.**
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of the definition of done; serial, no `Config/testthat/parallel`.
- **The conformance oracles** are pdfio's own `afl-input` corpus (every case must open and read or be refused with a classed condition, nothing on stderr; at 1.6.5 all 23 open), `pdftools::pdf_text()` after whitespace normalisation and `qpdf` on written files, both in the `conformance` job only (`Suggests`). Pinned bytes under `deterministic = TRUE` in `fixtures/hashes.tsv` are the package's own gate. None covers rendering, which the package does not do.
- **Helpers in `tests/testthat/helper-*.R`**: `helper-pdf.R` (`fixture()`, `minimal_pdf()`, `encrypted_fixture()`), `helper-expect.R` (`expect_zupdf_error()`, `expect_pdf_bytes()`, `expect_text_equal()`), `helper-skip.R` (`skip_heavy()` on `ZUPDF_SKIP_HEAVY`, `skip_if_no_slow_tests()` on `ZUPDF_SLOW_TESTS`, `skip_if_not_installed()` for `pdftools`, `qpdf`, `jpeg`, `png`).
- **Fixtures are data**, fetched only by `tools/update-fixtures`, with `fixtures/README.md` naming every source and licence; the font licences ride along; only `OpenSans-Regular.ttf` ships.
- **Keep the suite inside the CRAN time budget:** under 15 s; the thousand-handle, Flate-bomb and million-object tests call `skip_heavy()`.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors, 0 warnings and 0 notes. The one allowed note is "New submission" before the first release. `devtools::test(shuffle = TRUE)` green. `gctorture(TRUE)` clean when C changed. CI green on every leg, including `vendor.yaml`. A user-facing change also needs a test, roxygen documentation and a `NEWS.md` entry. A change to a contract (the exports, the value mapping, the limits, the patch series, the pin) amends the design in the same commit. A stage is done when its exit criteria pass in CI on all three platforms; a gate counts once it has been seen to fail.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD check runs `--as-cran` on the CRAN-like runners and containers, and replaces win-builder, the macOS builder and R-hub. `cran-comments.md` lists the CI legs as its test environments.
- **Entering `Pre-flight`.** Stages 0–7 done, `Version: 0.1.0` with the `NEWS.md` heading, `cran-comments.md` written, CI green, zufast on CRAN and `Remotes:` removed, the tarball under 5 MB.
- **Before submitting,** run the `cran-extrachecks` and `review-cran-submission` skills and resolve every finding.
- **The pretest is automated and does not read `cran-comments.md`.** Fix every NOTE, as under Vendored native code.
- **After acceptance,** tag `v0.1.0`, publish the GitHub release, bump to `0.1.0.9000`, close the parent issue.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- There is no `README.Rmd`; edit `README.md` directly and run its example.
- Prose is simple, short and en-GB (`Language: en-GB`, `inst/WORDLIST`). The package help page's first paragraph says zupdf does not render; keep it there.
- Wrap roxygen at 80 characters; `air format .` on R sources.
- `lower_snake_case`; the naming table above.
- Hard runtime dependencies: none. `pdftools`, `qpdf`, `jpeg`, `png` stay in `Suggests`.
- Every export has `@return` and runnable `@examples`; no roxygen topics for internals.
- `NEWS.md` keeps a versioned heading.

## Continuous integration

Workflows come from `pedrobtz/r-actions`. The scaffold's `R-CMD-check.yaml` (quick on pull requests, full on `main` and under `full-ci`), `coverage.yaml` and `pkgdown.yaml` exist at `@v1`; Stage 0 pins `coverage.yaml` by commit, adds Dependabot, and adds `vendor.yaml` (verify-vendor and symbols) and `vendor-upstream.yaml` (a new pdfio or ttf tag opens an issue). The roadmap's CI table says which stage adds `native-checks.yaml` (UBSan, ASan with `-UNDEBUG`, valgrind, LTO, gctorture, blocking rchk), `hardening.yaml` (fuzz seeded from `afl-input`, lint, mutation check, no-network) and `conformance.yaml` (`pdftools`, `qpdf`, cross-runner bytes, benchmarks). Every stage touches `src/`, so stage pull requests carry `full-ci`.

This file lives in `.claude/`, not the package root, because pkgdown renders every root-level `*.md` as a site page (alignment rule R8 in `pedrobtz/packages`); keep it here.

## Vendored native code

pdfio (Apache-2.0 with an exception permitting linking against GPL2-only software) pinned at **v1.6.5**, upstream's latest release on 2026-10-08, with its `ttf` library (same licence), which ships inside pdfio's own release tarball from 1.6.0, in `src/vendor/pdfio/` with provenance in `src/vendor/PROVENANCE`. Re-vendor with `tools/update-pdfio <version>`, never by hand. The `License:` field is `MIT + file LICENSE` with `Copyright: file inst/COPYRIGHTS` (design D15).

- Pin a stable upstream release, never `master` or a release candidate; the RFC's reading of `master` (1.7.0) is recorded in design §9 as what arrives when that tag exists. 1.6.5 carries the AES fix GHSA-527h-2p2v-g388, the floor on the pin.
- Record the tags, the commits, the tarball checksums, the file lists, every patch with its reason, and the compiler warnings seen, in `PROVENANCE`; keep `tools/update-pdfio` mechanical.
- Keep each library's `LICENSE` and `NOTICE` in the vendor tree; reproduce both `NOTICE` texts with the exception in `inst/COPYRIGHTS`; declare Michael R Sweet as `cph` in `Authors@R` with a comment naming pdfio and ttf; keep `LICENSE.note` current.
- Only the library sources, headers and licence files are vendored: no examples (the `pdf2text.c` algorithm is ported into `src/zpd_text.c` as project code, D10), no tests, `Makefile.in`, IDE projects or documentation. `HAVE_LIBPNG` and `HAVE_LIBWEBP` are never defined.
- The patch set (design D4): `0001-visibility-override` (pdfio marks its API `visibility("default")`; `Makevars` defines `_PDFIO_PUBLIC` and `_PDFIO_PRIVATE` empty so only `R_init_zupdf` is exported) and `0002-no-stdio` (`PDFIO_NO_STDIO` leaves out the default error callback's `stderr` write, ttf's `errorf()` fallback and the three debug printers, which are compiled in every build). `copy_png()`'s `fputs` is under `HAVE_LIBPNG` and never compiled. When the pin moves to 1.7.0, `ttf-cache.c` needs the same treatment. `0003-date-buffer` enlarges two date buffers that gcc's `-Wformat-truncation` flagged. `0004-undefined-behaviour` fixes what UBSan reports in pdfio: calls through mistyped function pointers (token, crypt and comparator callbacks), a `memcpy()` from NULL and pointer arithmetic on NULL; `0005-unsigned-shifts` the signed overflow of `byte << 24` in ttf.c and the PNG reader; `0006-dict-getstring` stops a read from rewriting a UTF-16 value as UTF-8; `0007-number-casts` clamps every number read from a file before it becomes an integer (the fuzzer's first find); `0008-repair-loop` stops the cross-reference repair looping for ever; `0009-index-cast` clamps the `/Index` cast 0007 missed; `0010-ttf-callbacks` gives the ttf callbacks the right types; `0011-object-value-leak` frees an object's own hex-string value; `0012-trailer-value-leak` frees a trailer that is not a dictionary. Each patch adds a modification notice to the files it changes (Apache-2.0 §4(b)); `verify-vendor` checks it. Every patch identifier is listed in `zupdf_info()` and asserted in `test-info.R`.
- `vendor.yaml` runs `tools/verify-vendor` and `tools/check-symbols` on every push, so an upstream bump cannot bring a forbidden symbol back.
- zlib is linked from the system (`PKG_LIBS = -lz`), never vendored: R requires it on every CRAN platform.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped. Keep each commit focused and do not sweep in unrelated files. A pull request explains the user-visible outcome and the rationale, links related issues, lists the checks that were run and the tests that were skipped, and flags platform-sensitive or vendored changes. Performance claims need evidence from `tools/run-benchmarks`.

Never commit or push to the default branch. Work on a branch (`stage-N-<slug>`), open a pull request, and leave it for review. Do not merge a pull request unless you are told to.

When you find a defect, in this package, in pdfio or ttf, in `zufast` or in an upstream tool, open an issue for it rather than only working around it; a pdfio fix also becomes a patch in `tools/patches/` until upstream releases it.
