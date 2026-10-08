# Benchmarks against pdftools and qpdf (design section 16, roadmap Stage 7).
# Informational, not a gate: prints the median of several runs of each, on
# files built here so every machine measures the same thing. Run through
# tools/run-benchmarks, from the package root, with zupdf installed.

suppressMessages(library(zupdf))
test_path <- function(...) file.path("tests", "testthat", ...)
source("tests/testthat/helper-pdf.R")
has <- function(p) requireNamespace(p, quietly = TRUE)

time_it <- function(expr, n = 5L) {
  e <- substitute(expr)
  env <- parent.frame()
  times <- vapply(seq_len(n), function(i) system.time(eval(e, env))[["elapsed"]], 0)
  1000 * stats::median(times)
}
row <- function(task, z, other = NA, against = "") {
  cat(sprintf(
    "%-38s zupdf %8.1f ms   %-8s %s\n",
    task,
    z,
    against,
    if (is.na(other)) "" else sprintf("%8.1f ms (%.2fx)", other, z / other)
  ))
}

dir <- tempfile("bench-")
dir.create(dir)
para <- paste(rep("The quick brown fox jumps over the lazy dog.", 4), collapse = " ")
doc100 <- file.path(dir, "doc100.pdf")
w <- pdf_new()
for (i in 1:100) {
  p <- pdf_page_new(w)
  for (k in 1:40) pdf_draw_text(p, 50, 800 - 18 * k, substr(paste(i, k, para), 1, 90), size = 10)
  pdf_page_end(p)
}
pdf_save(w, doc100)

cat("zupdf", as.character(utils::packageVersion("zupdf")), "on", R.version$platform, "\n")
row(
  "open + metadata, 100 pages",
  time_it(local({ p <- pdf_open(doc100); pdf_meta(p); pdf_close(p) })),
  if (has("pdftools")) time_it(pdftools::pdf_info(doc100)) else NA,
  "pdftools"
)
row(
  "text, 100 pages",
  time_it(local({ p <- pdf_open(doc100); pdf_page_text(p); pdf_close(p) }), 3L),
  if (has("pdftools")) time_it(pdftools::pdf_text(doc100), 3L) else NA,
  "pdftools"
)
ones <- vapply(1:100, function(i) {
  minimal_pdf(text = paste("page", i), path = file.path(dir, sprintf("one-%03d.pdf", i)))
}, "")
row(
  "merge 100 one-page files",
  time_it(zupdf::pdf_combine(ones, output = file.path(dir, "z.pdf")), 3L),
  if (has("qpdf")) time_it(qpdf::pdf_combine(ones, output = file.path(dir, "q.pdf")), 3L) else NA,
  "qpdf"
)
row(
  "write 100 pages of text and paths",
  time_it(local({
    w <- pdf_new()
    for (i in 1:100) {
      p <- pdf_page_new(w)
      for (k in 1:40) pdf_draw_text(p, 50, 800 - 18 * k, "A line of a report", size = 10)
      pdf_draw(p, data.frame(op = "rect", x = 40, y = 40, w = 515, h = 760))
      pdf_page_end(p)
    }
    pdf_save(w)
  }), 3L)
)
