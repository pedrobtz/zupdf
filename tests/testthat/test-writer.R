test_that("a written file reopens with its pages and text", {
  bytes <- written(
    function(page) pdf_draw_text(page, 72, 700, "Hello, writer."),
    pages = 3L
  )
  expect_identical(rawToChar(bytes[1:8]), "%PDF-2.0")
  text <- reread(bytes)
  expect_identical(as.vector(text), rep("Hello, writer.", 3))
  pages <- reread(bytes, pdf_pages)
  expect_identical(pages$width, rep(595.28, 3))
})

test_that("another reader accepts the file", {
  skip_if_not_installed("pdftools")
  bytes <- written(function(page) {
    pdf_draw_text(page, 72, 700, "Readable elsewhere")
  })
  expect_text_equal(pdftools::pdf_text(bytes), "Readable elsewhere")
})

test_that("deterministic = TRUE gives the same bytes every time", {
  draw <- function(page) {
    pdf_draw_text(page, 72, 700, "Same bytes", font = "Times-Roman", size = 14)
    pdf_draw(page, list(x = c(72, 200), y = c(650, 650)), stroke = "red")
  }
  a <- written(draw)
  b <- written(draw)
  expect_identical(a, b)
  m <- reread(a, pdf_meta)
  expect_identical(
    format(m$created, "%Y-%m-%d %H:%M:%S"),
    "2024-01-02 03:04:05"
  )
  expect_length(m$id, 2L)
  # A different page gives a different identifier.
  c2 <- written(function(page) pdf_draw_text(page, 72, 700, "Other bytes"))
  expect_false(identical(reread(c2, pdf_meta)$id, m$id))
})

test_that("without deterministic, the identifier is random", {
  a <- written(deterministic = FALSE)
  b <- written(deterministic = FALSE)
  expect_false(identical(reread(a, pdf_meta)$id, reread(b, pdf_meta)$id))
})

test_that("pinned bytes match where this zlib has a recorded hash", {
  # Flate output differs between zlib builds (zlib-ng, Apple's), so the
  # pin is per zlib version (design section 7).
  hashes <- utils::read.delim(
    fixture("hashes.tsv"),
    colClasses = "character",
    comment.char = "#"
  )
  zlib <- zupdf_info()$zlib_version
  row <- hashes[hashes$case == "hello" & hashes$zlib == zlib, ]
  skip_if(nrow(row) == 0L, paste("no pinned hash for zlib", zlib))
  bytes <- written(function(page) pdf_draw_text(page, 72, 700, "Hello"))
  expect_pdf_bytes(bytes, row$md5[[1]])
})

test_that("pdf_save() writes to a path and to a connection", {
  path <- withr::local_tempfile(fileext = ".pdf")
  w <- pdf_new()
  pdf_page_end(pdf_page_new(w))
  expect_identical(pdf_save(w, path), path)
  expect_identical(reread(path, length), 1L)

  w2 <- pdf_new()
  pdf_page_end(pdf_page_new(w2))
  path2 <- withr::local_tempfile(fileext = ".pdf")
  con <- file(path2)
  pdf_save(w2, con)
  expect_identical(reread(path2, length), 1L)
})

test_that("a saved writer, an ended page and an open page are refused", {
  w <- pdf_new()
  page <- pdf_page_new(w)
  expect_zupdf_error(pdf_save(w), "zupdf_write_error")
  pdf_page_end(page)
  expect_zupdf_error(pdf_draw_text(page, 1, 1, "x"), "zupdf_write_error")
  expect_zupdf_error(pdf_page_end(page), "zupdf_write_error")
  pdf_save(w)
  expect_zupdf_error(pdf_save(w), "zupdf_write_error")
  expect_zupdf_error(pdf_page_new(w), "zupdf_write_error")
  expect_zupdf_error(pdf_font(w, "Helvetica"), "zupdf_write_error")
  expect_output(print(w), "(saved)", fixed = TRUE)
})

test_that("an abandoned writer and page are finalized without harm", {
  local({
    w <- pdf_new()
    page <- pdf_page_new(w)
    pdf_draw_text(page, 1, 1, "never written")
  })
  gc()
  expect_true(TRUE)
})

test_that("page boxes and extra dictionary entries are written", {
  w <- pdf_new(media_box = pdf_paper("letter"))
  p1 <- pdf_page_new(w)
  pdf_page_end(p1)
  p2 <- pdf_page_new(
    w,
    media_box = pdf_paper("a5"),
    crop_box = c(10, 10, 400, 500),
    dict = list(Rotate = 90L, UserUnit = 1L)
  )
  pdf_page_end(p2)
  pages <- reread(pdf_save(w), pdf_pages)
  expect_identical(pages$media_box[[1]], c(0, 0, 612, 792))
  expect_identical(pages$media_box[[2]], pdf_paper("a5"))
  expect_identical(pages$crop_box[[2]], c(10, 10, 400, 500))
  expect_identical(pages$rotate, c(0L, 90L))
})

test_that("pages are written in the order they end", {
  w <- pdf_new()
  a <- pdf_page_new(w)
  b <- pdf_page_new(w)
  pdf_draw_text(a, 72, 700, "first opened")
  pdf_draw_text(b, 72, 700, "first ended")
  pdf_page_end(b)
  pdf_page_end(a)
  expect_identical(
    as.vector(reread(pdf_save(w))),
    c("first ended", "first opened")
  )
})

test_that("pdf_new() and pdf_page_new() check their arguments", {
  expect_zupdf_error(
    pdf_new(version = "3"),
    "zupdf_invalid_argument",
    arg = "version"
  )
  expect_zupdf_error(
    pdf_new(media_box = c(0, 0, -1, 5)),
    "zupdf_invalid_argument",
    arg = "media_box"
  )
  expect_zupdf_error(
    pdf_new(created = "now"),
    "zupdf_invalid_argument",
    arg = "created"
  )
  expect_zupdf_error(
    pdf_new(deterministic = NA),
    "zupdf_invalid_argument",
    arg = "deterministic"
  )
  expect_zupdf_error(pdf_new(oops = 1), "zupdf_invalid_argument", arg = "...")
  w <- pdf_new()
  expect_zupdf_error(
    pdf_page_new(w, dict = list(1)),
    "zupdf_invalid_argument",
    arg = "dict"
  )
  expect_zupdf_error(
    pdf_page_new(w, dict = list(A = NA)),
    "zupdf_invalid_argument",
    arg = "dict"
  )
})

test_that("pdf_paper() gives ISO and US sizes", {
  expect_identical(pdf_paper("a4"), c(0, 0, 595.28, 841.89))
  expect_identical(pdf_paper("A5"), c(0, 0, 419.53, 595.28))
  expect_identical(pdf_paper("b5"), c(0, 0, 498.9, 708.66))
  expect_identical(pdf_paper("letter", landscape = TRUE), c(0, 0, 792, 612))
  expect_zupdf_error(pdf_paper("a11"), "zupdf_invalid_argument", arg = "name")
  expect_zupdf_error(pdf_paper("a4", landscape = NA), "zupdf_invalid_argument")
})
