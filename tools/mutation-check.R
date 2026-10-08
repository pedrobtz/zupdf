# Proves the limits' guards are load-bearing (design section 12, roadmap
# Stage 6). Each guard is marked "GUARD: name": in C on its if-line, in R on
# the line after its if-line (air puts the comment there). For each, a
# scratch copy of the built package has that one guard disabled, is
# reinstalled (only the changed file recompiles), and the guard's hostile
# input must then get a different answer: another result, a crash, or a hang
# past the timeout. A guard whose removal changes nothing was never doing
# anything. Run through tools/run-mutation-check, from the package root.
#
# Not checked, as defence in depth: cmap_entries, cmap_cps and cid_widths in
# src/zpd_font.c bound a font's ToUnicode CMap and /W array at a million
# entries, a fixed bound no argument lowers, which only a ~30 MB font
# reaches.

args <- commandArgs(TRUE)
work <- args[[1]]
timeout_bin <- Sys.which(c("timeout", "gtimeout"))
timeout_bin <- timeout_bin[nzchar(timeout_bin)][1]

# guard, file, probe (R code; the test helpers are loaded), and what the
# probe gives with the guard in place.
cases <- list(
  list("max_size", "R/open.R", 'pdf_open(minimal_pdf(), max_size = 10)'),
  list("max_objects", "R/open.R", 'pdf_open(minimal_pdf(pages = 3L), max_objects = 3)'),
  list("max_pages", "R/open.R", 'pdf_open(minimal_pdf(pages = 3L), max_pages = 2)'),
  list(
    "max_depth_inherit",
    "src/zpd_core.c",
    'pdf_pages(pdf_open(minimal_pdf(media_box = NULL, tree_extra = " /Parent 2 0 R"), max_depth = 5))'
  ),
  list(
    "max_depth_read",
    "src/zpd_value.c",
    'pdf_object(pdf_open(stream_pdf(raw(), value = nested_array(10)), max_depth = 5), 5)'
  ),
  list(
    "max_depth_write",
    "src/zpd_value.c",
    '.Call(zupdf:::zupdf_value_roundtrip, list(a = list(list(list(list(1L))))), 3L)$status'
  ),
  list(
    "max_stream",
    "src/zpd_object.c",
    'pdf_stream(pdf_open(stream_pdf(flate(raw(1e6)), "/Filter /FlateDecode"), max_stream = 1e4), 4)'
  ),
  list(
    "max_stream_content",
    "src/zpd_text.c",
    'pdf_page_text(pdf_open(minimal_pdf(text = strrep("x", 200)), max_stream = 100))'
  ),
  list("form_cycle", "src/zpd_text.c", 'pdf_page_text(pdf_open(cycle_pdf(), max_depth = 8))'),
  list("max_depth_form", "src/zpd_text.c", 'pdf_page_text(pdf_open(deep_forms_pdf(4), max_depth = 3))')
)
expected <- c(
  max_size = "zupdf_limit_error",
  max_objects = "zupdf_limit_error",
  max_pages = "zupdf_limit_error",
  max_depth_inherit = "zupdf_limit_error",
  max_depth_read = "zupdf_limit_error",
  max_depth_write = "max_depth",
  max_stream = "zupdf_limit_error",
  max_stream_content = "zupdf_limit_error",
  form_cycle = "zupdf_limit_error: a form XObject draws itself",
  max_depth_form = "zupdf_limit_error"
)

# Forms for the two form guards: one that draws itself, and a chain of
# `n` forms of which the last shows text.
probe_helpers <- '
cycle_pdf <- function() {
  form <- list(
    dict = "<< /Type /XObject /Subtype /Form /BBox [0 0 600 800] /Resources << /XObject << /X1 5 0 R >> >> >>",
    data = "/X1 Do"
  )
  page_pdf("/X1 Do", "<< /XObject << /X1 5 0 R >> >>", extra = list(form))
}
deep_forms_pdf <- function(n) {
  forms <- lapply(seq_len(n), function(i) {
    k <- 4L + i
    list(
      dict = sprintf(
        "<< /Type /XObject /Subtype /Form /BBox [0 0 600 800] /Resources << /Font << /F1 %s >> /XObject << /X1 %d 0 R >> >> >>",
        helv, k + 1L
      ),
      data = if (i < n) "/X1 Do" else "BT /F1 12 Tf 72 700 Td (deep) Tj ET"
    )
  })
  page_pdf("/X1 Do", "<< /XObject << /X1 5 0 R >> >>", extra = forms)
}
'

# Runs a probe against the package installed in `lib`: one line, the
# condition's class (with the message for form_cycle) or the value's.
probe <- function(lib, guard, code) {
  script <- file.path(work, paste0("probe-", guard, ".R"))
  writeLines(
    c(
      sprintf("suppressMessages(library(zupdf, lib.loc = %s))", deparse(lib)),
      "test_path <- function(...) file.path('tests', 'testthat', ...)",
      "source('tests/testthat/helper-pdf.R')",
      probe_helpers,
      "out <- tryCatch({",
      paste0("  x <- suppressWarnings(", code, ")"),
      "  if (is.character(x) && length(x) == 1L) x else class(x)[[1L]]",
      "}, error = function(e) {",
      sprintf(
        "  if (%s == 'form_cycle') paste0(class(e)[[1L]], ': ', sub('.*: ', '', conditionMessage(e))) else class(e)[[1L]]",
        deparse(guard)
      ),
      "})",
      "cat(sub('[.]$', '', out))"
    ),
    script
  )
  rscript <- file.path(R.home("bin"), "Rscript")
  # A mutant may loop for ever (max_depth_inherit's cycle): timeout(1), or
  # perl's alarm where there is none (macOS).
  if (is.na(timeout_bin)) {
    cmd <- "perl"
    cargs <- c("-e", shQuote("alarm 60; exec @ARGV"), rscript, script)
  } else {
    cmd <- timeout_bin
    cargs <- c("60", rscript, script)
  }
  out <- suppressWarnings(system2(cmd, cargs, stdout = TRUE, stderr = FALSE))
  status <- attr(out, "status")
  if (!is.null(status) && status != 0L) {
    return(sprintf("exit %d (a crash or a hang)", status))
  }
  paste(out, collapse = "")
}

# Disables one guard in a copy of a source file; returns the new lines.
mutate <- function(lines, guard, file) {
  marker <- sprintf("GUARD: %s", guard)
  at <- grep(marker, lines, fixed = TRUE)
  if (length(at) != 1L) {
    stop(sprintf("%s: %d markers in %s, expected 1", guard, length(at), file))
  }
  if (grepl("[.]c$", file)) {
    pat <- sprintf("if \\((.*)\\)( *\\{)? */\\* %s \\*/", marker)
    new <- sub(pat, sprintf("if (0 && (\\1))\\2 /* %s */", marker), lines[[at]])
    k <- at
  } else {
    k <- at - 1L
    new <- sub("if \\((.*)\\) \\{$", "if (FALSE && (\\1)) {", lines[[k]])
  }
  if (identical(new, lines[[k]])) {
    stop(sprintf("%s: the mutation did not apply to %s", guard, file))
  }
  lines[[k]] <- new
  lines
}

install <- function(dir, lib) {
  dir.create(lib, showWarnings = FALSE)
  rcmd <- file.path(R.home("bin"), "R")
  out <- system2(rcmd, c("CMD", "INSTALL", "--no-test-load", "-l", lib, dir), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(out, "status"))) {
    writeLines(tail(out, 30))
    stop("R CMD INSTALL failed for ", dir)
  }
}

# The package, built in place once, so that each mutant recompiles only the
# file it changes.
base <- file.path(work, "base")
dir.create(base)
for (f in c("DESCRIPTION", "NAMESPACE", "R", "src", "inst", "man")) {
  file.copy(f, base, recursive = TRUE)
}
install(base, file.path(work, "lib-base"))

failed <- FALSE
for (cs in cases) {
  guard <- cs[[1]]
  file <- cs[[2]]
  code <- cs[[3]]
  got <- probe(file.path(work, "lib-base"), guard, code)
  if (!identical(got, expected[[guard]])) {
    message(sprintf("FAIL: %s: with the guard the probe gives '%s', expected '%s'", guard, got, expected[[guard]]))
    failed <- TRUE
    next
  }
  mdir <- file.path(work, paste0("mutant-", guard))
  system2("cp", c("-Rp", base, mdir))
  path <- file.path(mdir, file)
  writeLines(mutate(readLines(path), guard, file), path)
  install(mdir, file.path(work, paste0("lib-", guard)))
  mutant <- probe(file.path(work, paste0("lib-", guard)), guard, code)
  if (identical(mutant, got)) {
    message(sprintf("FAIL: %s: removing the guard changes nothing (still '%s')", guard, got))
    failed <- TRUE
  } else {
    message(sprintf("==> %s: '%s' with the guard, '%s' without", guard, got, mutant))
  }
  unlink(mdir, recursive = TRUE)
}
if (failed) {
  quit(status = 1L)
}
message("==> every guard is load-bearing")
