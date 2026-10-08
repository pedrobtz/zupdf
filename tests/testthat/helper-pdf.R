# PDF inputs for the tests. They live here, not at the top of a test file,
# because devtools::test(shuffle = TRUE) reorders a file's top-level
# expressions, definitions included.

# The path of a committed fixture (tests/testthat/fixtures, written by
# tools/update-fixtures). A missing fixture is an error, not a skip: the
# fixtures are part of the package's tests.
fixture <- function(name) {
  path <- test_path("fixtures", name)
  if (!file.exists(path)) {
    stop("no fixture ", name, "; run tools/update-fixtures")
  }
  path
}

# A small, valid PDF built byte by byte, so a test needs no fixture and no
# writer. One page per element of `text` (or `pages` empty pages), each
# showing its string in Helvetica 12 at (72, 720). `info` is a named
# character vector for the document information dictionary.
#
# Page attributes: `media_box` (default US letter), `crop_box` and `rotate`
# go on every page, or on the page tree's root when `inherit` is TRUE, so
# the pages inherit them. `page_extra` is raw dictionary text added to every
# page, and `tree_extra` to the root, for malformed cases.
#
# Returns the bytes, or writes them to `path` and returns it.
minimal_pdf <- function(
  pages = 1L,
  text = NULL,
  info = NULL,
  version = "1.4",
  media_box = c(0, 0, 612, 792),
  crop_box = NULL,
  rotate = NULL,
  inherit = FALSE,
  page_extra = "",
  tree_extra = "",
  path = NULL
) {
  if (!is.null(text)) {
    pages <- length(text)
  }
  n <- as.integer(pages)
  stopifnot(n >= 1L)
  # Objects: 1 catalog, 2 page tree, 3 font, then a page and its content
  # stream per page, then the information dictionary if any.
  page_obj <- 3L + 2L * seq_len(n) - 1L
  content_obj <- page_obj + 1L
  info_obj <- if (is.null(info)) NULL else 3L + 2L * n + 1L

  objs <- character()
  objs[1L] <- "<< /Type /Catalog /Pages 2 0 R >>"
  box <- function(b) sprintf("[%s]", paste(format(b), collapse = " "))
  attrs <- paste(
    c(
      if (!is.null(media_box)) paste0(" /MediaBox ", box(media_box)),
      if (!is.null(crop_box)) paste0(" /CropBox ", box(crop_box)),
      if (!is.null(rotate)) sprintf(" /Rotate %d", as.integer(rotate))
    ),
    collapse = ""
  )
  objs[2L] <- sprintf(
    "<< /Type /Pages /Kids [%s] /Count %d%s%s >>",
    paste(sprintf("%d 0 R", page_obj), collapse = " "),
    n,
    if (inherit) attrs else "",
    tree_extra
  )
  objs[
    3L
  ] <- "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"
  for (i in seq_len(n)) {
    objs[page_obj[i]] <- sprintf(
      paste0(
        "<< /Type /Page /Parent 2 0 R%s ",
        "/Resources << /Font << /F1 3 0 R >> >> /Contents %d 0 R%s >>"
      ),
      if (inherit) "" else attrs,
      content_obj[i],
      page_extra
    )
    stream <- if (is.null(text)) {
      ""
    } else {
      sprintf("BT /F1 12 Tf 72 720 Td (%s) Tj ET", pdf_escape(text[[i]]))
    }
    objs[content_obj[i]] <- sprintf(
      "<< /Length %d >>\nstream\n%s\nendstream",
      nchar(stream, type = "bytes"),
      stream
    )
  }
  if (!is.null(info)) {
    objs[info_obj] <- sprintf(
      "<< %s >>",
      paste(sprintf("/%s (%s)", names(info), pdf_escape(info)), collapse = " ")
    )
  }

  # The header's second line is a comment of four high bytes, which marks
  # the file as binary; the rest is ASCII, so byte offsets are char counts.
  header <- c(
    charToRaw(sprintf("%%PDF-%s\n%%", version)),
    as.raw(c(0xe2, 0xe3, 0xcf, 0xd3, 0x0a))
  )
  body <- ""
  offsets <- integer(length(objs))
  for (k in seq_along(objs)) {
    offsets[k] <- length(header) + nchar(body, type = "bytes")
    body <- paste0(body, sprintf("%d 0 obj\n%s\nendobj\n", k, objs[k]))
  }
  xref <- length(header) + nchar(body, type = "bytes")
  body <- paste0(
    body,
    sprintf("xref\n0 %d\n0000000000 65535 f \n", length(objs) + 1L),
    paste(sprintf("%010d 00000 n \n", offsets), collapse = ""),
    sprintf(
      "trailer\n<< /Size %d /Root 1 0 R%s >>\nstartxref\n%d\n%%%%EOF\n",
      length(objs) + 1L,
      if (is.null(info_obj)) "" else sprintf(" /Info %d 0 R", info_obj),
      xref
    )
  )
  bytes <- c(header, charToRaw(body))
  if (is.null(path)) {
    return(bytes)
  }
  writeBin(bytes, path)
  path
}

# A literal string's body: backslash, and both parentheses, escaped.
pdf_escape <- function(x) gsub("([\\\\()])", "\\\\\\1", x)

# pdfio's afl-input corpus (tools/update-fixtures).
afl_files <- function() {
  list.files(test_path("fixtures", "afl-input"), full.names = TRUE)
}

# Opens a file and reads everything Stage 1 can read, closing it again.
read_all <- function(path) {
  pdf <- pdf_open(path)
  on.exit(pdf_close(pdf))
  m <- pdf_meta(pdf)
  p <- pdf_pages(pdf)
  list(pages = m$pages, rows = nrow(p))
}
