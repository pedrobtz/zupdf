# The helpers are tested here so a failure elsewhere is never the helper's.

test_that("minimal_pdf() writes a header, a correct xref and a trailer", {
  bytes <- minimal_pdf(text = c("one", "two"), info = c(Title = "T"))
  # High bytes (the binary-marker comment) become "?", so offsets in bytes
  # are offsets in characters.
  bytes[bytes >= as.raw(0x80)] <- charToRaw("?")
  txt <- rawToChar(bytes)
  expect_true(startsWith(txt, "%PDF-1.4\n%????\n"))
  expect_true(endsWith(txt, "%%EOF\n"))

  # Every in-use xref entry points at "<n> 0 obj", and startxref at "xref".
  startxref <- as.integer(sub(".*startxref\n([0-9]+)\n.*", "\\1", txt))
  expect_identical(substr(txt, startxref + 1L, startxref + 4L), "xref")
  xref <- substring(txt, startxref + 1L)
  entries <- regmatches(xref, gregexpr("[0-9]{10} 00000 n", xref))[[1]]
  offsets <- as.integer(substr(entries, 1L, 10L))
  expect_length(offsets, 8L) # catalog, pages, font, 2 x (page, content), info
  for (k in seq_along(offsets)) {
    want <- sprintf("%d 0 obj", k)
    got <- substr(txt, offsets[k] + 1L, offsets[k] + nchar(want))
    expect_identical(got, want)
  }
})

test_that("minimal_pdf() writes to a path when given one", {
  path <- withr::local_tempfile(fileext = ".pdf")
  expect_identical(minimal_pdf(path = path), path)
  expect_identical(readBin(path, "raw", 5L), charToRaw("%PDF-"))
})

test_that("minimal_pdf() is a PDF another reader accepts", {
  skip_if_not_installed("pdftools")
  path <- minimal_pdf(
    text = c("hello (world)", "back\\slash"),
    info = c(Title = "A title"),
    path = withr::local_tempfile(fileext = ".pdf")
  )
  info <- pdftools::pdf_info(path)
  expect_identical(info$pages, 2L)
  expect_identical(info$keys$Title, "A title")
  expect_text_equal(
    pdftools::pdf_text(path),
    c("hello (world)", "back\\slash")
  )
})

test_that("expect_text_equal() ignores runs of white space", {
  expect_text_equal("  a \n\n b\t", "a b")
})

test_that("bytes_md5() hashes raw vectors and files alike", {
  bytes <- charToRaw("abc")
  path <- withr::local_tempfile()
  writeBin(bytes, path)
  expect_identical(bytes_md5(bytes), "900150983cd24fb0d6963f7d28e17f72")
  expect_identical(bytes_md5(path), bytes_md5(bytes))
})

test_that("fixture() refuses a missing fixture", {
  expect_error(fixture("no-such-file.pdf"), "update-fixtures")
})
