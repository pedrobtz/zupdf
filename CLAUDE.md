# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shared conventions

The portfolio's shared rules are synced into `.claude/shared/` from
`pedrobtz/packages:claude/shared/`. Never edit them here. Where this file and
a shared file disagree, this file wins for this package.

@.claude/shared/workflow.md
@.claude/shared/r-package.md
@.claude/shared/ci.md
@.claude/shared/native-code.md
@.claude/shared/correctness.md
@.claude/shared/assurance.md

## What this is

`zupdf` is an R package that opens, inspects, extracts from, assembles and
writes PDF files through a **vendored copy of pdfio** (Michael Sweet's C
library, Apache-2.0 with exceptions) and its `ttf` font library, with zlib the
only system library, which R itself already needs. It reads metadata, pages,
objects, streams, images, fonts and text in reading order; it copies pages
between files, sets metadata, permissions and encryption; and it writes new
PDFs from R with text, paths and images. Zero hard runtime dependencies
(`zufast` is build-time only). It deliberately never renders pages to pixels
(that is `pdftools`'s job and design D2 says there is no slot for it), never
decodes JPEG, never looks up system fonts, and models no forms, annotations
or signatures.

Two documents outrank this file. [.agents/design.md](.agents/design.md) is
the specification, numbered §1–§20: every statement in it is a decision, and
open questions live only in its §18. [.agents/roadmap.md](.agents/roadmap.md)
sequences it into Stages 0–8, each with a **Status:** line under its heading.
Both were adopted on 2026-10-08 from
[RFC 0008](https://github.com/pedrobtz/packages/blob/main/rfcs/0008-zupdf-pdf-files.md)
in `pedrobtz/packages`. `CLAUDE.md` orients, the design decides, the roadmap
sequences.

It is a member of the `zu*` family (sibling checkouts in `../`). `zucbor` and
`zuhtml` are the models for vendoring, `PROVENANCE`, the patch series,
`verify-vendor` and `check-symbols`; `zucbor` for classed conditions and the
`/* GUARD */` mutation check; `zuhtml` for an external-pointer-owned document
and the "patch, never justify" lesson.

## Current state

**2026-10-22: Stages 0–7 done; Stage 8 in pre-flight.** pdfio 1.6.5 is
vendored in `src/vendor/pdfio/` (its ttf library ships in the same tree) with
eighteen patches (`0001` to `0018`).

- **Readers:** `pdf_open()`, `pdf_close()`, `pdf_meta()`, `pdf_pages()`,
  `pdf_objects()`, `pdf_object()`, `pdf_stream()`, `pdf_page_text()`,
  `pdf_page_tokens()`, `pdf_font_table()`, `pdf_page_images()`,
  `pdf_image()`.
- **Writer:** `pdf_new()`, `pdf_page_new()`, `pdf_page_end()`,
  `pdf_draw_text()`, `pdf_draw()`, `pdf_draw_image()`, `pdf_font()`,
  `pdf_image_new()`, `pdf_copy_pages()`, `pdf_set_meta()`,
  `pdf_set_encryption()`, `pdf_save()`, `pdf_paper()`, and
  `pdf_text_width()`, added for the report vignette.
- **Compatibility layer** (`R/compat.R`, design §5.1): pdftools's
  `pdf_info()`, `pdf_text()`, `pdf_fonts()`, `pdf_pagesize()`, `pdf_toc()`,
  `pdf_attachments()`, `pdf_data()` and qpdf's `pdf_length()`, `pdf_split()`,
  `pdf_subset()`, `pdf_combine()`, `pdf_rotate_pages()`.
- **Hardening:** `fuzz/fuzz_pdf.c` over the R-free core (`-DZPD_STANDALONE`),
  `tools/run-fuzz`, `tools/run-mutation-check` (R probes; every guard
  load-bearing), `tools/run-lint`, `tools/check-no-network`, in
  `hardening.yaml`.
- **Conformance:** `tools/run-conformance` (`conformance.yaml`) against
  pdftools and qpdf; `tools/run-benchmarks`, results in design §16.
- **Stage 8:** four vignettes, the pkgdown reference index, README,
  `inst/WORDLIST` and `cran-comments.md` are in place. The review skills have
  run and their findings are fixed (2026-10-23 to 2026-10-26, recorded in
  `NEWS.md`). zufast 0.1.0 is on CRAN (2026-10-21); `Remotes:` is gone and
  `Version:` is `0.1.0`. `src/vendor/PROVENANCE` records the upstream pdfio
  issue each patch was reported in.

Left for the submission (Stage 8, #10): a clean nightly fuzz run with patch
0013, a last `--as-cran` run, and the submission. zupdf is not on CRAN
(crandb, 2026-11-11). Open since then: #97, raised by `vendor-upstream.yaml`
on 2026-11-02, reports pdfio 1.6.6 upstream and lists four published
advisories, one of them the AES fix 1.6.5 already carries; the pin is still
1.6.5.

Update this section at the end of every stage.

## Versions and dependents

The `v0.1.0` parent issue is #1; the roadmap has nine stages, 0 to 8, and
Stage 8 is #10. A deviation from a stage's exit criteria is recorded in its
**Status:** line first, and status never goes in a heading. Stage 0 recorded
one: the parent issue reaches the board only once `zupdf:1` is added to
`.github/scripts/stage-cards.sh` in `pedrobtz/packages`.

zupdf depended on a sibling before CRAN did: `LinkingTo: zufast (>= 0.1.0)`,
which was on `Remotes: pedrobtz/zufast@main` until zufast reached CRAN and
`Remotes:` was removed in Stage 8. Sibling packages that depend on zupdf:
none. The design's pdfio pin moves from 1.6.5 to 1.7.0 in its own pull
request when upstream tags it (design D12); `vendor-upstream.yaml` raises
the issue.

## Commands

The everyday `devtools` commands are in `.claude/shared/r-package.md`. Two
additions:

```sh
rm src/*.o   # after changing a header, before load_all(): pkgbuild
             # does not track headers
_R_CHECK_SYSTEM_CLOCK_=0 Rscript -e 'devtools::check(cran = TRUE)'
```

roxygen2 must be 8.1.0 or newer.

Gate scripts, with the roadmap stage that added each:

<!-- markdownlint-disable MD013 -->
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
<!-- markdownlint-enable MD013 -->

Run `tools/check-symbols` on an `R CMD INSTALL` build, never a `load_all()`
one (`-UNDEBUG` keeps `assert()`s in).

## Architecture

Layout, from design §4, §9 and §14:

<!-- markdownlint-disable MD013 -->
```text
R/            open.R, meta.R, pages.R, objects.R, text.R, images.R, fonts.R,
              writer.R, draw.R, assemble.R, paper.R, values.R, compat.R, data.R,
              conditions.R, args.R, info.R, zupdf-package.R
src/          init.c                          registration only
              zpd_file.c                      pdf_file external pointer; error and password callbacks; temp-file spill
              zpd_value.c                     pdfio values <-> R lists (§6), depth-bounded
              zpd_lex.c                       the content-stream lexer (§8), shared with pdf_page_tokens()
              zpd_font.c, zpd_glyphs.h        fonts: ToUnicode CMaps, encodings, widths, the per-file cache
              zpd_text.c                      the text walk (§8): graphics and text state, forms, layouts
              zpd_writer.c                    pdf_writer: memory output, fonts, images, page replay (D16), determinism
              zpd_core.c                      the R-free core shared with the fuzz target (§15): error callback, dictionary access
              zpd_r.h                         the .Call entry points, one declaration each; statuses by name
              zpd_info.c, zpd_object.c, zpd_string.c, zpd_roundtrip.c
              Makevars                        hand-listed objects; -I vendor/pdfio -DPDFIO_NO_STDIO -D_PDFIO_PUBLIC= -D_PDFIO_PRIVATE=; -lz
              vendor/pdfio/                   pdfio 1.6.5 and its ttf, byte-identical to the tarball plus tools/patches/
              vendor/PROVENANCE
tools/        update-pdfio, verify-vendor, check-symbols, patches/, pdfio-files.txt, fixtures/, gate scripts
fuzz/         fuzz_pdf.c, fuzz_canary.c, fuzz_common.c, fuzz.h, afl-pdf.dict (not in the tarball)
tests/testthat/fixtures/   pdfio testfiles subset, producer PDFs, afl-input, encrypted variants,
                           hashes.tsv, README.md (sources, licences); OpenSans-Regular.ttf only
inst/COPYRIGHTS, LICENSE.note
.agents/      design.md, roadmap.md
```
<!-- markdownlint-enable MD013 -->

Reading: R resolves the input (a path, or a raw vector or connection spilled
to a temporary file the handle owns) → `pdfioFileOpen()` with zupdf's
recording error callback and the password the handle holds → a `pdf_file`
external pointer → every reader goes back to it (pdfio reads lazily by xref),
bounded by the limits → pdfio values converted in `zpd_value.c`, text
extracted in `zpd_text.c`. Writing: `pdf_new()` → `pdfioFileCreate()` or
`pdfioFileCreateOutput()` into an R-owned buffer → `pdf_page` handles with
open content streams → `pdf_save()` closes streams, then the file. Only
`zpd_*.c` include pdfio headers.

## Invariants that are easy to break

- **The error callback records and returns; it never raises** (design D5).
  pdfio holds `malloc()`ed state and open descriptors across its calls; an
  `Rf_error()` inside the callback longjmps over them. Raise from R after the
  pdfio call returns, from the recorded message. The same for the password
  callback: it answers from a string the handle already holds, and a
  `password` function is called in R before `.Call`.
- **No R code runs inside pdfio.** No `R_CheckUserInterrupt()` or R
  allocation while a pdfio stream is open except into the R-owned result
  buffer; interrupts are polled between pdfio calls (every 4 096 tokens in
  the text walk).
- **Nothing pdfio allocates lives outside an external pointer.** `pdf_file`
  owns the `pdfio_file_t`, its temporary file and its caches; `pdf_writer`
  owns the file or buffer and closes abandoned page streams before the file
  in its finalizer. A closed handle is refused by every function.
- **The vendor trees are upstream plus exactly the patch series.**
  `tools/verify-vendor` re-derives both from the pinned tarballs and
  `tools/patches/`; any other edit fails it. Each patch is minimal, named in
  `PROVENANCE`, listed in `zupdf_info()`, asserted by `test-info.R`, and sent
  upstream (with the `PDFIO_NO_STDIO` proposal).
- **CRAN's compiled-code check applies to vendored code too.** pdfio's
  default error callback writes to `stderr`, `copy_png()`'s `setjmp` handler
  calls `fputs(stderr)`, and the `DEBUG` printers reference `fprintf`; all are
  patched out even though zupdf never reaches them. `tools/check-symbols`
  lists stream symbols as well as functions.
- **Limits are checked where they can be.** `max_size` before the spill,
  `max_objects` inside pdfio as it reads the xref (patch 0016), `max_pages`
  after it, `max_stream` in zupdf's own `pdfioStreamRead()` loop, `max_depth`
  in conversion and the text walk's Form XObject recursion (with cycle
  refusal). pdfio has no limits of its own. Guards carry `/* GUARD: name */`
  and a mutation case.
- **Names and strings are different types** (design §6): a `pdf_name` is a
  character scalar with a class; a plain character written to a dictionary is
  a string. Dropping the class turns `/Type /Page` into `(Page)`.
- **Determinism is by argument.** `deterministic = TRUE` fixes the file ID
  and `created =` the date; the writer tests pin bytes only under it, and a
  test that pins bytes without it is flaky by construction. Pins are per zlib
  version (`fixtures/hashes.tsv`), since deflate output differs between zlib
  builds; encrypted output is never byte-stable.
- **No pdfio content stream is open between calls** (design D16): a
  `pdf_page` records operations in R and `pdf_page_end()` writes the page
  whole. pdfio refuses to create an object while a stream is open.
- **The text extractor is project code** (`zpd_text.c`, D10), not a pdfio
  call: changes there are the main maintenance cost and are pinned against
  `pdftools` in the conformance job and exactly in the package tests.
- **DCT streams are returned as JPEG bytes, never decoded** (D6); do not
  vendor a JPEG decoder.
- **No system font lookup** (D7): `pdf_font()` takes a base-14 name or a file
  path; `pdfioFileCreateFontObjFromSystem()` is never called.
- **Portable make only** in `src/Makevars`: hand-listed objects, `-lz`, no
  `$(wildcard)`, no `$(shell)`, no `Makevars.win`.
- **C never calls `Rf_error()`**; statuses by enumerator name,
  `R/conditions.R` raises, pdfio's message prefixes map to classes and
  anything unknown falls to the bare class deliberately.

## Naming

<!-- markdownlint-disable MD013 -->
| Layer | Prefix | Examples |
| --- | --- | --- |
| R exports, native | `pdf_` plus `zupdf_info()`, never a `pdftools` or `qpdf` export name | `pdf_open()`, `pdf_page_text()`, `pdf_draw_text()` |
| R exports, compatibility (design §5.1) | exactly `pdftools`'s and `qpdf`'s names, formals and return shapes | `pdf_text()`, `pdf_info()`, `pdf_combine()` |
| R classes | `pdf_` | `pdf_file`, `pdf_writer`, `pdf_page`, `pdf_name`, `pdf_ref`, `pdf_binary` |
| R condition classes | `zupdf_` | `zupdf_error`, `zupdf_password_error`, `zupdf_warning` |
| R and C internals | `zpd_` / `ZPD_` | `zpd_text_extract()`, `ZPD_STANDALONE` |
| `.Call` entry points | `zupdf_` | `zupdf_open` |
| Test-switching variables | `ZUPDF_` | `ZUPDF_SKIP_HEAVY` |
<!-- markdownlint-enable MD013 -->

Names follow design D8. The compatibility layer (§5.1, `R/compat.R`) reuses
`pdftools`'s and `qpdf`'s names with their exact formals and return shapes,
so `library(zupdf)` can replace `library(pdftools)` for non-rendering work; a
test compares `formals()` with the originals. Every other export uses a name
neither package exports, and a shared name never means something different:
the writer's text function is `pdf_draw_text()`, the native font table
`pdf_font_table()`. Never define a stub for a function zupdf cannot provide
(`pdf_render_page()`, `pdf_convert()`, `pdf_ocr_*()`, `poppler_config()`).

## Editing rules

These add to `.claude/shared/r-package.md`, or depart from it where stated.

- **No `README.Rmd`, unlike the shared rule**: edit `README.md` directly and
  run its example.
- Prose is en-GB (`Language: en-GB`, `inst/WORDLIST`). The package help
  page's first paragraph says zupdf does not render; keep it there.
- Hard runtime dependencies: none. `pdftools`, `qpdf`, `jpeg`, `png` stay in
  `Suggests`.
- Every export has `@return` and runnable `@examples`.
- `NEWS.md` keeps a versioned heading.
- Branches for stages are `stage-N-<slug>`. Performance claims need evidence
  from `tools/run-benchmarks`. A defect in pdfio or ttf, or in `zufast`, gets
  an issue upstream; a pdfio fix also becomes a patch in `tools/patches/`
  until upstream releases it.

## Testing

- **Inputs** are built inside each `test_that()` (`minimal_pdf()` in
  `helper-pdf.R`) or read from `fixtures/`. Files live under
  `withr::local_tempdir()`; handles are closed with `withr::defer()` except
  in the finalizer tests, which leave them deliberately and call `gc()`.
- **Assert on condition classes and fields (`detail`, `object`, `limit`,
  `limit_value`)**, never message text; message wording is pinned in
  snapshots (`_snaps/`).
- The suite runs serially: no `Config/testthat/parallel`.
- **The conformance oracles** are pdfio's own `afl-input` corpus (every case
  must open and read or be refused with a classed condition, nothing on
  stderr; at 1.6.5 all 23 open), `pdftools::pdf_text()` after whitespace
  normalisation and `qpdf` on written files, both in the `conformance` job
  only (`Suggests`). Pinned bytes under `deterministic = TRUE` in
  `fixtures/hashes.tsv` are the package's own gate. None covers rendering,
  which the package does not do.
- **Helpers**: `helper-pdf.R` (`fixture()`; the builders `minimal_pdf()`,
  `stream_pdf()`, `build_pdf()`, `page_pdf()`, `image_pdf()`, `written()`;
  `reread()`, `text_of()`, `roundtrip()`; the corpus `afl_files()`,
  `corpus_files()`, `read_corpus()`, `corpus_pins()`), `helper-expect.R`
  (`expect_zupdf_error()`, `expect_pdf_bytes()`, `expect_text_equal()`,
  `bytes_md5()`), `helper-copy.R` (`chain_pdf()`, `linked_pdf()`,
  `objects_of_type()`, for page copying), `helper-pins.R` (`pinned_cases`,
  one deterministic file per writer function, and `pinned_hashes()`),
  `helper-skip.R` (`skip_heavy()` on `ZUPDF_SKIP_HEAVY`); testthat's own
  `skip_if_not_installed()` for `pdftools`, `qpdf`, `jpeg`, `png`. The
  encrypted fixtures are read with `fixture()`.
- **Fixtures are data**, fetched only by `tools/update-fixtures`, with
  `fixtures/README.md` naming every source and licence; the font licences
  ride along; only `OpenSans-Regular.ttf` ships.
- **CRAN time budget: under 15 s.** The thousand-handle, Flate-bomb and
  million-object tests call `skip_heavy()`.

## Definition of done

In addition to the shared definition: `gctorture(TRUE)` clean when C
changed, and CI green including `vendor.yaml`. A change to a contract (the
exports, the value mapping, the limits, the patch series, the pin) amends
the design in the same commit. A stage is done when its exit criteria pass in
CI on all three platforms; a gate counts once it has been seen to fail.

## Releasing to CRAN

The shared release steps apply. What is specific to zupdf: entering
`Pre-flight` also needed zufast on CRAN with `Remotes:` removed, and the
tarball must stay under 5 MB.

## Continuous integration

- `R-CMD-check.yaml` (`r-cmd-check.yml@v1`). **A deviation from `ci.md`:**
  it runs quick on pull requests and full on every push to `main` and under
  `full-ci`, not `profile: auto`.
- `coverage.yaml` (`coverage.yml`, pinned by commit, v1.22.0).
- `vendor.yaml` (`vendor.yml@v1`): `tools/verify-vendor` and
  `tools/check-symbols` on every push, so an upstream bump cannot bring a
  forbidden symbol back.
- `vendor-upstream.yaml` (`vendor-upstream.yml@v1`), weekly on Mondays: a
  new pdfio or ttf tag opens an issue.
- `native-checks.yaml`, weekly on Wednesdays: sanitizers (UBSan, ASan with
  `-UNDEBUG`), valgrind, LTO, gctorture, analyzers and blocking rchk, all at
  `@v1`; sanitizers and valgrind follow the same quick/full rule as
  R-CMD-check, and gctorture is quick on every pull request.
- `hardening.yaml`, the package's own: lint, no-network and mutation check;
  fuzz seeded from `afl-input`, 120 s per push and 30 minutes nightly.
- `conformance.yaml`, the package's own: `pdftools`, `qpdf`, cross-runner
  bytes, benchmarks.
- `pkgdown.yaml`.

Dependabot updates the GitHub Actions. Every stage touches `src/`, so stage
pull requests carry `full-ci`, a deviation from the shared quick-by-default
rule that the roadmap sets.

## Vendored native code

pdfio (Apache-2.0 with an exception permitting linking against GPL2-only
software) pinned at **v1.6.5**, upstream's latest release on 2026-10-08, with
its `ttf` library (same licence), which ships inside pdfio's own release
tarball from 1.6.0, in `src/vendor/pdfio/` with provenance in
`src/vendor/PROVENANCE`. Re-vendor with `tools/update-pdfio <version>`,
never by hand. The `License:` field is `MIT + file LICENSE` with
`Copyright: file inst/COPYRIGHTS` (design D15). The rules are in
`.claude/shared/native-code.md`; what follows is zupdf's.

- The RFC's reading of `master` (1.7.0) is recorded in design §9 as what
  arrives when that tag exists. 1.6.5 carries the AES fix
  GHSA-527h-2p2v-g388, the floor on the pin. 1.6.6 is out (#97).
- `PROVENANCE` records the tags, the commits, the tarball checksums, the file
  lists, every patch with its reason and its upstream report, and the
  compiler warnings seen; keep `tools/update-pdfio` mechanical.
- Reproduce both libraries' `NOTICE` texts with the exception in
  `inst/COPYRIGHTS`; declare Michael R Sweet as `cph` in `Authors@R` with a
  comment naming pdfio and ttf; keep `LICENSE.note` current.
- Only the library sources, headers and licence files are vendored: no
  examples (the `pdf2text.c` algorithm is ported into `src/zpd_text.c` as
  project code, D10), no tests, `Makefile.in`, IDE projects or
  documentation. `HAVE_LIBPNG` and `HAVE_LIBWEBP` are never defined.
- The patch set (design D4):
  - `0001-visibility-override`: pdfio marks its API `visibility("default")`;
    `Makevars` defines `_PDFIO_PUBLIC` and `_PDFIO_PRIVATE` empty so only
    `R_init_zupdf` is exported.
  - `0002-no-stdio`: `PDFIO_NO_STDIO` leaves out the default error
    callback's `stderr` write, ttf's `errorf()` fallback and the three debug
    printers, which are compiled in every build. `copy_png()`'s `fputs` is
    under `HAVE_LIBPNG` and never compiled. When the pin moves to 1.7.0,
    `ttf-cache.c` needs the same treatment.
  - `0003-date-buffer` enlarges two date buffers that gcc's
    `-Wformat-truncation` flagged.
  - `0004-undefined-behaviour` fixes what UBSan reports in pdfio: calls
    through mistyped function pointers (token, crypt and comparator
    callbacks), a `memcpy()` from NULL and pointer arithmetic on NULL.
  - `0005-unsigned-shifts`: the signed overflow of `byte << 24` in ttf.c and
    the PNG reader.
  - `0006-dict-getstring` stops a read from rewriting a UTF-16 value as
    UTF-8.
  - `0007-number-casts` clamps every number read from a file before it
    becomes an integer (the fuzzer's first find).
  - `0008-repair-loop` stops the cross-reference repair looping for ever.
  - `0009-index-cast` clamps the `/Index` cast 0007 missed.
  - `0010-ttf-callbacks` gives the ttf callbacks the right types.
  - `0011-object-value-leak` frees an object's own hex-string value.
  - `0012-trailer-value-leak` frees a trailer that is not a dictionary.
  - `0013-objstm-value-leak` frees an object's value before an object stream
    reads it again.
  - `0014-date-utc` converts dates without `mktime()`, since `Makevars`
    cannot detect `timegm()`.
  - `0015-copy-depth` bounds the depth of copying between files and moves its
    buffer off the stack.
  - `0016-object-limit` adds `_pdfioFileOpenMax()`, through which
    `max_objects` refuses objects as pdfio reads them.
  - `0017-xref-shifts` builds cross-reference-stream offsets and generations
    in unsigned types.
  - `0018-number-checks` clamps an indirect `/Length` and checks a
    cross-reference table's object range.
- Each patch adds a modification notice to the files it changes (Apache-2.0
  §4(b)); `verify-vendor` checks it. Every patch identifier is listed in
  `zupdf_info()` and asserted in `test-info.R`.
- zlib is linked from the system (`PKG_LIBS = -lz`), never vendored: R
  requires it on every CRAN platform.
