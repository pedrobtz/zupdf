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

# ---- unusual and malformed images ---------------------------------------------

test_that("an image mask has no colour space and is refused as native", {
  bytes <- page_pdf(
    "q 2 0 0 2 0 0 cm /Im1 Do Q",
    "<< /XObject << /Im1 5 0 R >> >>",
    extra = list(list(
      dict = "<< /Type /XObject /Subtype /Image /Width 2 /Height 2 /ImageMask true >>",
      data = as.raw(c(0x80, 0x40))
    ))
  )
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  im <- pdf_page_images(pdf, 1)
  expect_identical(im$color_space, NA_character_)
  expect_identical(im$bits, NA_integer_)
  expect_identical(as.vector(pdf_image(pdf, 5)), as.raw(c(0x80, 0x40)))
  expect_zupdf_error(
    pdf_image(pdf, 5, as = "native"),
    "zupdf_unsupported_input"
  )
})

test_that("an ICCBased image converts by its number of components", {
  icc_pdf <- function(n, data) {
    page_pdf(
      "",
      "<< /XObject << /Im1 5 0 R >> >>",
      extra = list(
        list(
          dict = "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace [/ICCBased 6 0 R] /BitsPerComponent 8 >>",
          data = data
        ),
        list(dict = sprintf("<< /N %s >>", n), data = as.raw(0))
      )
    )
  }
  rgb <- pdf_open(icc_pdf("3", as.raw(c(255, 0, 0, 0, 0, 255))))
  withr::defer(pdf_close(rgb))
  expect_identical(pdf_page_images(rgb, 1)$color_space, "ICCBased")
  nr <- pdf_image(rgb, 5, as = "native")
  expect_identical(dim(nr), c(1L, 2L))
  # 0xAABBGGRR as a signed int: opaque red is 0xFF0000FF.
  expect_identical(nr[[1]], bitwOr(-16777216L, 255L))

  grey <- pdf_open(icc_pdf("1", as.raw(c(0, 128))))
  withr::defer(pdf_close(grey))
  g <- pdf_image(grey, 5, as = "native")
  expect_identical(dim(g), c(1L, 2L))
  expect_identical(bitwAnd(g[[2]], 255L), 128L)

  # Four components (CMYK) are not converted.
  cmyk <- pdf_open(icc_pdf("4", as.raw(1:8)))
  withr::defer(pdf_close(cmyk))
  expect_zupdf_error(
    pdf_image(cmyk, 5, as = "native"),
    "zupdf_unsupported_input"
  )
})

test_that("1-bit and Indexed images read raw and are refused as native", {
  image <- function(cs, bits, data) {
    page_pdf(
      "",
      "<< /XObject << /Im1 5 0 R >> >>",
      extra = list(list(
        dict = sprintf(
          "<< /Type /XObject /Subtype /Image /Width 2 /Height 1 /ColorSpace %s /BitsPerComponent %d >>",
          cs,
          bits
        ),
        data = data
      ))
    )
  }
  one_bit <- pdf_open(image("/DeviceGray", 1L, as.raw(0x80)))
  withr::defer(pdf_close(one_bit))
  expect_identical(pdf_page_images(one_bit, 1)$bits, 1L)
  expect_identical(as.vector(pdf_image(one_bit, 5)), as.raw(0x80))
  expect_zupdf_error(
    pdf_image(one_bit, 5, as = "native"),
    "zupdf_unsupported_input"
  )

  indexed <- pdf_open(
    image("[/Indexed /DeviceRGB 1 <ff000000ff00>]", 8L, as.raw(c(0, 1)))
  )
  withr::defer(pdf_close(indexed))
  expect_identical(pdf_page_images(indexed, 1)$color_space, "Indexed")
  expect_identical(as.vector(pdf_image(indexed, 5)), as.raw(c(0, 1)))
  expect_zupdf_error(
    pdf_image(indexed, 5, as = "native"),
    "zupdf_unsupported_input"
  )
})

test_that("an image's size and depth are followed through references", {
  bytes <- page_pdf(
    "",
    "<< /XObject << /Im1 5 0 R >> >>",
    extra = list(
      list(
        dict = "<< /Type /XObject /Subtype /Image /Width 6 0 R /Height 7 0 R /ColorSpace /DeviceGray /BitsPerComponent 8 0 R >>",
        data = as.raw(c(0, 128, 255))
      ),
      "3",
      "1",
      "8"
    )
  )
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  im <- pdf_page_images(pdf, 1)
  expect_identical(c(im$width, im$height, im$bits), c(3L, 1L, 8L))
  expect_identical(dim(pdf_image(pdf, 5, as = "native")), c(1L, 3L))
})

test_that("an unreadable image is a row of NA and one warning", {
  image <- function(extra) {
    list(
      dict = sprintf(
        "<< /Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8 %s >>",
        extra
      ),
      data = as.raw(1)
    )
  }
  bytes <- page_pdf(
    "",
    "<< /XObject << /Im1 5 0 R /Im2 6 0 R >> >>",
    extra = list(
      image(paste("/Deep", nested_array(6L))),
      image("")
    )
  )
  pdf <- pdf_open(bytes, max_depth = 4)
  withr::defer(pdf_close(pdf))
  w <- expect_warning(im <- pdf_page_images(pdf, 1), class = "zupdf_warning")
  expect_identical(w$object, 5L)
  expect_identical(w$count, 1L)
  expect_identical(im$object, c(5L, 6L))
  expect_identical(im$width, c(NA, 1L))
  expect_identical(im$color_space, c(NA, "DeviceGray"))
})

test_that("every image in the afl-input corpus reads or is refused by class", {
  for (f in afl_files()) {
    pdf <- tryCatch(
      suppressWarnings(pdf_open(f)),
      zupdf_error = function(e) NULL
    )
    if (is.null(pdf)) {
      next
    }
    for (i in seq_len(length(pdf))) {
      im <- tryCatch(
        suppressWarnings(pdf_page_images(pdf, i)),
        zupdf_error = function(e) NULL
      )
      expect_true(is.null(im) || is.data.frame(im))
    }
    objs <- suppressWarnings(pdf_objects(pdf))
    for (n in objs$number[objs$subtype %in% "Image"]) {
      for (as in c("raw", "native")) {
        res <- tryCatch(
          suppressWarnings(pdf_image(pdf, n, as = as)),
          zupdf_error = function(e) "refused"
        )
        expect_true(
          is.raw(res) || inherits(res, "nativeRaster") || res == "refused"
        )
      }
    }
    pdf_close(pdf)
  }
})

# ---- round trips through png and jpeg (roadmap Stage 3) -----------------------

test_that("a written PNG image reads back as png::readPNG() reads the file", {
  skip_if_not_installed("png")
  png_file <- fixture("pdfio-color.png")
  bytes <- written(function(page) {
    img <- pdf_image_new(page$writer, png_file)
    pdf_draw_image(page, img, 0, 0, 100, 100)
  })
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  x <- pdf_image(pdf, pdf_page_images(pdf, 1)$object)
  ref <- png::readPNG(png_file)
  expect_identical(c(attr(x, "height"), attr(x, "width")), dim(ref)[1:2])
  expect_identical(
    as.vector(x),
    as.raw(round(aperm(ref, c(3L, 2L, 1L)) * 255))
  )
})

test_that("a written JPEG image reads back as its file, for jpeg::readJPEG()", {
  skip_if_not_installed("jpeg")
  jpg_file <- fixture("color.jpg")
  bytes <- written(function(page) {
    img <- pdf_image_new(page$writer, jpg_file)
    pdf_draw_image(page, img, 0, 0, 100, 100)
  })
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  x <- pdf_image(pdf, pdf_page_images(pdf, 1)$object)
  expect_false(attr(x, "decoded"))
  expect_identical(as.vector(x), readBin(jpg_file, "raw", file.size(jpg_file)))
  expect_identical(
    dim(jpeg::readJPEG(as.vector(x))),
    c(attr(x, "height"), attr(x, "width"), 3L)
  )
})
