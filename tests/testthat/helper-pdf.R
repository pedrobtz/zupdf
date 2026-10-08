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

# A one-page PDF whose object 4 is a stream holding `data` (raw) with the
# dictionary entries in `dict` (raw PDF text, such as "/Filter
# /FlateDecode"), and whose object 5 is `value` (raw PDF text) when given.
# For streams minimal_pdf() cannot hold: compressed, binary, or bombs.
stream_pdf <- function(data, dict = "", value = NULL) {
  objs <- list(
    charToRaw("<< /Type /Catalog /Pages 2 0 R >>"),
    charToRaw("<< /Type /Pages /Kids [3 0 R] /Count 1 >>"),
    charToRaw("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>"),
    c(
      charToRaw(sprintf("<< /Length %d %s >>\nstream\n", length(data), dict)),
      data,
      charToRaw("\nendstream")
    )
  )
  if (!is.null(value)) {
    objs[[5L]] <- charToRaw(value)
  }
  out <- charToRaw("%PDF-1.7\n")
  offsets <- integer(length(objs))
  for (k in seq_along(objs)) {
    offsets[k] <- length(out)
    out <- c(
      out,
      charToRaw(sprintf("%d 0 obj\n", k)),
      objs[[k]],
      charToRaw("\nendobj\n")
    )
  }
  xref <- length(out)
  c(
    out,
    charToRaw(paste0(
      sprintf("xref\n0 %d\n0000000000 65535 f \n", length(objs) + 1L),
      paste(sprintf("%010d 00000 n \n", offsets), collapse = ""),
      sprintf(
        "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n",
        length(objs) + 1L,
        xref
      )
    ))
  )
}

# zlib-compressed bytes, as FlateDecode stores them.
flate <- function(x) memCompress(x, "gzip")

# A value written by zupdf and read back (design section 6, both ways).
roundtrip <- function(x, ...) {
  r <- zpd_value_roundtrip(x, ...)
  pdf <- pdf_open(r$bytes)
  on.exit(pdf_close(pdf))
  pdf_object(pdf, r$number)
}

# A nested PDF array `depth` levels deep, as PDF text.
nested_array <- function(depth) {
  paste0(strrep("[", depth), "1", strrep("]", depth))
}

# A PDF from a list of objects, numbered from 1, with object 1 the catalog.
# Each object is PDF text, or list(dict = "<< ... >>" without /Length, data
# = raw or character) for a stream. Page content, fonts, forms and maps are
# written out in full, so a test shows exactly what it reads.
build_pdf <- function(objects) {
  body <- function(o) {
    if (!is.list(o)) {
      return(charToRaw(o))
    }
    data <- if (is.raw(o$data)) o$data else charToRaw(o$data)
    dict <- sub(">>\\s*$", sprintf(" /Length %d >>", length(data)), o$dict)
    c(charToRaw(dict), charToRaw("\nstream\n"), data, charToRaw("\nendstream"))
  }
  out <- charToRaw("%PDF-1.7\n")
  offsets <- integer(length(objects))
  for (k in seq_along(objects)) {
    offsets[k] <- length(out)
    out <- c(
      out,
      charToRaw(sprintf("%d 0 obj\n", k)),
      body(objects[[k]]),
      charToRaw("\nendobj\n")
    )
  }
  xref <- length(out)
  c(
    out,
    charToRaw(paste0(
      sprintf("xref\n0 %d\n0000000000 65535 f \n", length(objects) + 1L),
      paste(sprintf("%010d 00000 n \n", offsets), collapse = ""),
      sprintf(
        "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n",
        length(objects) + 1L,
        xref
      )
    ))
  )
}

# A one-page PDF whose page has content `content` and resources
# `resources` (PDF text), with `extra` objects numbered from 5. Objects 1-4
# are the catalog, page tree, page and content stream.
page_pdf <- function(content, resources = "<< >>", extra = list()) {
  build_pdf(c(
    list(
      "<< /Type /Catalog /Pages 2 0 R >>",
      "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
      sprintf(
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources %s /Contents 4 0 R >>",
        resources
      ),
      list(dict = "<< >>", data = content)
    ),
    extra
  ))
}

# Helvetica as a resource dictionary entry, WinAnsiEncoding.
helv <- "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"

# The text of a page_pdf(), opened from bytes.
text_of <- function(bytes, ..., layout = "reading") {
  pdf <- pdf_open(bytes, ...)
  on.exit(pdf_close(pdf))
  pdf_page_text(pdf, layout = layout)
}

# A page drawing image object 5: `w` x `h`, `cs`, 8 bits, with `data`
# stored under `filter` ("" for none).
image_pdf <- function(data, w, h, cs = "/DeviceRGB", filter = "") {
  page_pdf(
    sprintf("q %d 0 0 %d 0 0 cm /Im1 Do Q", w, h),
    "<< /XObject << /Im1 5 0 R >> >>",
    extra = list(list(
      dict = sprintf(
        "<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s /BitsPerComponent 8 %s >>",
        w,
        h,
        cs,
        filter
      ),
      data = data
    ))
  )
}

# A writer test's whole file: `draw` is called with each new page (one page
# unless `pages` says more) and the bytes are returned.
written <- function(
  draw = function(page) NULL,
  pages = 1L,
  ...,
  deterministic = TRUE
) {
  w <- pdf_new(
    created = as.POSIXct("2024-01-02 03:04:05", tz = "UTC"),
    deterministic = deterministic,
    ...
  )
  for (i in seq_len(pages)) {
    page <- pdf_page_new(w)
    draw(page)
    pdf_page_end(page)
  }
  pdf_save(w)
}

# Opens written bytes and returns what reading them gives.
reread <- function(bytes, what = pdf_page_text) {
  pdf <- pdf_open(bytes)
  on.exit(pdf_close(pdf))
  what(pdf)
}

# The compatibility layer (design section 5.1), by original package.
compat_pdftools <- c(
  "pdf_info",
  "pdf_text",
  "pdf_fonts",
  "pdf_pagesize",
  "pdf_toc",
  "pdf_attachments"
)
compat_qpdf <- c(
  "pdf_length",
  "pdf_split",
  "pdf_subset",
  "pdf_combine",
  "pdf_rotate_pages"
)
