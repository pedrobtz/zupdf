## Submission

This is a new submission.

zupdf bundles the pdfio PDF library (<https://github.com/michaelrsweet/pdfio>,
version 1.6.5, with its ttf font library) in `src/vendor/pdfio/`, so it needs
no system library beyond zlib, which R itself requires.

## Test environments

* local macOS (x86_64), R 4.5.2
* GitHub Actions: macOS-latest, windows-latest and ubuntu-latest (R
  release), ubuntu-latest (R oldrel-1), windows-latest (R-devel)
* R-hub containers, R-devel: `clang23`, `ubuntu-clang`, `ubuntu-gcc16`,
  `nosuggests`, `nold`
* UBSan, ASan, valgrind, LTO, gctorture, rchk and `-fanalyzer`
* libFuzzer with ASan and UBSan over the parser and text extraction,
  30 minutes nightly

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Bundled code

pdfio is Apache-2.0 with exceptions; zupdf's own code is MIT. `LICENSE.note`
explains how the two apply, and `inst/COPYRIGHTS` reproduces pdfio's notice.
Michael R Sweet, pdfio's author, is listed as `cph` in `Authors@R`.

The vendored tree carries eighteen small patches, listed with their reasons
in `src/vendor/PROVENANCE`: stdio writes and exported symbols removed;
compiler warnings, undefined behaviour, a loop and three leaks found by
sanitizers and fuzzing fixed; dates read in UTC whatever the local time
zone; and bounds on copying between files and on the objects a file may
list. Each patched file carries a notice saying so, and every patch is
reported upstream (michaelrsweet/pdfio#182 to #193, and #196).

`src/zpd_glyphs.h` holds the Adobe Glyph List (BSD-3-Clause), used to map
glyph names to Unicode; its notice is in `inst/COPYRIGHTS` and Adobe is listed
as `cph` in `Authors@R`.

The tests read third-party fixtures from pdfio's source tree: the Open Sans
font (Google, Apache-2.0, listed as `cph`) and PDF files from the Apache
PDFBox issue tracker. `inst/COPYRIGHTS` and `LICENSE.note` list them.

## Method References

There are no published references describing the methods in this package.
It implements the PDF format as specified in ISO 32000-2, through the
bundled pdfio library.
