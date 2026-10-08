# Conformance against pdftools and qpdf (design section 15, roadmap Stage
# 7). Run through tools/run-conformance, from the package root, with zupdf
# installed and pdftools and qpdf available; the qpdf command line, when on
# the PATH, checks every file zupdf writes.
#
#   reading   pdf_page_text() against pdftools::pdf_text(): word recall on
#             every fixture; pdf_data()'s boxes against pdftools's; the
#             compatibility layer's values where design section 5.1 says
#             they agree
#   writing   files zupdf writes open in pdftools and qpdf, read back the
#             same text, and pass `qpdf --check`
#   bytes     deterministic output is identical twice over; its MD5 and
#             zlib version are printed for comparison across runners
#
# Prints a report and exits non-zero on any failure.

suppressMessages({
  library(zupdf)
  library(pdftools)
  library(qpdf)
})
test_path <- function(...) file.path("tests", "testthat", ...)
source("tests/testthat/helper-pdf.R")

failures <- character()
fail <- function(...) failures <<- c(failures, sprintf(...))
words <- function(x) {
  w <- unlist(strsplit(trimws(gsub("[[:space:]]+", " ", paste(x, collapse = " "))), " "))
  w[nzchar(w)]
}
recall <- function(ours, theirs) {
  t <- table(theirs)
  o <- table(ours)
  common <- intersect(names(t), names(o))
  if (!length(t)) return(NA_real_)
  sum(pmin(t[common], o[common])) / sum(t)
}

# ---- reading ------------------------------------------------------------------

cat("== text and words against pdftools\n")
files <- c(
  list.files("tests/testthat/fixtures", pattern = "[.]pdf$", full.names = TRUE),
  list.files("tests/testthat/fixtures/afl-input", full.names = TRUE)
)
files <- files[!grepl("-pw[.]pdf$", files)]
# Text poppler reads from annotation appearances, which zupdf does not
# (design section 8): agreement there is not expected.
annotation_only <- c("PDFBOX-1036-0.pdf", "PDFBOX-1036-2.pdf")
for (f in files) {
  ours <- tryCatch(suppressWarnings(zupdf::pdf_text(f)), error = function(e) NULL)
  theirs <- tryCatch(suppressMessages(pdftools::pdf_text(f)), error = function(e) NULL)
  if (is.null(theirs)) {
    cat(sprintf("  %-28s pdftools cannot read it; skipped\n", basename(f)))
    next
  }
  if (is.null(ours)) {
    fail("%s: zupdf refused a file pdftools reads", basename(f))
    next
  }
  if (length(ours) != length(theirs)) {
    fail("%s: %d pages, pdftools %d", basename(f), length(ours), length(theirs))
  }
  r <- recall(words(ours), words(theirs))
  cat(sprintf("  %-28s word recall %s\n", basename(f), if (is.na(r)) "-" else format(round(r, 3))))
  if (!is.na(r) && r < 0.9 && !basename(f) %in% annotation_only) {
    fail("%s: word recall %.3f against pdftools", basename(f), r)
  }
}

cat("== pdf_data() boxes against pdftools\n")
# Each pdftools word is paired with the nearest zupdf word of the same text.
# x is held to 2 points; y is reported, not held, since poppler takes some
# fonts' ascent from elsewhere than their descriptor or bounding box (a
# Type 3 font's height comes out near twice its size).
for (f in c("inst/examples/hello.pdf", "tests/testthat/fixtures/grdevices.pdf", "tests/testthat/fixtures/testpdfio.pdf")) {
  a <- zupdf::pdf_data(f)
  b <- pdftools::pdf_data(f)
  for (i in seq_along(b)) {
    za <- as.data.frame(a[[i]])
    pb <- as.data.frame(b[[i]])
    dx <- dy <- rep(NA_real_, nrow(pb))
    for (k in seq_len(nrow(pb))) {
      cand <- which(za$text == pb$text[[k]])
      if (length(cand)) {
        d <- abs(za$x[cand] - pb$x[[k]]) + abs(za$y[cand] - pb$y[[k]])
        best <- cand[[which.min(d)]]
        dx[[k]] <- abs(za$x[[best]] - pb$x[[k]])
        dy[[k]] <- abs(za$y[[best]] - pb$y[[k]])
      }
    }
    matched <- sum(!is.na(dx))
    within <- if (matched) mean(dx <= 2, na.rm = TRUE) else NA
    cat(sprintf(
      "  %-14s page %d: %d of %d words found, x within 2 pt for %.0f%%, median |dy| %s\n",
      basename(f), i, matched, nrow(pb), 100 * within, format(stats::median(dy, na.rm = TRUE))
    ))
    if (nrow(pb) && (matched < 0.9 * nrow(pb) || within < 0.9)) {
      fail("%s page %d: pdf_data() words or x positions disagree with pdftools", basename(f), i)
    }
  }
}

cat("== compatibility layer values\n")
for (f in c("inst/examples/hello.pdf", "tests/testthat/fixtures/testpdfio.pdf", "tests/testthat/fixtures/grdevices.pdf")) {
  a <- zupdf::pdf_info(f)
  b <- pdftools::pdf_info(f)
  for (k in c("version", "pages", "encrypted", "linearized", "layout", "attachments")) {
    if (!identical(a[[k]], b[[k]])) fail("%s: pdf_info()$%s differs from pdftools", basename(f), k)
  }
  if (!identical(zupdf::pdf_pagesize(f), pdftools::pdf_pagesize(f))) {
    fail("%s: pdf_pagesize() differs from pdftools", basename(f))
  }
  if (!identical(zupdf::pdf_length(f), qpdf::pdf_length(f))) {
    fail("%s: pdf_length() differs from qpdf", basename(f))
  }
  cat(sprintf("  %-28s compared\n", basename(f)))
}

# ---- writing ------------------------------------------------------------------

cat("== written files in pdftools and qpdf\n")
dir <- tempfile("conformance-")
dir.create(dir)
qpdf_cli <- Sys.which("qpdf")
written_cases <- list(
  text = function(w) {
    p <- pdf_page_new(w)
    pdf_draw_text(p, 72, 700, "Base fonts: Helvetica and Times", size = 14)
    pdf_draw_text(p, 72, 650, "Embedded: Łódź ß", font = test_path("fixtures", "OpenSans-Regular.ttf"))
    pdf_page_end(p)
  },
  shapes = function(w) {
    p <- pdf_page_new(w)
    pdf_draw(p, list(x = c(72, 300, 186), y = c(500, 500, 650)), fill = "gold", stroke = "black", close = TRUE)
    pdf_draw(p, data.frame(op = "rect", x = 72, y = 300, w = 200, h = 100), fill = "steelblue")
    pdf_draw_text(p, 72, 280, "Shapes")
    pdf_page_end(p)
  },
  images = function(w) {
    p <- pdf_page_new(w)
    pdf_draw_image(p, pdf_image_new(w, test_path("fixtures", "pdfio-color.png")), 72, 500, 100, 100)
    pdf_draw_image(p, pdf_image_new(w, test_path("fixtures", "color.jpg")), 200, 500, 100, 100)
    pdf_draw_image(p, pdf_image_new(w, as.raster(matrix(c("red", "blue"), 1))), 330, 500, 100, 50)
    pdf_draw_text(p, 72, 480, "Images")
    pdf_page_end(p)
  },
  copied = function(w) {
    src <- pdf_open(test_path("fixtures", "testpdfio.pdf"))
    pdf_copy_pages(w, src, pages = c(2, 1), rotate = 90)
    pdf_save_later <<- src
  },
  encrypted = function(w) {
    pdf_set_encryption(w, user = "u", permissions = "print")
    p <- pdf_page_new(w)
    pdf_draw_text(p, 72, 700, "Encrypted")
    pdf_page_end(p)
  }
)
pdf_save_later <- NULL
for (nm in names(written_cases)) {
  w <- pdf_new(deterministic = TRUE)
  written_cases[[nm]](w)
  path <- file.path(dir, paste0(nm, ".pdf"))
  pdf_save(w, path)
  if (!is.null(pdf_save_later)) {
    pdf_close(pdf_save_later)
    pdf_save_later <- NULL
  }
  pw <- if (nm == "encrypted") "u" else ""
  ours <- zupdf::pdf_text(path, upw = pw)
  theirs <- tryCatch(pdftools::pdf_text(path, upw = pw), error = function(e) NULL)
  if (is.null(theirs)) {
    fail("%s: pdftools cannot read the file zupdf wrote", nm)
  } else if (!identical(words(ours), words(theirs))) {
    fail("%s: pdftools reads other words from the file zupdf wrote", nm)
  }
  n <- tryCatch(qpdf::pdf_length(path, password = pw), error = function(e) NA)
  if (is.na(n)) fail("%s: qpdf cannot read the file zupdf wrote", nm)
  check <- if (nzchar(qpdf_cli)) {
    args <- c(if (nzchar(pw)) paste0("--password=", pw), "--check", path)
    out <- suppressWarnings(system2(qpdf_cli, args, stdout = TRUE, stderr = TRUE))
    st <- attr(out, "status")
    if (!is.null(st) && st != 0L) {
      fail("%s: qpdf --check failed: %s", nm, paste(utils::tail(out, 3), collapse = " | "))
      "FAILED"
    } else {
      "ok"
    }
  } else {
    "not run (no qpdf command)"
  }
  cat(sprintf("  %-10s pdftools %s, qpdf %s pages, qpdf --check %s\n", nm, if (is.null(theirs)) "FAILED" else "ok", n, check))
}

# ---- bytes --------------------------------------------------------------------

cat("== deterministic bytes\n")
make <- function() written(function(page) pdf_draw_text(page, 72, 700, "Hello"))
a <- make()
b <- make()
if (!identical(a, b)) fail("deterministic output differs between two runs")
md5 <- unname(tools::md5sum({
  f <- tempfile()
  writeBin(a, f)
  f
}))
cat(sprintf("  hello: md5 %s, zlib %s, %s\n", md5, zupdf_info()$zlib_version, R.version$platform))

if (length(failures)) {
  cat("\nFAILURES:\n", paste0("  ", failures, "\n"), sep = "")
  quit(status = 1L)
}
cat("\n==> conformance: all checks passed\n")
