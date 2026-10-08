test_that("pdf_page_text() reads minimal_pdf() pages", {
  pdf <- pdf_open(minimal_pdf(text = c("Hello", "World (2)")))
  withr::defer(pdf_close(pdf))
  t <- pdf_page_text(pdf)
  expect_identical(as.vector(t), c("Hello", "World (2)"))
  expect_identical(attr(t, "unmapped"), c(0L, 0L))
  expect_identical(as.vector(pdf_page_text(pdf, pages = 2)), "World (2)")
  expect_identical(
    as.vector(pdf_page_text(pdf, layout = "raw")),
    c("Hello", "World (2)")
  )
})

test_that("pages and layout are checked", {
  pdf <- pdf_open(minimal_pdf(pages = 2L))
  withr::defer(pdf_close(pdf))
  for (bad in list(0, 3, 1.5, NA, "1", integer())) {
    expect_zupdf_error(
      pdf_page_text(pdf, pages = bad),
      "zupdf_invalid_argument",
      arg = "pages"
    )
  }
  expect_zupdf_error(
    pdf_page_text(pdf, layout = "x"),
    "zupdf_invalid_argument",
    arg = "layout"
  )
  expect_length(pdf_page_text(pdf, pages = c(2, 1, 2)), 3L)
})

test_that("reading order is top to bottom whatever the stream order", {
  content <- paste(
    "BT /F1 12 Tf 72 600 Td (second) Tj ET",
    "BT /F1 12 Tf 72 700 Td (first) Tj ET",
    "BT /F1 12 Tf 200 700 Td (right) Tj ET"
  )
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  expect_identical(as.vector(text_of(bytes)), "first right\nsecond")
  expect_identical(
    as.vector(text_of(bytes, layout = "raw")),
    "second\nfirst\nright"
  )
})

test_that("TJ kerning gaps become spaces and small ones do not", {
  content <- "BT /F1 12 Tf 72 700 Td [(Hel) -20 (lo) -900 (World)] TJ ET"
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  expect_identical(as.vector(text_of(bytes)), "Hello World")
  expect_identical(as.vector(text_of(bytes, layout = "raw")), "Hello World")
})

test_that("T*, ' and \" start new lines", {
  content <- paste(
    "BT /F1 12 Tf 14 TL 72 700 Td (one) Tj T* (two) Tj (three) '",
    "2 0 (four) \" ET"
  )
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  expect_identical(as.vector(text_of(bytes)), "one\ntwo\nthree\nfour")
})

test_that("Differences and glyph names map simple-font codes", {
  font <- paste(
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica",
    "/Encoding << /Type /Encoding /BaseEncoding /WinAnsiEncoding",
    "/Differences [65 /Aring /uni263A /u1F600 /eacute.sc /g123] >> >>"
  )
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td (ABCDEF) Tj ET",
    sprintf("<< /Font << /F1 %s >> >>", font)
  )
  t <- text_of(bytes)
  expect_identical(as.vector(t), "Å☺\U0001f600é�F")
  expect_identical(attr(t, "unmapped"), 1L)
})

test_that("StandardEncoding is the default for a Type 1 font", {
  font <- "<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >>"
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td (It\\047s \\256) Tj ET",
    sprintf("<< /Font << /F1 %s >> >>", font)
  )
  expect_identical(as.vector(text_of(bytes)), "It’s ﬁ")
})

test_that("a Type0 font maps two-byte codes through its ToUnicode CMap", {
  cmap <- paste(
    "/CIDInit /ProcSet findresource begin 12 dict begin begincmap",
    "1 begincodespacerange <0000> <FFFF> endcodespacerange",
    "2 beginbfchar <0001> <0048> <0002> <00660069> endbfchar",
    "2 beginbfrange <0010> <0012> <0061> <0020> <0021> [<263A> <D83DDE00>] endbfrange",
    "endcmap end end"
  )
  font <- paste(
    "<< /Type /Font /Subtype /Type0 /BaseFont /Test /Encoding /Identity-H",
    "/DescendantFonts [6 0 R] /ToUnicode 7 0 R >>"
  )
  cid <- paste(
    "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Test",
    "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >>",
    "/DW 500 /W [1 [600 700] 16 18 400] >>"
  )
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td <0001000200100011001200200021> Tj <0099> Tj ET",
    "<< /Font << /F1 5 0 R >> >>",
    extra = list(font, cid, list(dict = "<< >>", data = cmap))
  )
  t <- text_of(bytes)
  expect_identical(as.vector(t), "Hfiabc☺\U0001f600�")
  expect_identical(attr(t, "unmapped"), 1L)
})

test_that("text in a Form XObject is found, under its matrix", {
  form <- list(
    dict = paste(
      "<< /Type /XObject /Subtype /Form /BBox [0 0 600 800]",
      "/Matrix [1 0 0 1 0 -200]",
      sprintf("/Resources << /Font << /F1 %s >> >> >>", helv)
    ),
    data = "BT /F1 12 Tf 72 700 Td (in the form) Tj ET"
  )
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td (on the page) Tj ET /X1 Do",
    sprintf("<< /Font << /F1 %s >> /XObject << /X1 5 0 R >> >>", helv),
    extra = list(form)
  )
  expect_identical(as.vector(text_of(bytes)), "on the page\nin the form")
})

test_that("a form drawn inside itself is a limit error", {
  form <- list(
    dict = paste(
      "<< /Type /XObject /Subtype /Form /BBox [0 0 600 800]",
      "/Resources << /XObject << /X1 5 0 R >> >> >>"
    ),
    data = "/X1 Do"
  )
  bytes <- page_pdf(
    "/X1 Do",
    "<< /XObject << /X1 5 0 R >> >>",
    extra = list(form)
  )
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(
    pdf_page_text(pdf),
    "zupdf_limit_error",
    limit = "max_depth"
  )
})

test_that("forms nested deeper than max_depth are a limit error", {
  # Forms 5, 6, 7 each draw the next; 8 shows text.
  forms <- lapply(5:8, function(k) {
    list(
      dict = sprintf(
        paste(
          "<< /Type /XObject /Subtype /Form /BBox [0 0 600 800]",
          "/Resources << /Font << /F1 %s >> /XObject << /X1 %d 0 R >> >> >>"
        ),
        helv,
        k + 1L
      ),
      data = if (k < 8) "/X1 Do" else "BT /F1 12 Tf 72 700 Td (deep) Tj ET"
    )
  })
  bytes <- page_pdf("/X1 Do", "<< /XObject << /X1 5 0 R >> >>", extra = forms)
  expect_identical(as.vector(text_of(bytes, max_depth = 4)), "deep")
  expect_zupdf_error(
    text_of(bytes, max_depth = 3),
    "zupdf_limit_error",
    limit = "max_depth",
    limit_value = 3
  )
})

test_that("inline image data does not leak into the text", {
  image <- as.raw(c(0x28, 0x45, 0x49, 0x00, 0xff, 0x29, 0x5b))
  content <- c(
    charToRaw(
      "BT /F1 12 Tf 72 700 Td (before) Tj ET\nBI /W 2 /H 1 /BPC 8 /CS /G ID "
    ),
    image,
    charToRaw(" EI\nBT /F1 12 Tf 72 600 Td (after) Tj ET")
  )
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  expect_identical(as.vector(text_of(bytes)), "before\nafter")
})

test_that("rotated text stays whole", {
  content <- "BT /F1 12 Tf 0 1 -1 0 100 300 Tm (Up the page) Tj ET"
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  expect_identical(as.vector(text_of(bytes)), "Up the page")
})

test_that("a FlateDecode content stream is read", {
  content <- flate(charToRaw("BT /F1 12 Tf 72 700 Td (compressed) Tj ET"))
  bytes <- build_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    sprintf(
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 %s >> >> /Contents 4 0 R >>",
      helv
    ),
    list(dict = "<< /Filter /FlateDecode >>", data = content)
  ))
  expect_identical(as.vector(text_of(bytes)), "compressed")
})

test_that("a content stream larger than max_stream is a limit error", {
  bytes <- minimal_pdf(text = strrep("x", 200))
  expect_zupdf_error(
    text_of(bytes, max_stream = 100),
    "zupdf_limit_error",
    limit = "max_stream"
  )
})

test_that("pdfio's own test document reads in full", {
  pdf <- pdf_open(fixture("testpdfio.pdf"))
  withr::defer(pdf_close(pdf))
  t <- pdf_page_text(pdf)
  expect_length(t, 4L)
  expect_match(
    t[[1]],
    "^Lorem ipsum dolor sit amet, consectetur adipiscing\nelit\\."
  )
  expect_identical(attr(t, "unmapped"), rep(0L, 4))
})

test_that("an R graphics device's text is read, rotated labels whole", {
  pdf <- pdf_open(fixture("grdevices.pdf"))
  withr::defer(pdf_close(pdf))
  t <- pdf_page_text(pdf)
  expect_match(t, "grDevices::pdf()", fixed = TRUE)
  expect_match(t, "1:10", fixed = TRUE)
  expect_match(t, "Index", fixed = TRUE)
})

test_that("encrypted text is decrypted", {
  pdf <- pdf_open(fixture("encrypted-rc4-128-pw.pdf"), password = "user")
  withr::defer(pdf_close(pdf))
  expect_identical(
    as.vector(pdf_page_text(pdf)),
    "Encrypted with RC4-128 and passwords"
  )
})

test_that("every afl-input page's text extracts or is refused cleanly", {
  for (f in afl_files()) {
    res <- tryCatch(
      suppressWarnings({
        pdf <- pdf_open(f)
        on.exit(pdf_close(pdf), add = TRUE)
        pdf_page_text(pdf)
      }),
      zupdf_error = function(e) "refused"
    )
    expect_type(res, "character")
  }
})

test_that("a page of 2,000 is read without reading the others", {
  skip_heavy()
  bytes <- minimal_pdf(text = sprintf("page %d", 1:2000))
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  t <- system.time(x <- pdf_page_text(pdf, pages = 1500))
  expect_identical(as.vector(x), "page 1500")
  expect_lt(t[["elapsed"]], 1)
})

# ---- tokens -----------------------------------------------------------------

test_that("pdf_page_tokens() lists the content stream's tokens", {
  content <- "BT /F1 12 Tf [(a) -5 <4142>] TJ << /K 1 >> BDC ET"
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  tk <- pdf_page_tokens(pdf, 1)
  expect_named(tk, c("type", "value"))
  expect_identical(
    tk$type,
    c(
      "operator",
      "name",
      "number",
      "operator",
      "array_open",
      "string",
      "number",
      "string",
      "array_close",
      "operator",
      "dict_open",
      "name",
      "number",
      "dict_close",
      "operator",
      "operator"
    )
  )
  expect_identical(tk$value[c(2, 3, 6, 8)], c("F1", "12", "a", "AB"))
  expect_zupdf_error(
    pdf_page_tokens(pdf, 2),
    "zupdf_invalid_argument",
    arg = "i"
  )
})

test_that("an inline image is one token with its size", {
  content <- c(
    charToRaw("BI /W 1 /H 1 ID "),
    as.raw(c(0, 1, 2)),
    charToRaw(" EI Q")
  )
  pdf <- pdf_open(page_pdf(content))
  withr::defer(pdf_close(pdf))
  tk <- pdf_page_tokens(pdf, 1)
  expect_identical(tail(tk$type, 3), c("operator", "inline_image", "operator"))
  expect_identical(tail(tk$value, 2), c("3 bytes", "Q"))
})
