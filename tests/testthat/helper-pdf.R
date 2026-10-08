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
# showing its string in Helvetica 12 at (72, 720) on a US letter page.
# `info` is a named character vector for the document information
# dictionary. Returns the bytes, or writes them to `path` and returns it.
minimal_pdf <- function(
  pages = 1L,
  text = NULL,
  info = NULL,
  version = "1.4",
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
  objs[2L] <- sprintf(
    "<< /Type /Pages /Kids [%s] /Count %d >>",
    paste(sprintf("%d 0 R", page_obj), collapse = " "),
    n
  )
  objs[
    3L
  ] <- "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"
  for (i in seq_len(n)) {
    objs[page_obj[i]] <- sprintf(
      paste0(
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] ",
        "/Resources << /Font << /F1 3 0 R >> >> /Contents %d 0 R >>"
      ),
      content_obj[i]
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
