# pdfio's afl-input corpus: PDFs from PDFBox's issue tracker, some
# malformed. Each must either open and read, or be refused with a classed
# condition; nothing may crash (design section 15).

test_that("every afl-input case opens or is refused with a classed error", {
  files <- afl_files()
  expect_gt(length(files), 20L)
  for (f in files) {
    res <- tryCatch(
      suppressWarnings(read_all(f)),
      zupdf_error = function(e) "refused"
    )
    if (!identical(res, "refused")) {
      expect_identical(res$rows, res$pages, label = basename(f))
    } else {
      succeed()
    }
  }
})

test_that("reading the afl-input corpus writes nothing to stderr", {
  skip_heavy()
  skip_on_cran()
  # A child R process, so that anything written to the C stderr is caught.
  script <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      "suppressMessages(library(zupdf))",
      sprintf("files <- %s", deparse1(afl_files())),
      "for (f in files) try(suppressWarnings({",
      "  p <- pdf_open(f); pdf_meta(p); pdf_pages(p); pdf_close(p)",
      "}), silent = TRUE)"
    ),
    script
  )
  rscript <- file.path(R.home("bin"), "Rscript")
  out <- withr::local_tempfile()
  err <- withr::local_tempfile()
  status <- system2(rscript, script, stdout = out, stderr = err)
  skip_if(status != 0L, "zupdf is not installed for a child process")
  expect_identical(readLines(err), character())
})
