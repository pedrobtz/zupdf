## Submission

This is a new submission.

zupdf bundles the pdfio PDF library (<https://github.com/michaelrsweet/pdfio>,
version 1.6.5, with its ttf font library) in `src/vendor/pdfio/`, so it needs
no system library beyond zlib, which R itself requires.

## Test environments

* local macOS (aarch64), R 4.6.1
* GitHub Actions: ubuntu-latest (R release, oldrel-1), macOS-latest
  (R release), windows-latest (R release)
* R-hub containers, R-devel: `clang23`, `ubuntu-clang`, `ubuntu-gcc16`
* UBSan, ASan, valgrind, LTO, gctorture, rchk and `-fanalyzer`
* libFuzzer with ASan and UBSan over the parser and text extraction, nightly

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Bundled code

pdfio is Apache-2.0 with exceptions; zupdf's own code is MIT. `LICENSE.note`
explains how the two apply, and `inst/COPYRIGHTS` reproduces pdfio's notice.
Michael R Sweet, pdfio's author, is listed as `cph` in `Authors@R`.

The vendored tree carries twelve small patches, listed with their reasons in
`src/vendor/PROVENANCE`: stdio writes and exported symbols removed, and
compiler warnings, undefined behaviour, a loop and two leaks found by
sanitizers and fuzzing fixed. Each patched file carries a notice saying so,
and each patch is reported upstream.

`src/zpd_glyphs.h` holds the Adobe Glyph List (BSD-3-Clause), used to map
glyph names to Unicode; its notice is in `inst/COPYRIGHTS` and Adobe is listed
as `cph` in `Authors@R`.
