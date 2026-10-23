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
  # An internal check, so a plain error rather than a zupdf class.
  err <- expect_error(zpd_abort("zupdf_made_up", "m"), class = "simpleError")
  expect_false(inherits(err, "zupdf_error"))
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
    "Unsupported image file 'x.gif'." = "zupdf_unsupported_input",
    "Unsupported PNG color type 6." = "zupdf_unsupported_input"
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
  pw <- res("pdfdoc")
  pw$value <- "owner"
  expect_zupdf_error(
    zpd_unwrap(pw, "x"),
    "zupdf_invalid_argument",
    arg = "owner"
  )
  expect_zupdf_error(
    zpd_unwrap(res("bogus"), "x"),
    "zupdf_parse_error",
    detail = "bogus"
  )
})

test_that("C refuses a closed handle itself, not only through R", {
  # R checks every handle before .Call, so these branches are reached only
  # by calling C directly, as an internal caller that skipped R's check
  # would (design section 13).
  pdf <- pdf_open(minimal_pdf())
  pdf_close(pdf)
  file_calls <- list(
    .Call(zupdf_counts, pdf),
    .Call(zupdf_meta, pdf),
    .Call(zupdf_pages, pdf, 10L),
    .Call(zupdf_page_xobjects, pdf, 1L, 10L),
    .Call(zupdf_objects, pdf),
    .Call(zupdf_object, pdf, 1, 10L),
    .Call(zupdf_stream, pdf, 4, TRUE, 1e6),
    .Call(zupdf_doc_dict, pdf, "catalog", 10L),
    .Call(zupdf_page_text, pdf, 1L, FALSE, 10L, 1e6),
    .Call(zupdf_page_glyphs, pdf, 1L, 10L, 1e6),
    .Call(zupdf_page_tokens, pdf, 1L, 1e6)
  )
  for (res in file_calls) {
    expect_identical(res$status, "closed")
  }
  expect_false(.Call(zupdf_is_open, pdf))

  w <- pdf_new()
  pdf_save(w)
  src <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(src))
  writer_calls <- list(
    .Call(zupdf_writer_font, w, 1L, "Helvetica"),
    .Call(zupdf_writer_image_file, w, "x.png", FALSE),
    .Call(zupdf_writer_image_data, w, raw(3), 1L, 1L, 3L, FALSE, FALSE),
    .Call(zupdf_writer_page, w, NULL, NULL, NULL, NULL, NULL, NULL, 10L),
    .Call(zupdf_writer_save, w, 0, TRUE),
    .Call(zupdf_writer_set_meta, w, character(), character(), NA_real_),
    .Call(zupdf_writer_set_encryption, w, 3L, -1L, NULL, NULL)
  )
  for (res in writer_calls) {
    expect_identical(res$status, "closed")
  }
  expect_identical(
    .Call(zupdf_writer_copy_pages, w, src, 1L, 0L, TRUE)$status,
    "closed_writer"
  )
  expect_identical(
    .Call(zupdf_writer_measure, w, 1L, "x", 12)$status,
    "closed_writer"
  )
  expect_false(.Call(zupdf_writer_is_open, w))

  # An open writer, with a closed source file.
  w2 <- pdf_new()
  withr::defer(pdf_save(w2))
  expect_identical(
    .Call(zupdf_writer_copy_pages, w2, pdf, 1L, 0L, TRUE)$status,
    "closed"
  )
})

test_that("every status from C raises a zupdf_error, with its class", {
  res <- function(status) {
    list(status = status, value = 1, detail = "d", nwarning = 0L)
  }
  expected <- c(
    closed = "zupdf_invalid_argument",
    pdfio = "zupdf_write_error",
    max_depth = "zupdf_limit_error",
    form_cycle = "zupdf_limit_error",
    max_stream = "zupdf_limit_error",
    unknown_object = "zupdf_invalid_argument",
    no_stream = "zupdf_invalid_argument",
    unknown_ref = "zupdf_invalid_argument",
    font = "zupdf_font_error",
    image = "zupdf_parse_error",
    memory = "zupdf_parse_error",
    unsupported = "zupdf_invalid_argument",
    closed_writer = "zupdf_write_error",
    bad_ops = "zupdf_write_error",
    pdfdoc = "zupdf_invalid_argument",
    max_objects = "zupdf_limit_error",
    max_stream_page = "zupdf_limit_error"
  )
  expect_setequal(c("ok", names(expected)), zpd_c_statuses)
  limits <- list(max_depth = 1, max_stream = 1, max_objects = 1)
  for (s in names(expected)) {
    expect_zupdf_error(
      zpd_unwrap(res(s), "x", default = "zupdf_write_error", limits = limits),
      expected[[s]]
    )
  }
  expect_zupdf_error(
    zpd_unwrap(res("unknown_ref"), "x", arg = "dict"),
    "zupdf_invalid_argument",
    arg = "dict"
  )
})

test_that("C returns no status zpd_unwrap() does not know", {
  src <- test_path("..", "..", "src")
  skip_if_not(dir.exists(src), "no src/ beside the tests")
  code <- unlist(lapply(
    list.files(src, pattern = "^zpd_.*\\.c$", full.names = TRUE),
    readLines
  ))
  calls <- regmatches(
    code,
    gregexpr(
      paste0(
        "zpd_(status|result)\\(\"[a-z_]+\"|zpd_fail\\([a-z]+, \"[a-z_]+\"|",
        "return \"[a-z_]+\";|status = \"[a-z_]+\";"
      ),
      code
    )
  )
  expect_true("form_cycle" %in% gsub(".*\"([a-z_]+)\".*", "\\1", unlist(calls)))
  found <- unique(gsub(".*\"([a-z_]+)\".*", "\\1", unlist(calls)))
  expect_length(setdiff(found, zpd_c_statuses), 0L)
})
