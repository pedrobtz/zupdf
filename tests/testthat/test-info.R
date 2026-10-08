test_that("the pinned pdfio is the one linked", {
  # Literals, because tools/ is not installed: bumping pdfio means changing
  # tools/update-pdfio's input, src/zpd_info.c and these lines together.
  info <- zupdf_info()
  expect_identical(info$pdfio_version, "1.6.5")
  expect_identical(.Call(zupdf_build_info)$pdfio_header_version, "1.6.5")
})

test_that("the patch series is the one in tools/patches", {
  expect_identical(
    zupdf_info()$patches,
    c(
      "0001-visibility-override",
      "0002-no-stdio",
      "0003-date-buffer",
      "0004-undefined-behaviour",
      "0005-unsigned-shifts",
      "0006-dict-getstring",
      "0010-ttf-callbacks"
    )
  )
})

test_that("the 1.7.0-only features are reported absent", {
  expect_true(all(
    c("lzw", "gif", "object_streams") %in% zupdf_info()$absent
  ))
})

test_that("zlib is linked and reports a version", {
  expect_match(zupdf_info()$zlib_version, "^[0-9]+\\.[0-9]+")
})

test_that("the bundled pdfio writes a file in memory", {
  expect_true(zupdf_info()$smoke_ok)
})

test_that("default limits are the design's", {
  lim <- zupdf_info()$limits
  expect_identical(lim$max_size, 1024^3)
  expect_identical(lim$max_objects, 1e6)
  expect_identical(lim$max_stream, 256 * 1024^2)
  expect_identical(lim$max_depth, 64L)
  expect_identical(lim$max_pages, 1e5)
})

test_that("zupdf_info() prints without error", {
  expect_output(print(zupdf_info()), "pdfio:       1.6.5", fixed = TRUE)
})
