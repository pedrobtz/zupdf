# Design section 5.1: pdftools's and qpdf's names, formals and shapes.

test_that("the wrappers have exactly pdftools's and qpdf's formals", {
  skip_if_not_installed("pdftools")
  skip_if_not_installed("qpdf")
  for (f in compat_pdftools) {
    expect_identical(
      formals(getExportedValue("zupdf", f)),
      formals(getExportedValue("pdftools", f)),
      label = f
    )
  }
  for (f in compat_qpdf) {
    expect_identical(
      formals(getExportedValue("zupdf", f)),
      formals(getExportedValue("qpdf", f)),
      label = f
    )
  }
})

test_that("no stub is defined for what zupdf cannot do", {
  exports <- getNamespaceExports("zupdf")
  for (f in c(
    "pdf_render_page",
    "pdf_convert",
    "pdf_ocr_text",
    "pdf_ocr_data",
    "poppler_config",
    "pdf_compress",
    "pdf_overlay_stamp"
  )) {
    expect_false(f %in% exports, label = f)
  }
})

test_that("pdf_info() has pdftools's fields and values", {
  path <- minimal_pdf(
    pages = 2L,
    info = c(Title = "T", Author = "A"),
    path = withr::local_tempfile(fileext = ".pdf")
  )
  x <- pdf_info(path)
  expect_named(
    x,
    c(
      "version",
      "pages",
      "encrypted",
      "linearized",
      "keys",
      "created",
      "modified",
      "metadata",
      "locked",
      "attachments",
      "layout"
    )
  )
  expect_identical(x$pages, 2L)
  expect_identical(x$keys, list(Author = "A", Title = "T"))
  expect_false(x$encrypted)
  expect_identical(x$layout, "no_layout")
  expect_s3_class(x$created, "POSIXct")
  skip_if_not_installed("pdftools")
  y <- pdftools::pdf_info(path)
  for (f in c(
    "version",
    "pages",
    "encrypted",
    "linearized",
    "metadata",
    "locked",
    "attachments",
    "layout"
  )) {
    expect_identical(x[[f]], y[[f]], label = f)
  }
  expect_identical(x$keys[order(names(x$keys))], y$keys[order(names(y$keys))])
})

test_that("pdf_info() reads the layout, XMP metadata and encryption", {
  w <- pdf_new(version = "2.0")
  pdf_set_encryption(w, permissions = "print")
  pdf_set_meta(w, title = "Meta")
  pdf_page_end(pdf_page_new(w))
  bytes <- pdf_save(w)
  x <- pdf_info(bytes)
  expect_true(x$encrypted)
  expect_match(x$metadata, "Meta", fixed = TRUE)
})

test_that("pdf_text() matches pdftools on simple pages, with its line ends", {
  path <- minimal_pdf(
    text = c("Hello", "World"),
    path = withr::local_tempfile(fileext = ".pdf")
  )
  expect_identical(pdf_text(path), c("Hello\n", "World\n"))
  expect_identical(pdf_text(path, raw = TRUE), c("Hello\n", "World\n"))
  skip_if_not_installed("pdftools")
  expect_identical(pdf_text(path), pdftools::pdf_text(path))
})

test_that("pdf_text() and pdf_info() take passwords as pdftools does", {
  f <- fixture("encrypted-aes-128-pw.pdf")
  expect_zupdf_error(pdf_text(f), "zupdf_password_error")
  expect_identical(
    pdf_text(f, upw = "user"),
    "Encrypted with AES-128 and passwords\n"
  )
  expect_identical(
    pdf_text(f, opw = "owner"),
    "Encrypted with AES-128 and passwords\n"
  )
})

test_that("the readers take an open pdf_file and leave it open", {
  pdf <- pdf_open(minimal_pdf(text = "x"))
  withr::defer(pdf_close(pdf))
  expect_identical(pdf_text(pdf), "x\n")
  expect_identical(pdf_info(pdf)$pages, 1L)
  expect_identical(length(pdf), 1L)
})

test_that("pdf_fonts() and pdf_pagesize() have pdftools's columns and types", {
  path <- fixture("testpdfio.pdf")
  f <- pdf_fonts(path)
  expect_s3_class(f, "tbl_df")
  expect_named(f, c("name", "type", "embedded", "file"))
  expect_true(all(f$type == "type3"))
  expect_true(all(f$embedded))
  s <- pdf_pagesize(path)
  expect_named(s, c("top", "right", "bottom", "left", "width", "height"))
  skip_if_not_installed("pdftools")
  p <- pdftools::pdf_fonts(path)
  expect_identical(f$type, p$type)
  expect_identical(f$embedded, p$embedded)
  expect_identical(s, pdftools::pdf_pagesize(path))
})

test_that("pdf_toc() and pdf_attachments() are empty lists when there are none", {
  path <- minimal_pdf(path = withr::local_tempfile(fileext = ".pdf"))
  expect_identical(pdf_toc(path), list())
  expect_identical(pdf_attachments(path), list())
})

test_that("pdf_toc() walks the outline tree", {
  objs <- list(
    "<< /Type /Catalog /Pages 2 0 R /Outlines 5 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
    list(dict = "<< >>", data = ""),
    "<< /Type /Outlines /First 6 0 R /Last 7 0 R /Count 2 >>",
    "<< /Title (Chapter 1) /Parent 5 0 R /Next 7 0 R /First 8 0 R /Last 8 0 R >>",
    "<< /Title (Chapter 2) /Parent 5 0 R /Prev 6 0 R >>",
    "<< /Title (Section 1.1) /Parent 6 0 R >>"
  )
  path <- withr::local_tempfile(fileext = ".pdf")
  writeBin(build_pdf(objs), path)
  toc <- pdf_toc(path)
  expect_identical(toc$title, "")
  expect_true(toc$is_open)
  expect_identical(
    vapply(toc$children, `[[`, "", "title"),
    c("Chapter 1", "Chapter 2")
  )
  expect_identical(toc$children[[1]]$children[[1]]$title, "Section 1.1")
  skip_if_not_installed("pdftools")
  expect_identical(toc, pdftools::pdf_toc(path))
})

test_that("an outline that loops on itself ends", {
  objs <- list(
    "<< /Type /Catalog /Pages 2 0 R /Outlines 5 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
    list(dict = "<< >>", data = ""),
    "<< /Type /Outlines /First 6 0 R >>",
    "<< /Title (Loop) /Next 6 0 R /First 6 0 R >>"
  )
  toc <- pdf_toc(build_pdf(objs))
  expect_length(toc$children, 1L)
})

test_that("pdf_attachments() returns embedded files", {
  objs <- list(
    "<< /Type /Catalog /Pages 2 0 R /Names << /EmbeddedFiles << /Names [(a.txt) 5 0 R] >> >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
    list(dict = "<< >>", data = ""),
    "<< /Type /Filespec /F (a.txt) /Desc (A note) /EF << /F 6 0 R >> >>",
    list(
      dict = "<< /Type /EmbeddedFile /Subtype /text#2Fplain >>",
      data = "attached"
    )
  )
  att <- pdf_attachments(build_pdf(objs))
  expect_length(att, 1L)
  expect_named(
    att[[1]],
    c("name", "mime", "created", "modified", "description", "data")
  )
  expect_identical(att[[1]]$name, "a.txt")
  expect_identical(att[[1]]$mime, "text/plain")
  expect_identical(att[[1]]$description, "A note")
  expect_identical(rawToChar(att[[1]]$data), "attached")
  expect_true(pdf_info(build_pdf(objs))$attachments)
})

# ---- qpdf --------------------------------------------------------------------

test_that("pdf_split() writes one file per page with qpdf's names", {
  dir <- withr::local_tempdir()
  path <- minimal_pdf(text = c("a", "b", "c"), path = file.path(dir, "doc.pdf"))
  out <- pdf_split(path)
  expect_identical(basename(out), c("doc_1.pdf", "doc_2.pdf", "doc_3.pdf"))
  expect_identical(
    vapply(out, pdf_text, ""),
    c("a\n", "b\n", "c\n"),
    ignore_attr = TRUE
  )
  expect_identical(
    basename(pdf_split(path, output = file.path(dir, "part"))),
    sprintf("part_%d.pdf", 1:3)
  )
})

test_that("pdf_subset() keeps the pages chosen, as R indexes", {
  dir <- withr::local_tempdir()
  path <- minimal_pdf(text = c("a", "b", "c"), path = file.path(dir, "doc.pdf"))
  out <- pdf_subset(path, pages = c(3, 1))
  expect_identical(basename(out), "doc_output.pdf")
  expect_identical(pdf_text(out), c("c\n", "a\n"))
  expect_identical(pdf_text(pdf_subset(path, pages = -2)), c("a\n", "c\n"))
  expect_zupdf_error(
    pdf_subset(path, pages = 9),
    "zupdf_invalid_argument",
    arg = "pages"
  )
})

test_that("pdf_combine() concatenates files, named after the first", {
  dir <- withr::local_tempdir()
  a <- minimal_pdf(text = c("a1", "a2"), path = file.path(dir, "a.pdf"))
  b <- minimal_pdf(text = "b1", path = file.path(dir, "b.pdf"))
  out <- pdf_combine(c(a, b))
  expect_identical(basename(out), "a_combined.pdf")
  expect_identical(pdf_length(out), 3L)
  expect_identical(pdf_text(out), c("a1\n", "a2\n", "b1\n"))
})

test_that("pdf_rotate_pages() sets or adds rotation on the pages chosen", {
  dir <- withr::local_tempdir()
  path <- minimal_pdf(pages = 3L, rotate = 90, path = file.path(dir, "doc.pdf"))
  rot <- function(f) {
    p <- pdf_open(f)
    on.exit(pdf_close(p))
    pdf_pages(p)$rotate
  }
  expect_identical(
    rot(pdf_rotate_pages(path, pages = 2, angle = 180)),
    c(90L, 180L, 90L)
  )
  expect_identical(
    rot(pdf_rotate_pages(path, pages = 1:2, angle = 90, relative = TRUE)),
    c(180L, 180L, 90L)
  )
  expect_zupdf_error(
    pdf_rotate_pages(path, pages = 1, angle = 45),
    "zupdf_invalid_argument",
    arg = "angle"
  )
})

test_that("pdf_length() counts pages, with a password", {
  expect_identical(
    pdf_length(fixture("encrypted-rc4-128-pw.pdf"), password = "user"),
    1L
  )
  expect_zupdf_error(
    pdf_length(c("a", "b")),
    "zupdf_invalid_argument",
    arg = "input"
  )
})

test_that("the copies open in qpdf too", {
  skip_if_not_installed("qpdf")
  dir <- withr::local_tempdir()
  path <- minimal_pdf(text = c("a", "b"), path = file.path(dir, "doc.pdf"))
  out <- pdf_combine(c(path, path), output = file.path(dir, "both.pdf"))
  expect_identical(qpdf::pdf_length(out), 4L)
})

test_that("pdf_data() gives words with pdftools's columns and boxes", {
  path <- minimal_pdf(
    text = c("Hello from zupdf.", "Two"),
    path = withr::local_tempfile(fileext = ".pdf")
  )
  d <- pdf_data(path)
  expect_length(d, 2L)
  expect_s3_class(d[[1]], "tbl_df")
  expect_named(d[[1]], c("width", "height", "x", "y", "space", "text"))
  expect_identical(d[[1]]$text, c("Hello", "from", "zupdf."))
  expect_identical(d[[1]]$space, c(TRUE, TRUE, FALSE))
  expect_identical(d[[1]]$x[[1]], 72L)
  # Helvetica 12 at baseline 720 on a 792-point page: top 792 - 720 - 8.6.
  expect_identical(d[[1]]$y[[1]], 63L)
  f <- pdf_data(path, font_info = TRUE)[[2]]
  expect_identical(f$font_name, "Helvetica")
  expect_identical(f$font_size, 12)
  skip_if_not_installed("pdftools")
  p <- pdftools::pdf_data(path)
  expect_identical(d[[1]]$text, p[[1]]$text)
  expect_identical(d[[1]]$x, p[[1]]$x, tolerance = 2)
  expect_lte(max(abs(d[[1]]$y - p[[1]]$y)), 1L)
})

test_that("pdf_data() keeps a rotated word whole, and an empty page is empty", {
  rotated <- page_pdf(
    "BT /F1 12 Tf 0 1 -1 0 100 300 Tm (Upward) Tj ET",
    sprintf("<< /Font << /F1 %s >> >>", helv)
  )
  d <- pdf_data(rotated)[[1]]
  expect_identical(d$text, "Upward")
  expect_gt(d$height, d$width)
  empty <- pdf_data(minimal_pdf())[[1]]
  expect_identical(nrow(empty), 0L)
  expect_named(empty, c("width", "height", "x", "y", "space", "text"))
})

test_that("pdf_data() leaves out a glyph placed by non-finite numbers", {
  g <- list(
    text = c("A", "B"),
    x0 = c(NaN, 72),
    y0 = c(720, 720),
    x1 = c(80, 80),
    y1 = c(720, 720),
    size = c(12, 12),
    ascent = c(0.7, 0.7),
    descent = c(-0.2, -0.2),
    font = c("Helvetica", "Helvetica")
  )
  d <- zpd_words(g, 792, FALSE)
  expect_identical(d$text, "B")
  g$x0[[1]] <- 72
  g$size[[1]] <- Inf
  expect_identical(zpd_words(g, 792, TRUE)$text, "B")
})

# ---- values per case, pinned from pdftools 3.9.0 -------------------------------

test_that("pdf_fonts() reports poppler's type for each font and font file", {
  objs <- list()
  add <- function(x) {
    objs[[length(objs) + 1L]] <<- x
    4L + length(objs)
  }
  # A font descriptor with a font file under `key`, of subtype `sub`.
  desc <- function(key, sub = "") {
    f <- add(list(dict = sprintf("<< %s >>", sub), data = as.raw(0:3)))
    add(sprintf(
      "<< /Type /FontDescriptor /FontName /X /%s %d 0 R >>",
      key,
      f
    ))
  }
  fd <- function(d) {
    if (is.null(d)) "" else sprintf(" /FontDescriptor %d 0 R", d)
  }
  simple <- function(name, subtype, d = NULL) {
    add(sprintf(
      "<< /Type /Font /Subtype /%s /BaseFont /%s%s >>",
      subtype,
      name,
      fd(d)
    ))
  }
  type0 <- function(name, cid, d = NULL) {
    k <- add(sprintf(
      "<< /Type /Font /Subtype /CIDFontType%d /BaseFont /%s%s >>",
      cid,
      name,
      fd(d)
    ))
    add(sprintf(
      "<< /Type /Font /Subtype /Type0 /BaseFont /%s /Encoding /Identity-H /DescendantFonts [%d 0 R] >>",
      name,
      k
    ))
  }
  fonts <- c(
    simple("T1", "Type1"),
    simple("T1File", "Type1", desc("FontFile")),
    simple("T1File3", "Type1", desc("FontFile3")),
    simple("T1C", "Type1", desc("FontFile3", "/Subtype /Type1C")),
    simple("T1OT", "Type1", desc("FontFile3", "/Subtype /OpenType")),
    simple("MM", "MMType1"),
    simple("TT", "TrueType"),
    simple("TTFile2", "TrueType", desc("FontFile2")),
    simple("TTCFF", "TrueType", desc("FontFile3", "/Subtype /Type1C")),
    simple("TTOT", "TrueType", desc("FontFile3", "/Subtype /OpenType")),
    simple("Odd", "Foo"),
    type0("CID2", 2L),
    type0("CID0", 0L),
    type0("CID0File2", 0L, desc("FontFile2")),
    type0("CID0File3", 0L, desc("FontFile3")),
    type0("CID0C", 0L, desc("FontFile3", "/Subtype /CIDFontType0C")),
    type0("CID2CFF", 2L, desc("FontFile3", "/Subtype /Type1C")),
    type0("CID2OT", 2L, desc("FontFile3", "/Subtype /OpenType"))
  )
  res <- sprintf(
    "<< /Font << %s >> >>",
    paste(sprintf("/F%d %d 0 R", fonts, fonts), collapse = " ")
  )
  path <- withr::local_tempfile(fileext = ".pdf")
  writeBin(page_pdf("", res, extra = objs), path)
  f <- pdf_fonts(path)
  expected <- data.frame(
    name = c(
      "T1",
      "T1File",
      "T1File3",
      "T1C",
      "T1OT",
      "MM",
      "TT",
      "TTFile2",
      "TTCFF",
      "TTOT",
      "Odd",
      "CID2",
      "CID0",
      "CID0File2",
      "CID0File3",
      "CID0C",
      "CID2CFF",
      "CID2OT"
    ),
    type = c(
      "type1",
      "type1",
      "type1",
      "type1c",
      "type1c_ot",
      "type1",
      "truetype",
      "truetype",
      "type1c",
      "truetype_ot",
      "unknown",
      "cid_truetype",
      "cid_type0",
      "cid_truetype",
      "cid_type0",
      "cid_type0c",
      "cid_type0c",
      "cid_truetype_ot"
    ),
    embedded = c(
      FALSE,
      TRUE,
      TRUE,
      TRUE,
      TRUE,
      FALSE,
      FALSE,
      TRUE,
      TRUE,
      TRUE,
      FALSE,
      FALSE,
      FALSE,
      TRUE,
      TRUE,
      TRUE,
      TRUE,
      TRUE
    )
  )
  expect_identical(f$name, expected$name)
  expect_identical(f$type, expected$type)
  expect_identical(f$embedded, expected$embedded)
  expect_identical(f$file, ifelse(expected$embedded, "", NA_character_))
  skip_if_not_installed("pdftools")
  p <- suppressMessages(pdftools::pdf_fonts(path))
  p <- p[match(f$name, p$name), ]
  expect_identical(p$type, f$type)
  expect_identical(p$embedded, f$embedded)
})

test_that("pdf_fonts() reports a font it cannot read as unknown", {
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
  expect_warning(f <- pdf_fonts(pdf), class = "zupdf_warning")
  expect_identical(f$name, c("", "Helvetica"))
  expect_identical(f$type, c("unknown", "type1"))
})

test_that("pdf_attachments() walks /Kids and reads names, types and dates", {
  objs <- list(
    "<< /Type /Catalog /Pages 2 0 R /Names << /EmbeddedFiles 5 0 R >> >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
    list(dict = "<< >>", data = ""),
    "<< /Kids [6 0 R null 7 0 R] >>",
    "<< /Limits [(a.txt) (a.txt)] /Names [(a.txt) 8 0 R] >>",
    "<< /Limits [(b.csv) (c.bin)] /Names [(b.csv) 9 0 R (c.bin) 12 0 R] >>",
    "<< /Type /Filespec /F (a.txt) /UF (a-unicode.txt) /Desc (First) /EF << /F 10 0 R >> >>",
    "<< /Type /Filespec /F (b.csv) /EF << /F 11 0 R >> >>",
    list(
      dict = "<< /Type /EmbeddedFile /Subtype /text#2Fplain /Params << /CreationDate (D:20240102030405Z) /ModDate (D:20240203040506+01'00') >> >>",
      data = "aaa"
    ),
    list(dict = "<< /Type /EmbeddedFile >>", data = "x,y\n1,2\n"),
    # No /F: /FS must not stand in for it.
    "<< /Type /Filespec /FS /URL /EF << /F 13 0 R >> >>",
    list(
      dict = "<< /Type /EmbeddedFile /Subtype /application#2Foctet-stream >>",
      data = as.raw(0:5)
    )
  )
  path <- withr::local_tempfile(fileext = ".pdf")
  writeBin(build_pdf(objs), path)
  att <- pdf_attachments(path)
  expect_identical(
    vapply(att, `[[`, "", "name"),
    c("a-unicode.txt", "b.csv", "c.bin")
  )
  expect_identical(
    vapply(att, `[[`, "", "mime"),
    c("text/plain", "", "application/octet-stream")
  )
  expect_identical(vapply(att, `[[`, "", "description"), c("First", "", ""))
  expect_identical(rawToChar(att[[2]]$data), "x,y\n1,2\n")
  expect_identical(att[[3]]$data, as.raw(0:5))
  expect_equal(
    as.numeric(att[[1]]$created),
    as.numeric(as.POSIXct("2024-01-02 03:04:05", tz = "UTC"))
  )
  expect_equal(
    as.numeric(att[[1]]$modified),
    as.numeric(as.POSIXct("2024-02-03 03:05:06", tz = "UTC"))
  )
  expect_true(is.na(att[[2]]$created))
  expect_true(pdf_info(path)$attachments)
  skip_if_not_installed("pdftools")
  # pdftools gives the third, whose specification is invalid, no name or
  # data, and an absent date one second before 1970.
  p <- suppressMessages(pdftools::pdf_attachments(path))
  for (k in 1:2) {
    for (f in c("name", "mime", "description", "data")) {
      expect_identical(att[[k]][[f]], p[[k]][[f]], label = f)
    }
  }
  expect_equal(as.numeric(att[[1]]$created), as.numeric(p[[1]]$created))
  expect_equal(as.numeric(att[[1]]$modified), as.numeric(p[[1]]$modified))
})

test_that("an empty or odd /Names array lists no attachment", {
  for (names in c("[]", "[(a.txt)]")) {
    objs <- list(
      sprintf(
        "<< /Type /Catalog /Pages 2 0 R /Names << /EmbeddedFiles << /Names %s >> >> >>",
        names
      ),
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
      list(dict = "<< >>", data = "")
    )
    bytes <- build_pdf(objs)
    expect_identical(pdf_attachments(bytes), list(), label = names)
    expect_false(pdf_info(bytes)$attachments, label = names)
  }
})

test_that("pdf_info()$layout names each /PageLayout as pdftools does", {
  layouts <- c(
    SinglePage = "single_page",
    OneColumn = "one_column",
    TwoColumnLeft = "two_column_left",
    TwoColumnRight = "two_column_right",
    TwoPageLeft = "two_page_left",
    TwoPageRight = "two_page_right",
    Bogus = "no_layout"
  )
  for (l in names(layouts)) {
    objs <- list(
      sprintf("<< /Type /Catalog /Pages 2 0 R /PageLayout /%s >>", l),
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
      list(dict = "<< >>", data = "")
    )
    expect_identical(pdf_info(build_pdf(objs))$layout, layouts[[l]], label = l)
  }
})

# ---- passwords, limits and outputs ----------------------------------------------

test_that("the owner password is tried when the user password is refused", {
  f <- fixture("encrypted-aes-128-pw.pdf")
  text <- "Encrypted with AES-128 and passwords\n"
  expect_identical(pdf_text(f, opw = "owner", upw = "wrong"), text)
  expect_identical(pdf_text(f, opw = "wrong", upw = "user"), text)
  bytes <- readBin(f, "raw", file.size(f))
  expect_identical(pdf_info(bytes, opw = "owner", upw = "wrong")$pages, 1L)
  expect_zupdf_error(
    pdf_text(f, opw = "bad", upw = "wrong"),
    "zupdf_password_error"
  )
  expect_zupdf_error(
    pdf_text(f, opw = NA_character_),
    "zupdf_invalid_argument",
    arg = "opw"
  )
})

test_that("pdf_toc() stops at the file's max_depth", {
  objs <- list(
    "<< /Type /Catalog /Pages 2 0 R /Outlines 5 0 R >>",
    "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
    list(dict = "<< >>", data = ""),
    "<< /Type /Outlines /First 6 0 R >>",
    "<< /Title (1) /First 7 0 R >>",
    "<< /Title (1.1) /First 8 0 R >>",
    "<< /Title (1.1.1) >>"
  )
  bytes <- build_pdf(objs)
  deep <- pdf_toc(bytes)
  expect_identical(
    deep$children[[1]]$children[[1]]$children[[1]]$title,
    "1.1.1"
  )
  pdf <- pdf_open(bytes, max_depth = 1)
  withr::defer(pdf_close(pdf))
  shallow <- pdf_toc(pdf)
  expect_identical(shallow$children[[1]]$children[[1]]$title, "1.1")
  expect_identical(shallow$children[[1]]$children[[1]]$children, list())
})

test_that("a deep outline under a large max_depth does not overflow R", {
  # 5 000 objects: the recursive walk this replaced overflowed R's stack.
  skip_heavy()
  n <- 5000L
  items <- sprintf(
    "<< /Title (%d)%s >>",
    seq_len(n),
    ifelse(seq_len(n) < n, sprintf(" /First %d 0 R", 6L + seq_len(n)), "")
  )
  bytes <- build_pdf(c(
    list(
      "<< /Type /Catalog /Pages 2 0 R /Outlines 5 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R >>",
      list(dict = "<< >>", data = ""),
      "<< /Type /Outlines /First 6 0 R >>"
    ),
    as.list(items)
  ))
  pdf <- pdf_open(bytes, max_depth = 1e6)
  withr::defer(pdf_close(pdf))
  item <- pdf_toc(pdf)
  depth <- 0L
  while (length(item$children)) {
    item <- item$children[[1]]
    depth <- depth + 1L
  }
  expect_identical(depth, n)
  expect_identical(item$title, as.character(n))
})

test_that("a limit reached reading the XMP metadata is raised", {
  w <- pdf_new(version = "2.0")
  pdf_set_meta(w, title = "Meta")
  pdf_page_end(pdf_page_new(w))
  pdf <- pdf_open(pdf_save(w), max_stream = 100)
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(pdf_info(pdf), "zupdf_limit_error", limit = "max_stream")
})

test_that("default outputs drop .pdf in any case and never overwrite an input", {
  dir <- withr::local_tempdir()
  upper <- minimal_pdf(text = "a", path = file.path(dir, "doc.PDF"))
  bare <- minimal_pdf(text = "b", path = file.path(dir, "bare"))
  before <- bytes_md5(upper)
  expect_identical(basename(pdf_subset(upper)), "doc_output.pdf")
  expect_identical(basename(pdf_rotate_pages(upper, 1)), "doc_output.pdf")
  expect_identical(basename(pdf_combine(c(upper, bare))), "doc_combined.pdf")
  expect_identical(basename(pdf_subset(bare)), "bare_output.pdf")
  expect_identical(bytes_md5(upper), before)
  expect_zupdf_error(
    pdf_subset(upper, output = upper),
    "zupdf_invalid_argument",
    arg = "output"
  )
  expect_zupdf_error(
    pdf_combine(c(upper, bare), output = bare),
    "zupdf_invalid_argument",
    arg = "output"
  )
  # The second page of "x" would be x_2.pdf, the input itself.
  two <- minimal_pdf(text = c("1", "2"), path = file.path(dir, "x_2.pdf"))
  expect_zupdf_error(
    pdf_split(two, output = file.path(dir, "x")),
    "zupdf_invalid_argument",
    arg = "output"
  )
  expect_identical(bytes_md5(upper), before)
})

test_that("a pdf_file read from memory needs an explicit output", {
  pdf <- pdf_open(minimal_pdf(text = c("a", "b")))
  withr::defer(pdf_close(pdf))
  expect_zupdf_error(
    pdf_subset(pdf, pages = 2),
    "zupdf_invalid_argument",
    arg = "output"
  )
  expect_zupdf_error(pdf_split(pdf), "zupdf_invalid_argument", arg = "output")
  out <- withr::local_tempfile(fileext = ".pdf")
  expect_identical(pdf_text(pdf_subset(pdf, pages = 2, output = out)), "b\n")
})
