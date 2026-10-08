test_that("pdf_objects() lists every object with type, subtype and length", {
  pdf <- pdf_open(minimal_pdf(text = c("a", "b"), info = c(Title = "T")))
  withr::defer(pdf_close(pdf))
  o <- pdf_objects(pdf)
  expect_named(o, c("number", "generation", "type", "subtype", "length"))
  expect_identical(o$number, 1:8)
  expect_identical(o$generation, rep(0L, 8))
  expect_identical(o$type[1:4], c("Catalog", "Pages", "Font", "Page"))
  expect_identical(o$subtype[[3]], "Type1")
  # Content streams are objects 5 and 7; the rest have no stream.
  expect_identical(!is.na(o$length), c(rep(FALSE, 4), TRUE, FALSE, TRUE, FALSE))
  expect_identical(o$length[[5]], nchar("BT /F1 12 Tf 72 720 Td (a) Tj ET"))
})

test_that("pdf_object() reads a dictionary with references and names", {
  pdf <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(pdf))
  cat <- pdf_object(pdf, 1)
  expect_identical(names(cat), c("Pages", "Type"))
  expect_s3_class(cat$Type, "pdf_name")
  expect_identical(unclass(cat$Type), "Catalog")
  expect_s3_class(cat$Pages, "pdf_ref")
  expect_identical(as.integer(unclass(cat$Pages)), 2L)
  expect_identical(attr(cat$Pages, "generation"), 0L)
  expect_identical(format(cat$Pages), "2 0 R")
  expect_identical(format(cat$Type), "/Catalog")
})

test_that("pdf_object() reads an object that is not a dictionary", {
  pdf <- pdf_open(stream_pdf(raw(), value = "[1 2.5 (s) /N true null]"))
  withr::defer(pdf_close(pdf))
  v <- pdf_object(pdf, 5)
  expect_identical(v[[1]], 1L)
  expect_identical(v[[2]], 2.5)
  expect_identical(v[[3]], "s")
  expect_identical(unclass(v[[4]]), "N")
  expect_true(v[[5]])
  expect_null(v[[6]])
})

test_that("an unknown object number or a bad n is an invalid argument", {
  pdf <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(pdf_object(pdf, 99), "zupdf_invalid_argument", arg = "n")
  for (bad in list(0, -1, 1.5, NA, "1", c(1, 2), Inf)) {
    expect_zupdf_error(
      pdf_object(pdf, bad),
      "zupdf_invalid_argument",
      arg = "n"
    )
  }
})

test_that("pdf_object() bounds nesting by max_depth", {
  pdf <- pdf_open(stream_pdf(raw(), value = nested_array(10)), max_depth = 5)
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(
    pdf_object(pdf, 5),
    "zupdf_limit_error",
    limit = "max_depth",
    limit_value = 5
  )
  pdf2 <- pdf_open(stream_pdf(raw(), value = nested_array(10)), max_depth = 10)
  withr::defer(pdf_close(pdf2))
  expect_type(pdf_object(pdf2, 5), "list")
})

# ---- streams ----------------------------------------------------------------

test_that("pdf_stream() returns a content stream's bytes", {
  pdf <- pdf_open(minimal_pdf(text = "Hello"))
  withr::defer(pdf_close(pdf))
  s <- pdf_stream(pdf, 5)
  expect_identical(
    rawToChar(as.vector(s)),
    "BT /F1 12 Tf 72 720 Td (Hello) Tj ET"
  )
  expect_true(attr(s, "decoded"))
  expect_identical(attr(s, "filter"), character())
})

test_that("pdf_stream() decodes FlateDecode, or returns it as stored", {
  data <- charToRaw(strrep("zupdf ", 100))
  pdf <- pdf_open(stream_pdf(flate(data), "/Filter /FlateDecode"))
  withr::defer(pdf_close(pdf))
  s <- pdf_stream(pdf, 4)
  expect_identical(as.vector(s), data)
  expect_true(attr(s, "decoded"))
  expect_identical(attr(s, "filter"), "FlateDecode")
  stored <- pdf_stream(pdf, 4, decode = FALSE)
  expect_identical(as.vector(stored), flate(data))
  expect_false(attr(stored, "decoded"))
})

test_that("a filter pdfio cannot decode comes back as stored", {
  for (f in c("DCTDecode", "ASCIIHexDecode")) {
    data <- as.raw(c(0xff, 0xd8, 0xff, 0x00, 0x41))
    pdf <- pdf_open(stream_pdf(data, paste0("/Filter /", f)))
    s <- pdf_stream(pdf, 4)
    pdf_close(pdf)
    expect_identical(as.vector(s), data, label = f)
    expect_false(attr(s, "decoded"))
    expect_identical(attr(s, "filter"), f)
  }
})

test_that("a filter array is reported in order", {
  data <- as.raw(1:4)
  pdf <- pdf_open(stream_pdf(data, "/Filter [/ASCII85Decode /DCTDecode]"))
  withr::defer(pdf_close(pdf))
  s <- pdf_stream(pdf, 4)
  expect_identical(attr(s, "filter"), c("ASCII85Decode", "DCTDecode"))
  expect_false(attr(s, "decoded"))
})

test_that("an object without a stream is refused", {
  pdf <- pdf_open(minimal_pdf())
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(pdf_stream(pdf, 1), "zupdf_invalid_argument", arg = "n")
  expect_zupdf_error(pdf_stream(pdf, 99), "zupdf_invalid_argument", arg = "n")
  expect_zupdf_error(
    pdf_stream(pdf, 5, decode = NA),
    "zupdf_invalid_argument",
    arg = "decode"
  )
})

test_that("max_stream stops a Flate bomb", {
  # 16 MiB of zeros compress to about 16 KiB.
  bomb <- flate(raw(16 * 1024^2))
  expect_lt(length(bomb), 100000)
  pdf <- pdf_open(stream_pdf(bomb, "/Filter /FlateDecode"), max_stream = 1e6)
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(
    pdf_stream(pdf, 4),
    "zupdf_limit_error",
    limit = "max_stream",
    limit_value = 1e6
  )
  # The stored bytes are within the limit.
  expect_length(pdf_stream(pdf, 4, decode = FALSE), length(bomb))
})

test_that("the default max_stream stops a large Flate bomb", {
  skip_heavy()
  bomb <- flate(raw(300 * 1024^2))
  pdf <- pdf_open(stream_pdf(bomb, "/Filter /FlateDecode"))
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(
    pdf_stream(pdf, 4),
    "zupdf_limit_error",
    limit = "max_stream"
  )
})

test_that("every afl-input case lists its objects", {
  for (f in afl_files()) {
    pdf <- suppressWarnings(pdf_open(f))
    o <- suppressWarnings(pdf_objects(pdf))
    pdf_close(pdf)
    expect_s3_class(o, "data.frame")
  }
})
