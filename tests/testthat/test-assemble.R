test_that("pdf_copy_pages() copies pages in order, with their text", {
  a <- pdf_open(minimal_pdf(text = c("a1", "a2", "a3")))
  b <- pdf_open(fixture("testpdfio.pdf"))
  withr::defer({
    pdf_close(a)
    pdf_close(b)
  })
  w <- pdf_new()
  pdf_copy_pages(w, a, pages = c(3, 1))
  pdf_copy_pages(w, b, pages = 1)
  pdf_copy_pages(w, a)
  out <- pdf_open(pdf_save(w))
  withr::defer(pdf_close(out))
  t <- pdf_page_text(out)
  expect_identical(length(t), 6L)
  expect_identical(
    as.vector(t[c(1, 2, 4, 5, 6)]),
    c("a3", "a1", "a1", "a2", "a3")
  )
  expect_match(t[[3]], "^Lorem ipsum")
})

test_that("rotation is added to each copied page's own", {
  src <- pdf_open(minimal_pdf(pages = 2L, rotate = 90, inherit = TRUE))
  withr::defer(pdf_close(src))
  w <- pdf_new()
  pdf_copy_pages(w, src, rotate = 90)
  pdf_copy_pages(w, src, pages = 1, rotate = -90)
  pdf_copy_pages(w, src, pages = 1)
  out <- pdf_open(pdf_save(w))
  withr::defer(pdf_close(out))
  expect_identical(pdf_pages(out)$rotate, c(180L, 180L, 0L, 90L))
})

test_that("inherited boxes are carried onto the copy", {
  src <- pdf_open(minimal_pdf(media_box = c(0, 0, 300, 400), inherit = TRUE))
  withr::defer(pdf_close(src))
  w <- pdf_new()
  pdf_copy_pages(w, src)
  out <- pdf_open(pdf_save(w))
  withr::defer(pdf_close(out))
  expect_identical(pdf_pages(out)$media_box[[1]], c(0, 0, 300, 400))
})

test_that("pages copied from an encrypted file are readable", {
  src <- pdf_open(fixture("encrypted-aes-128-pw.pdf"), password = "user")
  withr::defer(pdf_close(src))
  w <- pdf_new()
  pdf_copy_pages(w, src)
  out <- pdf_open(pdf_save(w))
  withr::defer(pdf_close(out))
  expect_identical(pdf_meta(out)$encryption, "none")
  expect_identical(
    as.vector(pdf_page_text(out)),
    "Encrypted with AES-128 and passwords"
  )
})

test_that("pdf_copy_pages() checks its arguments", {
  src <- pdf_open(minimal_pdf(pages = 2L))
  w <- pdf_new()
  expect_zupdf_error(
    pdf_copy_pages(w, src, pages = 3),
    "zupdf_invalid_argument",
    arg = "pages"
  )
  expect_zupdf_error(
    pdf_copy_pages(w, src, rotate = 45),
    "zupdf_invalid_argument",
    arg = "rotate"
  )
  pdf_close(src)
  expect_zupdf_error(
    pdf_copy_pages(w, src),
    "zupdf_invalid_argument",
    arg = "pdf"
  )
})

# ---- metadata ---------------------------------------------------------------

test_that("pdf_set_meta() writes text every reader decodes", {
  w <- pdf_new()
  when <- as.POSIXct("2025-05-06 07:08:09", tz = "UTC")
  pdf_set_meta(
    w,
    title = "Zürich ☺",
    author = "An author",
    subject = "S",
    keywords = "k1, k2",
    creator = "tests",
    language = "de-CH",
    modified = when
  )
  pdf_page_end(pdf_page_new(w))
  bytes <- pdf_save(w)
  m <- reread(bytes, pdf_meta)
  expect_identical(m$title, "Zürich ☺")
  expect_identical(m$author, "An author")
  expect_identical(m$subject, "S")
  expect_identical(m$keywords, "k1, k2")
  expect_identical(m$creator, "tests")
  expect_identical(m$language, "de-CH")
  expect_identical(m$modified, when)
  skip_if_not_installed("pdftools")
  expect_identical(pdftools::pdf_info(bytes)$keys$Title, "Zürich ☺")
})

test_that("in PDF 2.0 the information goes to XMP metadata", {
  w <- pdf_new(version = "2.0")
  pdf_set_meta(w, title = "Zürich")
  pdf_page_end(pdf_page_new(w))
  bytes <- pdf_save(w)
  expect_match(pdf_info(bytes)$metadata, "Zürich", fixed = TRUE)
})

test_that("pdf_set_meta() checks its arguments", {
  w <- pdf_new()
  expect_zupdf_error(
    pdf_set_meta(w, colour = "red"),
    "zupdf_invalid_argument",
    arg = "..."
  )
  expect_zupdf_error(
    pdf_set_meta(w, "untitled"),
    "zupdf_invalid_argument",
    arg = "..."
  )
  expect_zupdf_error(
    pdf_set_meta(w, title = 1),
    "zupdf_invalid_argument",
    arg = "title"
  )
  expect_zupdf_error(
    pdf_set_meta(w, modified = "now"),
    "zupdf_invalid_argument",
    arg = "modified"
  )
})

# ---- encryption ---------------------------------------------------------------

test_that("each method encrypts with user and owner passwords", {
  for (method in c("aes128", "rc4128")) {
    w <- pdf_new()
    pdf_set_encryption(
      w,
      user = "u",
      owner = "o",
      method = method,
      permissions = c("print", "copy")
    )
    page <- pdf_page_new(w)
    pdf_draw_text(page, 72, 700, paste("Secret", method))
    pdf_page_end(page)
    bytes <- pdf_save(w)
    expect_zupdf_error(pdf_open(bytes), "zupdf_password_error")
    expect_zupdf_error(pdf_open(bytes, password = "x"), "zupdf_password_error")
    for (pw in c("u", "o")) {
      pdf <- pdf_open(bytes, password = pw)
      m <- pdf_meta(pdf)
      t <- pdf_page_text(pdf)
      pdf_close(pdf)
      expect_identical(
        m$encryption,
        c(aes128 = "aes-128", rc4128 = "rc4-128")[[method]]
      )
      expect_setequal(m$permissions, c("print", "copy"))
      expect_identical(as.vector(t), paste("Secret", method))
    }
  }
})

test_that("without a user password the file opens and keeps its permissions", {
  w <- pdf_new()
  pdf_set_encryption(w, permissions = character())
  pdf_page_end(pdf_page_new(w))
  m <- reread(pdf_save(w), pdf_meta)
  expect_identical(m$encryption, "aes-128")
  expect_identical(m$permissions, character())
})

test_that("encryption comes first, and deterministic files stay readable", {
  w <- pdf_new()
  pdf_page_end(pdf_page_new(w))
  expect_zupdf_error(pdf_set_encryption(w, user = "u"), "zupdf_write_error")

  # The key comes from the identifier, so deterministic = TRUE leaves the
  # identifier alone once encryption is on.
  w2 <- pdf_new(deterministic = TRUE)
  pdf_set_encryption(w2, user = "u")
  page <- pdf_page_new(w2)
  pdf_draw_text(page, 72, 700, "still readable")
  pdf_page_end(page)
  pdf <- pdf_open(pdf_save(w2), password = "u")
  withr::defer(pdf_close(pdf))
  expect_identical(as.vector(pdf_page_text(pdf)), "still readable")
})

test_that("pdf_set_encryption() checks its arguments", {
  w <- pdf_new()
  expect_zupdf_error(
    pdf_set_encryption(w, method = "aes256"),
    "zupdf_invalid_argument",
    arg = "method"
  )
  expect_zupdf_error(
    pdf_set_encryption(w, permissions = "fly"),
    "zupdf_invalid_argument",
    arg = "permissions"
  )
  expect_zupdf_error(
    pdf_set_encryption(w, user = 1),
    "zupdf_invalid_argument",
    arg = "user"
  )
})

test_that("an encrypted file opens in another reader", {
  skip_if_not_installed("pdftools")
  w <- pdf_new()
  pdf_set_encryption(w, user = "u")
  page <- pdf_page_new(w)
  pdf_draw_text(page, 72, 700, "Hello")
  pdf_page_end(page)
  expect_text_equal(pdftools::pdf_text(pdf_save(w), upw = "u"), "Hello")
})
