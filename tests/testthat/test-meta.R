test_that("pdf_meta() reads the information dictionary", {
  pdf <- pdf_open(minimal_pdf(
    pages = 3L,
    info = c(
      Title = "A title",
      Author = "An author",
      Subject = "A subject",
      Keywords = "a, b",
      Creator = "tests",
      Producer = "minimal_pdf()"
    )
  ))
  withr::defer(pdf_close(pdf))
  m <- pdf_meta(pdf)
  expect_named(
    m,
    c(
      "version",
      "pages",
      "title",
      "author",
      "subject",
      "keywords",
      "creator",
      "producer",
      "language",
      "created",
      "modified",
      "id",
      "encryption",
      "permissions"
    )
  )
  expect_identical(m$version, "1.4")
  expect_identical(m$pages, 3L)
  expect_identical(m$title, "A title")
  expect_identical(m$author, "An author")
  expect_identical(m$subject, "A subject")
  expect_identical(m$keywords, "a, b")
  expect_identical(m$creator, "tests")
  expect_identical(m$producer, "minimal_pdf()")
  expect_identical(m$language, NA_character_)
  expect_s3_class(m$created, "POSIXct")
  expect_true(is.na(m$created))
  expect_identical(m$id, character())
  expect_identical(m$encryption, "none")
  expect_identical(m$permissions, names(zpd_permission_bits))
})

test_that("absent fields are NA", {
  pdf <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(pdf))
  m <- pdf_meta(pdf)
  for (f in c("title", "author", "subject", "keywords", "creator")) {
    expect_identical(m[[f]], NA_character_, label = f)
  }
})

test_that("dates are POSIXct in UTC", {
  pdf <- pdf_open(minimal_pdf(info = c(CreationDate = "D:20240102030405Z")))
  withr::defer(pdf_close(pdf))
  created <- pdf_meta(pdf)$created
  expect_identical(attr(created, "tzone"), "UTC")
  expect_identical(
    format(created, "%Y-%m-%d %H:%M:%S"),
    "2024-01-02 03:04:05"
  )
})

test_that("PDFDocEncoding strings become UTF-8", {
  # 0x80 is a bullet and 0xA0 the euro sign in PDFDocEncoding; 0xE9 is
  # Latin-1's e-acute in both.
  title <- rawToChar(as.raw(c(0x80, 0x20, 0xa0, 0x20, 0xe9)))
  Encoding(title) <- "bytes"
  bytes <- minimal_pdf(info = c(Title = "XX"))
  at <- grepRaw("(XX)", bytes, fixed = TRUE)
  bytes <- c(bytes[seq_len(at)], charToRaw(title), bytes[-seq_len(at + 2L)])
  # The xref offsets after the title move by three bytes; pdfio rebuilds
  # the table when they are wrong, so the file still opens.
  pdf <- suppressWarnings(pdf_open(bytes))
  withr::defer(pdf_close(pdf))
  got <- pdf_meta(pdf)$title
  expect_identical(Encoding(got), "UTF-8")
  expect_identical(got, "• € é")
})

test_that("UTF-16 strings become UTF-8", {
  bytes <- minimal_pdf(info = c(Title = "XX"))
  utf16 <- "<FEFF00E90020263A>" # e-acute, space, white smiling face
  at <- grepRaw("(XX)", bytes, fixed = TRUE)
  bytes <- c(
    bytes[seq_len(at - 1L)],
    charToRaw(utf16),
    bytes[-seq_len(at + 3L)]
  )
  pdf <- suppressWarnings(pdf_open(bytes))
  withr::defer(pdf_close(pdf))
  expect_identical(pdf_meta(pdf)$title, "é ☺")
})

test_that("encryption and permissions are reported", {
  cases <- list(
    list("encrypted-rc4-128.pdf", NULL, "rc4-128", TRUE),
    list("encrypted-aes-128.pdf", NULL, "aes-128", TRUE),
    list("encrypted-rc4-128-pw.pdf", "user", "rc4-128", FALSE),
    list("encrypted-aes-128-pw.pdf", "user", "aes-128", FALSE)
  )
  for (cs in cases) {
    pdf <- pdf_open(fixture(cs[[1]]), password = cs[[2]])
    m <- pdf_meta(pdf)
    pdf_close(pdf)
    expect_identical(m$encryption, cs[[3]], label = cs[[1]])
    expect_identical("print" %in% m$permissions, cs[[4]], label = cs[[1]])
    expect_length(m$id, 2L)
    expect_match(m$id, "^[0-9a-f]+$")
  }
})

test_that("encrypted metadata is decrypted", {
  pdf <- pdf_open(fixture("encrypted-aes-128-pw.pdf"), password = "owner")
  withr::defer(pdf_close(pdf))
  expect_identical(pdf_meta(pdf)$title, "Encrypted with AES-128 and passwords")
})
