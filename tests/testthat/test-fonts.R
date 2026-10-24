test_that("pdf_font_table() lists base-14 fonts as not embedded", {
  pdf <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(pdf))
  f <- pdf_font_table(pdf)
  expect_named(f, c("object", "name", "type", "embedded"))
  expect_identical(f$object, 3L)
  expect_identical(f$name, "Helvetica")
  expect_identical(f$type, "Type1")
  expect_false(f$embedded)
})

test_that("an embedded font and a Type0 font's descendant are recognised", {
  type0 <- "<< /Type /Font /Subtype /Type0 /BaseFont /ABCDEF+Test /Encoding /Identity-H /DescendantFonts [6 0 R] >>"
  cid <- "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /ABCDEF+Test /FontDescriptor 7 0 R >>"
  desc <- "<< /Type /FontDescriptor /FontName /ABCDEF+Test /FontFile2 8 0 R >>"
  bytes <- page_pdf(
    "",
    "<< /Font << /F1 5 0 R /F2 9 0 R >> >>",
    extra = list(
      type0,
      cid,
      desc,
      list(dict = "<< >>", data = as.raw(0:3)),
      helv
    )
  )
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  f <- pdf_font_table(pdf)
  # The descendant (object 6) is listed through its parent.
  expect_identical(f$object, c(5L, 9L))
  expect_identical(f$name, c("ABCDEF+Test", "Helvetica"))
  expect_identical(f$type, c("Type0", "Type1"))
  expect_identical(f$embedded, c(TRUE, FALSE))
})

test_that("pdfio's test document lists its fonts", {
  pdf <- pdf_open(fixture("testpdfio.pdf"))
  withr::defer(pdf_close(pdf))
  f <- pdf_font_table(pdf)
  expect_gt(nrow(f), 0L)
  expect_true(all(f$type %in% c("Type1", "Type3", "TrueType", "Type0")))
})

test_that("an unreadable font is a row of NA and one warning", {
  deep <- sprintf(
    "<< /Type /Font /Subtype /Type1 /BaseFont /Deep /X %s >>",
    nested_array(6L)
  )
  bytes <- page_pdf(
    "",
    "<< /Font << /F1 5 0 R /F2 6 0 R >> >>",
    extra = list(deep, helv)
  )
  pdf <- pdf_open(bytes, max_depth = 4)
  withr::defer(pdf_close(pdf))
  w <- expect_warning(f <- pdf_font_table(pdf), class = "zupdf_warning")
  expect_identical(w$object, 5L)
  expect_identical(w$count, 1L)
  expect_identical(f$object, c(5L, 6L))
  expect_identical(f$name, c(NA, "Helvetica"))
  expect_identical(f$type, c(NA, "Type1"))
  expect_identical(f$embedded, c(NA, FALSE))
})

test_that("a font's entries are looked up by their exact key", {
  # /BaseFontX must not stand in for a missing /BaseFont, as `$` would let
  # it.
  bytes <- page_pdf(
    "",
    "<< /Font << /F1 5 0 R >> >>",
    extra = list("<< /Type /Font /Subtype /Type1 /BaseFontX /Wrong >>")
  )
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  expect_identical(pdf_font_table(pdf)$name, NA_character_)
})
