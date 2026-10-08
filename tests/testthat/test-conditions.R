test_that("zpd_abort() raises the class under zupdf_error with its fields", {
  err <- tryCatch(
    zpd_abort("zupdf_parse_error", "m", object = 12L, detail = "bad xref"),
    error = identity
  )
  expect_identical(
    class(err),
    c("zupdf_parse_error", "zupdf_error", "error", "condition")
  )
  expect_identical(err$object, 12L)
  expect_identical(err$detail, "bad xref")
})

test_that("every design section 11 class can be raised and caught", {
  for (cls in zpd_condition_classes) {
    err <- tryCatch(zpd_abort(cls, "m"), zupdf_error = identity)
    expect_s3_class(err, cls)
    expect_s3_class(err, "error")
  }
})

test_that("zpd_abort() refuses a class outside the hierarchy", {
  expect_error(zpd_abort("zupdf_made_up", "m"))
})

test_that("zpd_invalid_argument() carries the argument's name", {
  expect_zupdf_error(
    zpd_invalid_argument("max_depth", "m"),
    "zupdf_invalid_argument",
    arg = "max_depth"
  )
})

test_that("zpd_limit_error() carries the limit and its value", {
  expect_zupdf_error(
    zpd_limit_error("max_stream", 1024, "m"),
    "zupdf_limit_error",
    limit = "max_stream",
    limit_value = 1024
  )
})

test_that("zpd_warn() raises a zupdf_warning", {
  w <- tryCatch(zpd_warn("m", count = 2L), warning = identity)
  expect_s3_class(w, "zupdf_warning")
  expect_identical(w$count, 2L)
})

test_that("every known pdfio message prefix maps to its class", {
  expected <- c(
    "Unable to unlock PDF file." = "zupdf_password_error",
    "Unable to unlock AES-256 encrypted file at this time." = "zupdf_unsupported_input",
    "Unable to open file - No such file or directory" = "zupdf_io_error",
    "Unable to open image file 'x.png': No such file or directory" = "zupdf_io_error",
    "Unable to open font file 'x.ttf': No such file or directory" = "zupdf_io_error",
    "Unsupported image file 'x.gif'." = "zupdf_unsupported_input"
  )
  for (msg in names(expected)) {
    expect_identical(zpd_pdfio_class(msg), expected[[msg]], label = msg)
  }
  # The table and this test change together.
  expect_length(zpd_pdfio_prefixes, length(expected))
})

test_that("an unknown pdfio message falls to the bare default class", {
  expect_identical(zpd_pdfio_class("Missing Root object."), "zupdf_parse_error")
  expect_identical(zpd_pdfio_class(NA_character_), "zupdf_parse_error")
  expect_identical(
    zpd_pdfio_class("Unable to write trailer.", "zupdf_write_error"),
    "zupdf_write_error"
  )
})

test_that("zpd_unwrap() raises by status and warns once for warnings", {
  res <- function(status, detail = NA_character_, nwarning = 0L) {
    list(
      status = status,
      value = 1,
      detail = detail,
      nwarning = nwarning,
      warning = if (nwarning) "WARNING: w" else NA_character_
    )
  }
  expect_identical(zpd_unwrap(res("ok"), "x"), 1)
  expect_zupdf_error(
    zpd_unwrap(res("pdfio", "Unable to unlock PDF file."), "x"),
    "zupdf_password_error",
    detail = "Unable to unlock PDF file."
  )
  expect_zupdf_error(
    zpd_unwrap(res("closed"), "x"),
    "zupdf_invalid_argument",
    arg = "pdf"
  )
  expect_zupdf_error(
    zpd_unwrap(res("max_depth"), "x", limits = list(max_depth = 3)),
    "zupdf_limit_error",
    limit = "max_depth",
    limit_value = 3
  )
  w <- tryCatch(zpd_unwrap(res("ok", nwarning = 3L), "x"), warning = identity)
  expect_s3_class(w, "zupdf_warning")
  expect_identical(w$count, 3L)
  expect_error(zpd_unwrap(res("bogus"), "x"), "unknown status")
})
