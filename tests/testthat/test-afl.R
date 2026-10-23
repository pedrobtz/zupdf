# pdfio's afl-input corpus (PDFs from PDFBox's issue tracker, some
# malformed) and the inputs tools/run-fuzz found. What each reads is pinned
# in fixtures/corpus.tsv; nothing may crash or write to stderr (design
# sections 15 and 19).

test_that("every corpus file has a pinned outcome", {
  pins <- corpus_pins()
  files <- basename(c(afl_files(), corpus_files("fuzz")))
  expect_gt(length(afl_files()), 20L)
  expect_setequal(pins$file, files)
})

test_that("every afl-input case opens and reads as pinned", {
  pins <- corpus_pins()
  for (f in afl_files()) {
    pin <- pins[pins$file == basename(f), ]
    expect_identical(
      read_corpus(f),
      as.list(pin[, -1L]),
      label = basename(f)
    )
  }
})

test_that("every fuzz-found input reads as pinned or is refused", {
  # Each was fixed by a pdfio patch or a zupdf change (fixtures/README.md).
  pins <- corpus_pins()
  for (f in corpus_files("fuzz")) {
    pin <- pins[pins$file == basename(f), ]
    if (is.na(pin$pages)) {
      expect_zupdf_error(
        suppressWarnings(pdf_open(f)),
        "zupdf_parse_error"
      )
    } else {
      expect_identical(
        read_corpus(f),
        as.list(pin[, -1L]),
        label = basename(f)
      )
    }
  }
})

test_that("reading the corpus neither crashes nor writes to stderr", {
  skip_heavy()
  # A child R process, so that a crash or anything written to the C stderr
  # is seen. It loads the zupdf under test: the source tree, already built,
  # under devtools::test(); otherwise the installed copy the namespace came
  # from, not whichever zupdf is first on the library path.
  path <- getNamespaceInfo("zupdf", "path")
  dev <- isNamespaceLoaded("pkgload") && pkgload::is_dev_package("zupdf")
  load <- if (dev) {
    sprintf(
      "pkgload::load_all(%s, compile = FALSE, quiet = TRUE)",
      deparse1(path)
    )
  } else {
    sprintf(
      "suppressMessages(library(zupdf, lib.loc = %s))",
      deparse1(dirname(path))
    )
  }
  files <- normalizePath(c(afl_files(), corpus_files("fuzz")))
  script <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      load,
      sprintf("files <- %s", deparse1(files)),
      "for (f in files) try(suppressWarnings({",
      "  p <- pdf_open(f)",
      "  pdf_meta(p); pdf_pages(p); o <- pdf_objects(p)",
      "  for (n in o$number) try(pdf_object(p, n), silent = TRUE)",
      "  for (n in o$number[!is.na(o$length)]) {",
      "    try(pdf_stream(p, n), silent = TRUE)",
      "  }",
      "  pdf_page_text(p); pdf_page_text(p, layout = 'raw')",
      "  for (i in seq_len(length(p))) {",
      "    pdf_page_tokens(p, i)",
      "    for (k in pdf_page_images(p, i)$object) {",
      "      try(pdf_image(p, k), silent = TRUE)",
      "    }",
      "  }",
      "  pdf_close(p)",
      "}), silent = TRUE)",
      "cat('done\\n')"
    ),
    script
  )
  rscript <- file.path(R.home("bin"), "Rscript")
  out <- withr::local_tempfile()
  err <- withr::local_tempfile()
  status <- system2(rscript, c("--vanilla", script), stdout = out, stderr = err)
  # Every call is wrapped in try(), so only a crash or abort() stops it.
  expect_identical(status, 0L)
  expect_identical(readLines(out), "done")
  expect_identical(readLines(err), character())
})
