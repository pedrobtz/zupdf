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
    "pdf_overlay_stamp",
    "pdf_data"
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
