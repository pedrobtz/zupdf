# pdf_copy_pages() over every fixture the tests read (design section 15,
# round trips): each page's boxes, rotation and text must survive the copy.

test_that("every fixture copies with its boxes, rotation and text", {
  files <- c(
    list.files(test_path("fixtures"), "\\.pdf$", full.names = TRUE),
    afl_files()
  )
  passwords <- c(
    "encrypted-aes-128-pw.pdf" = "user",
    "encrypted-rc4-128-pw.pdf" = "user"
  )
  # Two afl-input cases are damaged where a copy must read: 1037-0's last
  # page draws an image object the file lacks, and 1094-3's object 7 has a
  # bad header. Copying them is refused, with a class.
  refused <- c("PDFBOX-1037-0.pdf", "PDFBOX-1094-3.pdf")
  copied <- 0L
  for (path in files) {
    label <- basename(path)
    password <- if (label %in% names(passwords)) passwords[[label]]
    # Some afl-input files warn that their cross-reference is rebuilt.
    src <- suppressWarnings(pdf_open(path, password = password))
    withr::defer(pdf_close(src))
    w <- pdf_new()
    if (label %in% refused) {
      expect_zupdf_error(pdf_copy_pages(w, src), "zupdf_write_error")
      next
    }
    pdf_copy_pages(w, src)
    dst <- pdf_open(pdf_save(w))
    withr::defer(pdf_close(dst))

    a <- pdf_pages(src)
    b <- pdf_pages(dst)
    expect_identical(nrow(b), nrow(a), label = label)
    expect_identical(b$rotate, a$rotate, label = paste(label, "rotate"))
    # pdfio writes reals to six decimals, so 595.2199707031 becomes
    # 595.219971: equal, not identical.
    for (col in c("width", "height", "media_box", "crop_box")) {
      expect_equal(b[[col]], a[[col]], label = paste(label, col))
    }
    expect_identical(
      as.vector(pdf_page_text(dst)),
      as.vector(pdf_page_text(src)),
      label = paste(label, "text")
    )
    copied <- copied + 1L
  }
  # The four encrypted files, testpdfio.pdf, grdevices.pdf and 21 of
  # pdfio's 23 afl-input cases.
  expect_identical(copied, length(files) - length(refused))
  expect_gte(copied, 27L)
})
