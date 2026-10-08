# Expectations shared by the test files. They live here, not at the top of a
# test file, because devtools::test(shuffle = TRUE) reorders a file's
# top-level expressions, definitions included.

# `expr` raises `class` (a zupdf condition), and each field named in `...`
# has the value given. Asserts on classes and fields, never on the message.
expect_zupdf_error <- function(expr, class, ...) {
  err <- expect_error(expr, class = class)
  expect_s3_class(err, "zupdf_error")
  fields <- list(...)
  for (f in names(fields)) {
    expect_identical(err[[f]], fields[[f]], label = paste0("$", f))
  }
  invisible(err)
}

# Text equal after whitespace normalisation: runs of white space become one
# space and the ends are trimmed. For comparing extracted text with another
# extractor's, whose spacing differs by design (design section 5.1).
normalise_ws <- function(x) trimws(gsub("[[:space:]]+", " ", x))

expect_text_equal <- function(object, expected) {
  expect_identical(normalise_ws(object), normalise_ws(expected))
}

# The MD5 of bytes (a raw vector) or of a file, as a lower-case string.
bytes_md5 <- function(x) {
  if (is.raw(x)) {
    path <- withr::local_tempfile()
    writeBin(x, path)
    x <- path
  }
  unname(tools::md5sum(x))
}

# Written bytes are exactly the pinned ones (design section 7: only under
# deterministic = TRUE). `hash` is the MD5 recorded in fixtures/hashes.tsv.
expect_pdf_bytes <- function(object, hash) {
  expect_identical(bytes_md5(object), hash)
}
