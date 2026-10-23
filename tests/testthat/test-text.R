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

test_that("TD moves to the next line and sets the leading", {
  content <- "BT /F1 12 Tf 72 700 Td (a) Tj 0 -14 TD (b) Tj T* (c) Tj ET"
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  expect_identical(as.vector(text_of(bytes)), "a\nb\nc")
  expect_identical(as.vector(text_of(bytes, layout = "raw")), "a\nb\nc")
})

test_that("Tz scales the advance", {
  box <- function(content) {
    bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
    pdf_data(bytes)[[1]]$width
  }
  # Helvetica's a and b are 556 units each: 13.3 points at 12 points.
  expect_identical(box("BT /F1 12 Tf 72 700 Td (ab) Tj ET"), 13L)
  expect_identical(box("BT /F1 12 Tf 50 Tz 72 700 Td (ab) Tj ET"), 7L)
})

test_that("an operator keeps its last operands when there are too many", {
  junk <- paste(rep("5", 100), collapse = " ")
  content <- sprintf(
    "BT /F1 12 Tf 72 700 Td (a) Tj %s 0 -50 Td (b) Tj ET",
    junk
  )
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  expect_identical(as.vector(text_of(bytes)), "a\nb")
})

test_that("nested inline dictionaries carry no text", {
  content <- paste(
    "BT /F1 12 Tf 72 700 Td",
    "/P << /A << /B 1 >> /C (no) Tj >> BDC (yes) Tj EMC ET"
  )
  bytes <- page_pdf(content, sprintf("<< /Font << /F1 %s >> >>", helv))
  expect_identical(as.vector(text_of(bytes)), "yes")
})

test_that("an Identity-UCS2 font reads UTF-16 codes, surrogate pairs whole", {
  cmap <- paste(
    "/CIDInit /ProcSet findresource begin 12 dict begin begincmap",
    "/CMapName /Identity-UCS2 def",
    "1 begincodespacerange <0000> <FFFF> endcodespacerange endcmap end end"
  )
  font <- paste(
    "<< /Type /Font /Subtype /Type0 /BaseFont /Test /Encoding /Identity-H",
    "/DescendantFonts [6 0 R] /ToUnicode 7 0 R >>"
  )
  cid <- paste(
    "<< /Type /Font /Subtype /CIDFontType2 /BaseFont /Test",
    "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >>",
    "/DW 500 >>"
  )
  # A pair, A, a lone high surrogate (U+FFFD), B; then a tab, which as a
  # control code becomes a space.
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td <D83DDE000041D83D0042> Tj <004100090042> Tj ET",
    "<< /Font << /F1 5 0 R >> >>",
    extra = list(font, cid, list(dict = "<< >>", data = cmap))
  )
  t <- text_of(bytes)
  expect_identical(as.vector(t), "\U0001f600A\ufffdBA B")
  expect_identical(attr(t, "unmapped"), 0L)
  # The pair is one glyph: four glyphs of 6 points before the second Tj.
  expect_identical(pdf_data(bytes)[[1]]$x, c(72L, 108L))
})

test_that("an unmapped control code is U+FFFD, which pdftools drops", {
  # WinAnsiEncoding has no glyph for a tab: zupdf shows U+FFFD and counts
  # it, where poppler (pdftools) leaves it out and gives "ab".
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td (a\\tb) Tj ET",
    sprintf("<< /Font << /F1 %s >> >>", helv)
  )
  t <- text_of(bytes)
  expect_identical(as.vector(t), "a\ufffdb")
  expect_identical(attr(t, "unmapped"), 1L)
})

test_that("resources inherited past max_depth are a limit error", {
  # The page's resources are on the root, two /Parent steps up.
  bytes <- build_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    sprintf(
      "<< /Type /Pages /Kids [5 0 R] /Count 1 /Resources << /Font << /F1 %s >> >> >>",
      helv
    ),
    "<< /Type /Page /Parent 6 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
    list(dict = "<< >>", data = "BT /F1 12 Tf 72 700 Td (inherited) Tj ET"),
    "<< /Type /Pages /Parent 2 0 R /Kids [6 0 R] /Count 1 >>",
    "<< /Type /Pages /Parent 5 0 R /Kids [3 0 R] /Count 1 >>"
  ))
  expect_identical(as.vector(text_of(bytes, max_depth = 3)), "inherited")
  expect_zupdf_error(
    text_of(bytes, max_depth = 2),
    "zupdf_limit_error",
    limit = "max_depth",
    limit_value = 2
  )
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
  expect_identical(as.vector(t), "\u00c5\u263a\U0001f600\u00e9\ufffdF")
  # Marked UTF-8, so it reads the same in any locale.
  expect_identical(Encoding(t), "UTF-8")
  expect_identical(attr(t, "unmapped"), 1L)
})

test_that("pdf_data() reads a font name that is not UTF-8 as pdf_font_table()", {
  font <- "<< /Type /Font /Subtype /Type1 /BaseFont /#82#A0 >>"
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td (ab) Tj ET",
    "<< /Font << /F1 5 0 R >> >>",
    extra = list(font)
  )
  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  expect_identical(pdf_font_table(pdf)$name, "\u2021\u20ac")
  expect_identical(
    pdf_data(bytes, font_info = TRUE)[[1]]$font_name,
    "\u2021\u20ac"
  )
})

test_that("StandardEncoding is the default for a Type 1 font", {
  font <- "<< /Type /Font /Subtype /Type1 /BaseFont /Times-Roman >>"
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td (It\\047s \\256) Tj ET",
    sprintf("<< /Font << /F1 %s >> >>", font)
  )
  expect_identical(as.vector(text_of(bytes)), "It\u2019s \ufb01")
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
  expect_identical(as.vector(t), "Hfiabc\u263a\U0001f600\ufffd")
  expect_identical(Encoding(t), "UTF-8")
  expect_identical(attr(t, "unmapped"), 1L)
})

test_that("a simple font reads one-byte codes whatever its CMap's code space", {
  # A ToUnicode map may declare two-byte codes; a simple font's codes are
  # one byte all the same (PDF 2.0, 9.6.1).
  cmap <- paste(
    "begincmap 1 begincodespacerange <0000> <FFFF> endcodespacerange",
    "1 beginbfchar <0041> <0058> endbfchar endcmap"
  )
  font <- paste(
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica",
    "/Encoding /WinAnsiEncoding /ToUnicode 6 0 R >>"
  )
  bytes <- page_pdf(
    "BT /F1 12 Tf 72 700 Td (AB) Tj ET",
    "<< /Font << /F1 5 0 R >> >>",
    extra = list(font, list(dict = "<< >>", data = cmap))
  )
  t <- text_of(bytes)
  expect_identical(as.vector(t), "XB")
  expect_identical(attr(t, "unmapped"), 0L)
  # Each code has its own Helvetica width: A is 667, B 667 units.
  d <- pdf_data(bytes)[[1]]
  expect_identical(d$width, 16L)
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
  # A cycle, not the depth: refused at once, whatever max_depth allows.
  expect_zupdf_error(
    pdf_page_text(pdf),
    "zupdf_limit_error",
    limit = "max_depth",
    cycle = TRUE
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
    limit_value = 3,
    cycle = NULL
  )
})

test_that("numbers too large for a double do not upset the layout", {
  # A 400-digit number overflows to Inf and reads as 0; two finite but huge
  # scalings overflow the CTM to Inf and NaN, and glyph positions that are
  # not finite are placed at 0. Neither may reach the sort as NaN.
  show <- "BT /F1 12 Tf 72 700 Td (ab) Tj ET BT /F1 12 Tf 72 600 Td (cd) Tj ET"
  res <- sprintf("<< /Font << /F1 %s >> >>", helv)
  huge <- strrep("9", 400)
  big <- paste0("1", strrep("0", 200))
  cms <- c(
    overflow = sprintf("1 0 0 %s 0 0 cm", huge),
    nan = sprintf(
      "%s 0 0 %s 0 0 cm %s 0 0 %s 0 0 cm 0 0 0 0 0 0 cm",
      big,
      big,
      big,
      big
    )
  )
  # The first flattens the page onto one line; in the second every glyph
  # sits at the origin, so they make one word.
  want <- list(overflow = c("ab cd", "ab", "cd"), nan = c("abcd", "abcd"))
  for (k in names(cms)) {
    bytes <- page_pdf(paste(cms[[k]], show), res)
    expect_identical(as.vector(text_of(bytes)), want[[k]][[1]], label = k)
    d <- pdf_data(bytes)[[1]]
    expect_identical(d$text, want[[k]][-1], label = k)
    expect_false(anyNA(c(d$x, d$y, d$width, d$height)), label = k)
  }
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

test_that("max_stream bounds everything one page reads, forms counted each time", {
  # Form 5 draws form 6 ten times, which draws form 7 ten times: each
  # stream is small, but the walk reads 111 of them.
  forms <- lapply(5:7, function(k) {
    list(
      dict = sprintf(
        paste(
          "<< /Type /XObject /Subtype /Form /BBox [0 0 600 800]",
          "/Resources << /Font << /F1 %s >> /XObject << /X1 %d 0 R >> >> >>"
        ),
        helv,
        k + 1L
      ),
      data = if (k < 7) {
        strrep("/X1 Do ", 10)
      } else {
        "BT /F1 12 Tf 72 700 Td (x) Tj ET"
      }
    )
  })
  bytes <- page_pdf("/X1 Do", "<< /XObject << /X1 5 0 R >> >>", extra = forms)
  expect_identical(as.vector(text_of(bytes)), strrep("x", 100))
  expect_zupdf_error(
    text_of(bytes, max_stream = 2000),
    "zupdf_limit_error",
    limit = "max_stream",
    limit_value = 2000
  )
})

test_that("max_stream bounds a page that lists one content stream many times", {
  repeated <- function(times) {
    build_pdf(list(
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      sprintf(
        paste(
          "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]",
          "/Resources << /Font << /F1 %s >> >> /Contents [%s] >>"
        ),
        helv,
        paste(rep("4 0 R", times), collapse = " ")
      ),
      list(dict = "<< >>", data = "BT /F1 12 Tf 72 700 Td (abc) Tj ET")
    ))
  }
  expect_identical(
    as.vector(text_of(repeated(2), max_stream = 1000)),
    "abc abc"
  )
  expect_zupdf_error(
    text_of(repeated(40), max_stream = 1000),
    "zupdf_limit_error",
    limit = "max_stream"
  )
  pdf <- pdf_open(repeated(40), max_stream = 1000)
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(
    pdf_page_tokens(pdf, 1),
    "zupdf_limit_error",
    limit = "max_stream"
  )
})

test_that("max_stream counts the ToUnicode maps a page's fonts read", {
  # Twenty fonts share one ToUnicode map of about 600 bytes; each font
  # reads it once.
  cmap <- paste(
    "begincmap 1 begincodespacerange <00> <FF> endcodespacerange",
    "1 beginbfchar <61> <0062> endbfchar",
    strrep("% padding to make the map larger ", 18),
    "endcmap"
  )
  fonts <- lapply(1:20, function(i) {
    paste(
      "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica",
      "/ToUnicode 25 0 R >>"
    )
  })
  names <- sprintf("/F%d %d 0 R", 1:20, 4L + 1:20)
  content <- paste(
    "BT 72 700 Td",
    paste(sprintf("/F%d 12 Tf (a) Tj", 1:20), collapse = " "),
    "ET"
  )
  bytes <- page_pdf(
    content,
    sprintf("<< /Font << %s >> >>", paste(names, collapse = " ")),
    extra = c(fonts, list(list(dict = "<< >>", data = cmap)))
  )
  expect_identical(as.vector(text_of(bytes)), strrep("b", 20))
  expect_zupdf_error(
    text_of(bytes, max_stream = 5000),
    "zupdf_limit_error",
    limit = "max_stream"
  )
})

test_that("a font given as a direct dictionary is loaded once per page", {
  # Each Tf of a direct dictionary used to load the font, and its ToUnicode
  # map, again; now it is read once, so the page fits in max_stream.
  cmap <- paste(
    "begincmap 1 begincodespacerange <00> <FF> endcodespacerange",
    "1 beginbfchar <61> <0062> endbfchar",
    strrep("% padding ", 20),
    "endcmap"
  )
  font <- paste(
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica",
    "/ToUnicode 5 0 R >>"
  )
  content <- paste(
    "BT 72 700 Td",
    strrep("/F1 12 Tf (a) Tj ", 100),
    "ET"
  )
  bytes <- page_pdf(
    content,
    sprintf("<< /Font << /F1 %s >> >>", font),
    extra = list(list(dict = "<< >>", data = cmap))
  )
  expect_identical(
    as.vector(text_of(bytes, max_stream = 3000)),
    strrep("b", 100)
  )
})

test_that("pdfio's own test document reads in full", {
  pdf <- pdf_open(fixture("testpdfio.pdf"))
  withr::defer(pdf_close(pdf))
  t <- pdf_page_text(pdf)
  expect_identical(attr(t, "unmapped"), rep(0L, 4))
  # Pinned exactly: the MD5 of each page's UTF-8 text everywhere, and the
  # text itself in _snaps/text.md where snapshots run. pdftools gives the
  # same words (the conformance job).
  expect_identical(
    vapply(
      as.vector(t),
      function(x) bytes_md5(charToRaw(x)),
      "",
      USE.NAMES = FALSE
    ),
    c(
      "ee0190d0a187b8861e1821100da4ad87",
      "c0663566545ea7b655e07a403d1ebd1d",
      "a5300402376582dcfd4b55ec4493f9c3",
      "ed7d5c2f06fb815d4fc82feccbe38d73"
    )
  )
  expect_snapshot(writeLines(t))
})

test_that("an R graphics device's text is read, rotated labels whole", {
  pdf <- pdf_open(fixture("grdevices.pdf"))
  withr::defer(pdf_close(pdf))
  # pdftools has the same words; it puts the rotated y-axis labels on the
  # lines they cross, where zupdf keeps them as one run.
  expect_identical(
    as.vector(pdf_page_text(pdf)),
    "grDevices::pdf()\n1:10\n2 4 6 8 10\n2 4 6 8 10\nIndex"
  )
})

test_that("encrypted text is decrypted", {
  pdf <- pdf_open(fixture("encrypted-rc4-128-pw.pdf"), password = "user")
  withr::defer(pdf_close(pdf))
  expect_identical(
    as.vector(pdf_page_text(pdf)),
    "Encrypted with RC4-128 and passwords"
  )
})

test_that("every afl-input case's text extracts as pinned", {
  pins <- corpus_pins()
  for (f in afl_files()) {
    pdf <- suppressWarnings(pdf_open(f))
    withr::defer(pdf_close(pdf))
    text <- suppressWarnings(pdf_page_text(pdf))
    expect_length(text, length(pdf))
    expect_identical(
      bytes_md5(charToRaw(enc2utf8(paste(text, collapse = "\f")))),
      pins$text[pins$file == basename(f)],
      label = basename(f)
    )
  }
})

test_that("a page is read without reading the others", {
  # Structural, not a timing: page 2's content is a Flate bomb past
  # max_stream and page 3's a reference to no object, so reading either
  # page 1 or page 4 reads only that page.
  bomb <- flate(charToRaw(strrep(" ", 1e5)))
  page <- function(contents) {
    sprintf(
      paste(
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]",
        "/Resources << /Font << /F1 %s >> >> /Contents %s >>"
      ),
      helv,
      contents
    )
  }
  bytes <- build_pdf(list(
    "<< /Type /Catalog /Pages 2 0 R >>",
    "<< /Type /Pages /Kids [3 0 R 4 0 R 5 0 R 6 0 R] /Count 4 >>",
    page("7 0 R"),
    page("8 0 R"),
    page("99 0 R"),
    page("7 0 R"),
    list(dict = "<< >>", data = "BT /F1 12 Tf 72 700 Td (page) Tj ET"),
    list(dict = "<< /Filter /FlateDecode >>", data = bomb)
  ))
  pdf <- pdf_open(bytes, max_stream = 1000)
  withr::defer(pdf_close(pdf))
  expect_identical(
    as.vector(pdf_page_text(pdf, pages = c(1, 4))),
    c("page", "page")
  )
  expect_identical(nrow(pdf_page_tokens(pdf, 4)), 10L)
  expect_zupdf_error(
    pdf_page_text(pdf, pages = 2),
    "zupdf_limit_error",
    limit = "max_stream"
  )
  expect_identical(
    as.vector(suppressWarnings(pdf_page_text(pdf, pages = 3))),
    ""
  )
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

test_that("the lexer decodes escapes, continuations, names and comments", {
  content <- paste0(
    "(a\\tb\\bc\\fd\\ne\\rf\\\\g\\(h\\)i\\101\\7j(k)l) ",
    "/A#20B % a comment\n",
    "(m\\\nn) (o\\\r\np) <41 4>"
  )
  pdf <- pdf_open(page_pdf(content))
  withr::defer(pdf_close(pdf))
  tk <- pdf_page_tokens(pdf, 1)
  expect_identical(tk$type, c("string", "name", "string", "string", "string"))
  expect_identical(
    tk$value,
    c("a\tb\bc\fd\ne\rf\\g(h)iA\aj(k)l", "A B", "mn", "op", "A@")
  )
})

test_that("an inline image without EI runs to the end of the content", {
  pdf <- pdf_open(page_pdf("BI /W 1 /H 1 ID xyz"))
  withr::defer(pdf_close(pdf))
  tk <- pdf_page_tokens(pdf, 1)
  expect_identical(tail(tk$type, 2), c("operator", "inline_image"))
  # The data, and the space zupdf puts after each content stream.
  expect_identical(tail(tk$value, 1), "4 bytes")
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
