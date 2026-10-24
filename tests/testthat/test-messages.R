# The wording of one representative error per class and status, pinned in
# _snaps/messages.md. Other tests assert classes and fields, never the
# message; these say what a user reads, so a change to it is seen.

test_that("argument and handle errors read well", {
  pdf <- pdf_open(minimal_pdf())
  expect_snapshot(error = TRUE, pdf_page_text(pdf, pages = 3))
  pdf_close(pdf)
  expect_snapshot(error = TRUE, pdf_page_text(pdf))
})

test_that("errors from pdfio read well", {
  expect_snapshot(error = TRUE, pdf_open(charToRaw("not a pdf at all")))
  expect_snapshot(
    error = TRUE,
    pdf_open(fixture("encrypted-rc4-128-pw.pdf"), password = "wrong")
  )
  expect_snapshot(error = TRUE, pdf_open("no-such-file.pdf"))
})

test_that("limit errors read well", {
  expect_snapshot(error = TRUE, pdf_open(minimal_pdf(), max_size = 10))
  bomb <- stream_pdf(flate(raw(1e5)), "/Filter /FlateDecode")
  pdf <- pdf_open(bomb, max_stream = 1000)
  withr::defer(pdf_close(pdf))
  expect_snapshot(error = TRUE, pdf_stream(pdf, 4))
  expect_snapshot(
    error = TRUE,
    text_of(minimal_pdf(text = strrep("x", 200)), max_stream = 100)
  )
  deep <- page_pdf(
    "/X1 Do",
    "<< /XObject << /X1 5 0 R >> >>",
    extra = list(
      list(
        dict = "<< /Type /XObject /Subtype /Form /BBox [0 0 1 1] /Resources << /XObject << /X1 6 0 R >> >> >>",
        data = "/X1 Do"
      ),
      list(
        dict = "<< /Type /XObject /Subtype /Form /BBox [0 0 1 1] >>",
        data = ""
      )
    )
  )
  expect_snapshot(error = TRUE, text_of(deep, max_depth = 1))
  cycle <- page_pdf(
    "/X1 Do",
    "<< /XObject << /X1 5 0 R >> >>",
    extra = list(list(
      dict = "<< /Type /XObject /Subtype /Form /BBox [0 0 1 1] /Resources << /XObject << /X1 5 0 R >> >> >>",
      data = "/X1 Do"
    ))
  )
  expect_snapshot(error = TRUE, text_of(cycle))
})

test_that("unsupported input and writer errors read well", {
  pdf <- pdf_open(fixture("testpdfio.pdf"))
  withr::defer(pdf_close(pdf))
  im <- pdf_page_images(pdf, 1)
  jpeg <- im$object[im$filter == "DCTDecode"][[1]]
  expect_snapshot(error = TRUE, pdf_image(pdf, jpeg, as = "native"))

  w <- pdf_new()
  not_font <- withr::local_tempfile(fileext = ".ttf")
  writeBin(charToRaw("not a font"), not_font)
  expect_snapshot(error = TRUE, pdf_font(w, not_font))
  pdf_save(w)
  expect_snapshot(error = TRUE, pdf_page_new(w))
})
