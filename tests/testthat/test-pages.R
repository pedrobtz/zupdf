test_that("pdf_pages() has one row per page with the design's columns", {
  pdf <- pdf_open(minimal_pdf(pages = 3L))
  withr::defer(pdf_close(pdf))
  p <- pdf_pages(pdf)
  expect_s3_class(p, "data.frame")
  expect_named(
    p,
    c("page", "width", "height", "rotate", "media_box", "crop_box", "streams")
  )
  expect_identical(p$page, 1:3)
  expect_identical(p$width, rep(612, 3))
  expect_identical(p$height, rep(792, 3))
  expect_identical(p$rotate, rep(0L, 3))
  expect_identical(p$media_box[[2]], c(0, 0, 612, 792))
  expect_identical(p$crop_box, p$media_box)
  expect_identical(p$streams, rep(1L, 3))
})

test_that("boxes and rotation are inherited from the page tree", {
  pdf <- pdf_open(minimal_pdf(
    pages = 2L,
    media_box = c(0, 0, 595, 842),
    crop_box = c(10, 20, 500, 800),
    rotate = 90,
    inherit = TRUE
  ))
  withr::defer(pdf_close(pdf))
  p <- pdf_pages(pdf)
  expect_identical(p$media_box[[1]], c(0, 0, 595, 842))
  expect_identical(p$crop_box[[2]], c(10, 20, 500, 800))
  expect_identical(p$width, c(490, 490))
  expect_identical(p$height, c(780, 780))
  expect_identical(p$rotate, c(90L, 90L))
})

test_that("rotation is normalised to 0, 90, 180 or 270", {
  for (r in list(c(-90, 270), c(450, 90), c(180, 180), c(360, 0))) {
    pdf <- pdf_open(minimal_pdf(rotate = r[[1]]))
    expect_identical(pdf_pages(pdf)$rotate, as.integer(r[[2]]))
    pdf_close(pdf)
  }
})

test_that("the crop box is clipped to the media box", {
  pdf <- pdf_open(minimal_pdf(
    media_box = c(0, 0, 100, 100),
    crop_box = c(-10, 50, 200, 90)
  ))
  withr::defer(pdf_close(pdf))
  expect_identical(pdf_pages(pdf)$crop_box[[1]], c(0, 50, 100, 90))
})

test_that("a box with its corners swapped is normalised", {
  pdf <- pdf_open(minimal_pdf(media_box = c(612, 792, 0, 0)))
  withr::defer(pdf_close(pdf))
  expect_identical(pdf_pages(pdf)$media_box[[1]], c(0, 0, 612, 792))
})

test_that("a missing or malformed media box is NA", {
  for (mb in list(NULL, c(0, 0, 612))) {
    pdf <- pdf_open(minimal_pdf(media_box = mb))
    p <- pdf_pages(pdf)
    pdf_close(pdf)
    expect_true(all(is.na(p$media_box[[1]])))
    expect_true(is.na(p$width))
  }
})

test_that("an inherited attribute deeper than max_depth is a limit error", {
  # Each page's /Parent is the root, whose /Parent is itself: an attribute
  # absent everywhere sends the walk round the cycle until max_depth.
  bytes <- minimal_pdf(media_box = NULL, tree_extra = " /Parent 2 0 R")
  pdf <- pdf_open(bytes, max_depth = 5)
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(
    pdf_pages(pdf),
    "zupdf_limit_error",
    limit = "max_depth",
    limit_value = 5
  )
})

test_that("pdfio's own test document reads", {
  pdf <- pdf_open(fixture("testpdfio.pdf"))
  withr::defer(pdf_close(pdf))
  p <- pdf_pages(pdf)
  expect_identical(nrow(p), length(pdf))
  expect_false(anyNA(p$width))
})
