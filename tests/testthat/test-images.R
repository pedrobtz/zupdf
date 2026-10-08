test_that("pdf_page_images() lists a page's images", {
  rgb <- as.raw(c(255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255))
  pdf <- pdf_open(image_pdf(flate(rgb), 2, 2, filter = "/Filter /FlateDecode"))
  withr::defer(pdf_close(pdf))
  im <- pdf_page_images(pdf, 1)
  expect_named(
    im,
    c("object", "name", "width", "height", "bits", "color_space", "filter")
  )
  expect_identical(im$object, 5L)
  expect_identical(im$name, "Im1")
  expect_identical(c(im$width, im$height, im$bits), c(2L, 2L, 8L))
  expect_identical(im$color_space, "DeviceRGB")
  expect_identical(im$filter, "FlateDecode")
})

test_that("a page without images lists none", {
  pdf <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(pdf))
  im <- pdf_page_images(pdf, 1)
  expect_identical(nrow(im), 0L)
  expect_named(
    im,
    c("object", "name", "width", "height", "bits", "color_space", "filter")
  )
})

test_that("pdf_image() returns decoded samples with their attributes", {
  rgb <- as.raw(c(255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255))
  pdf <- pdf_open(image_pdf(flate(rgb), 2, 2, filter = "/Filter /FlateDecode"))
  withr::defer(pdf_close(pdf))
  x <- pdf_image(pdf, 5)
  expect_identical(as.vector(x), rgb)
  expect_identical(attr(x, "width"), 2L)
  expect_identical(attr(x, "color_space"), "DeviceRGB")
  expect_true(attr(x, "decoded"))
})

test_that("pdf_image(as = \"native\") packs RGB and grey pixels", {
  rgb <- as.raw(c(255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 255))
  pdf <- pdf_open(image_pdf(rgb, 2, 2))
  withr::defer(pdf_close(pdf))
  nr <- pdf_image(pdf, 5, as = "native")
  expect_s3_class(nr, "nativeRaster")
  expect_identical(dim(nr), c(2L, 2L))
  # 0xAABBGGRR as a signed int: opaque red is 0xFF0000FF.
  expect_identical(nr[[1]], bitwOr(-16777216L, 255L))

  gray <- as.raw(c(0, 128, 255))
  pdf2 <- pdf_open(image_pdf(gray, 3, 1, cs = "/DeviceGray"))
  withr::defer(pdf_close(pdf2))
  g <- pdf_image(pdf2, 5, as = "native")
  expect_identical(dim(g), c(1L, 3L))
  expect_identical(bitwAnd(g[[2]], 255L), 128L)
})

test_that("a JPEG image comes back as its JPEG bytes", {
  pdf <- pdf_open(fixture("testpdfio.pdf"))
  withr::defer(pdf_close(pdf))
  im <- pdf_page_images(pdf, 1)
  jpeg <- im$object[im$filter == "DCTDecode"][[1]]
  x <- pdf_image(pdf, jpeg)
  expect_identical(as.vector(x)[1:2], as.raw(c(0xff, 0xd8)))
  expect_identical(attr(x, "filter"), "DCTDecode")
  expect_zupdf_error(
    pdf_image(pdf, jpeg, as = "native"),
    "zupdf_unsupported_input"
  )
})

test_that("pdf_image() refuses an object that is not an image", {
  pdf <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(pdf_image(pdf, 1), "zupdf_invalid_argument", arg = "n")
  expect_zupdf_error(
    pdf_image(pdf, 3, as = "x"),
    "zupdf_invalid_argument",
    arg = "as"
  )
})

test_that("an image with fewer samples than its size says is refused", {
  pdf <- pdf_open(image_pdf(as.raw(1:3), 2, 2))
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(pdf_image(pdf, 5, as = "native"), "zupdf_parse_error")
})
