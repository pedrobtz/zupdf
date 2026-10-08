test_that("pdf_open() opens a path, a raw vector and a connection", {
  path <- minimal_pdf(
    pages = 2L,
    path = withr::local_tempfile(fileext = ".pdf")
  )
  inputs <- list(path, readBin(path, "raw", file.size(path)), file(path))
  for (x in inputs) {
    pdf <- pdf_open(x)
    withr::defer(pdf_close(pdf))
    expect_s3_class(pdf, "pdf_file")
    expect_identical(length(pdf), 2L)
  }
})

test_that("pdf_open() reads an already-open connection without closing it", {
  path <- minimal_pdf(path = withr::local_tempfile(fileext = ".pdf"))
  con <- file(path, "rb")
  withr::defer(close(con))
  pdf <- pdf_open(con)
  withr::defer(pdf_close(pdf))
  expect_true(isOpen(con))
  expect_identical(length(pdf), 1L)
})

test_that("pdf_open() passes an open pdf_file through", {
  pdf <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(pdf))
  expect_identical(pdf_open(pdf), pdf)
})

test_that("a missing file is a zupdf_io_error", {
  expect_zupdf_error(
    pdf_open(file.path(withr::local_tempdir(), "missing.pdf")),
    "zupdf_io_error"
  )
  expect_zupdf_error(pdf_open(withr::local_tempdir()), "zupdf_io_error")
})

test_that("bytes that are not a PDF are a zupdf_parse_error with detail", {
  err <- expect_zupdf_error(
    pdf_open(charToRaw("not a pdf at all")),
    "zupdf_parse_error"
  )
  expect_type(err$detail, "character")
  expect_true(nzchar(err$detail))
})

test_that("pdfio's warnings arrive as one zupdf_warning with a count", {
  # A header and nothing else: pdfio warns that it will rebuild the
  # cross-reference table, then fails.
  w <- NULL
  err <- tryCatch(
    withCallingHandlers(
      pdf_open(charToRaw("%PDF-1.4\ngarbage")),
      zupdf_warning = function(c) {
        w <<- c
        invokeRestart("muffleWarning")
      }
    ),
    zupdf_error = identity
  )
  expect_s3_class(err, "zupdf_parse_error")
  expect_s3_class(w, "zupdf_warning")
  expect_identical(w$count, 1L)
  expect_match(w$detail, "^WARNING:")
})

test_that("arguments are checked", {
  bytes <- minimal_pdf()
  expect_zupdf_error(pdf_open(1), "zupdf_invalid_argument", arg = "x")
  expect_zupdf_error(pdf_open(NA_character_), "zupdf_invalid_argument")
  expect_zupdf_error(pdf_open(bytes, 5), "zupdf_invalid_argument")
  expect_zupdf_error(
    pdf_open(bytes, password = c("a", "b")),
    "zupdf_invalid_argument",
    arg = "password"
  )
  expect_zupdf_error(
    pdf_open(bytes, oops = 1),
    "zupdf_invalid_argument",
    arg = "..."
  )
  for (bad in list(0, -1, 1.5, NA, "1", c(1, 2))) {
    expect_zupdf_error(
      pdf_open(bytes, max_pages = bad),
      "zupdf_invalid_argument",
      arg = "max_pages"
    )
  }
  expect_no_error(pdf_close(pdf_open(bytes, max_pages = Inf)))
})

# ---- limits -----------------------------------------------------------------

test_that("max_size refuses a raw vector, a path and a connection", {
  bytes <- minimal_pdf()
  path <- withr::local_tempfile(fileext = ".pdf")
  writeBin(bytes, path)
  n <- length(bytes)
  for (x in list(bytes, path, file(path))) {
    expect_zupdf_error(
      pdf_open(x, max_size = n - 1),
      "zupdf_limit_error",
      limit = "max_size",
      limit_value = n - 1
    )
  }
  expect_no_error(pdf_close(pdf_open(bytes, max_size = n)))
})

test_that("max_pages and max_objects are checked after the xref is read", {
  bytes <- minimal_pdf(pages = 3L)
  expect_zupdf_error(
    pdf_open(bytes, max_pages = 2),
    "zupdf_limit_error",
    limit = "max_pages",
    limit_value = 2
  )
  expect_no_error(pdf_close(pdf_open(bytes, max_pages = 3)))
  # 3 pages: catalog, page tree, font, and a page and stream each.
  expect_zupdf_error(
    pdf_open(bytes, max_objects = 8),
    "zupdf_limit_error",
    limit = "max_objects"
  )
  expect_no_error(pdf_close(pdf_open(bytes, max_objects = 9)))
})

# ---- passwords --------------------------------------------------------------

test_that("an encrypted file opens with no password when it has none", {
  for (f in c("encrypted-rc4-128.pdf", "encrypted-aes-128.pdf")) {
    pdf <- pdf_open(fixture(f))
    withr::defer(pdf_close(pdf))
    expect_identical(length(pdf), 1L)
  }
})

test_that("a password-protected file needs its user or owner password", {
  for (f in c("encrypted-rc4-128-pw.pdf", "encrypted-aes-128-pw.pdf")) {
    expect_zupdf_error(pdf_open(fixture(f)), "zupdf_password_error")
    expect_zupdf_error(
      pdf_open(fixture(f), password = "wrong"),
      "zupdf_password_error"
    )
    for (pw in c("user", "owner")) {
      pdf <- pdf_open(fixture(f), password = pw)
      expect_identical(length(pdf), 1L)
      pdf_close(pdf)
    }
  }
})

test_that("a password function is called only when one is needed", {
  calls <- 0L
  ask <- function(name) {
    calls <<- calls + 1L
    "user"
  }
  pdf <- pdf_open(minimal_pdf(), password = ask)
  pdf_close(pdf)
  expect_identical(calls, 0L)

  pdf <- pdf_open(fixture("encrypted-aes-128-pw.pdf"), password = ask)
  pdf_close(pdf)
  expect_identical(calls, 1L)

  # A spilled raw vector survives the first, failed attempt.
  bytes <- readBin(fixture("encrypted-rc4-128-pw.pdf"), "raw", 1e6)
  pdf <- pdf_open(bytes, password = ask)
  pdf_close(pdf)
  expect_identical(calls, 2L)
})

test_that("a password function must return a string", {
  expect_zupdf_error(
    pdf_open(fixture("encrypted-aes-128-pw.pdf"), password = function(x) 1),
    "zupdf_invalid_argument",
    arg = "password"
  )
})

# ---- closing and temporary files ---------------------------------------------

test_that("a closed handle is refused everywhere and closing twice is fine", {
  pdf <- pdf_open(minimal_pdf())
  pdf_close(pdf)
  expect_no_error(pdf_close(pdf))
  expect_zupdf_error(pdf_meta(pdf), "zupdf_invalid_argument", arg = "pdf")
  expect_zupdf_error(pdf_pages(pdf), "zupdf_invalid_argument", arg = "pdf")
  expect_zupdf_error(length(pdf), "zupdf_invalid_argument", arg = "pdf")
  expect_zupdf_error(pdf_open(pdf), "zupdf_invalid_argument", arg = "pdf")
  expect_output(print(pdf), "(closed)", fixed = TRUE)
})

test_that("a spilled copy is removed by pdf_close() and by the finalizer", {
  spilled <- function() {
    list.files(tempdir(), pattern = "^zupdf-.*[.]pdf$", full.names = TRUE)
  }
  gc() # other tests' unclosed handles
  before <- spilled()
  pdf <- pdf_open(minimal_pdf())
  expect_length(setdiff(spilled(), before), 1L)
  pdf_close(pdf)
  expect_length(setdiff(spilled(), before), 0L)

  local(pdf_open(minimal_pdf()))
  gc()
  expect_length(setdiff(spilled(), before), 0L)

  # A failed open leaves nothing behind either.
  try(pdf_open(charToRaw("not a pdf")), silent = TRUE)
  try(pdf_open(minimal_pdf(pages = 2L), max_pages = 1), silent = TRUE)
  expect_length(setdiff(spilled(), before), 0L)
})

test_that("a thousand unclosed handles leave no descriptors or files", {
  skip_heavy()
  fds <- function() {
    d <- "/proc/self/fd"
    if (dir.exists(d)) length(list.files(d)) else NA_integer_
  }
  gc() # other tests' unclosed handles
  before_fd <- fds()
  before <- list.files(tempdir(), pattern = "^zupdf-")
  bytes <- minimal_pdf()
  for (i in 1:1000) {
    pdf_open(bytes)
  }
  gc()
  gc()
  expect_identical(list.files(tempdir(), pattern = "^zupdf-"), before)
  if (!is.na(before_fd)) {
    expect_lte(fds(), before_fd + 5L)
  }
})

test_that("print() and format() describe the file", {
  pdf <- pdf_open(minimal_pdf(pages = 2L))
  withr::defer(pdf_close(pdf))
  out <- format(pdf)
  expect_identical(out[[1L]], "<pdf_file>")
  expect_match(out[[3L]], "PDF 1.4, 2 pages, not encrypted", fixed = TRUE)
  expect_output(print(pdf), "<pdf_file>", fixed = TRUE)
})
