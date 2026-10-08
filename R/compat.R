# The compatibility layer (design section 5.1, D8): pdftools's and qpdf's
# functions that need no renderer, under their names and with exactly their
# formal arguments, as thin wrappers over the native API. Formals are pinned
# to pdftools 3.9.0 and qpdf 1.4.1; test-compat.R compares them with the
# originals whenever those are installed. Never add an argument here: it
# belongs on the native function.

#' pdftools-compatible readers
#'
#' These functions take pdftools's arguments and return what pdftools
#' returns, so code written for pdftools runs with `library(zupdf)` in
#' place of `library(pdftools)` for everything but rendering. Each opens
#' its input with [pdf_open()]'s default limits and closes it again; `pdf`
#' may also be an open `pdf_file`, which is left open.
#'
#' Where the results differ from pdftools's (design section 5.1):
#' * `pdf_text()` comes from zupdf's extractor ([pdf_page_text()]), not
#'   poppler's physical layout: the same pages and words, single spaces
#'   instead of padding to page positions, and no text from annotations.
#' * `pdf_fonts()` reports `file` as `""` for an embedded font and `NA`
#'   otherwise, since zupdf looks up no system fonts.
#' * `pdf_info()` reports an absent date as `NA`, where pdftools reports
#'   one second before 1970.
#'
#' `pdf_render_page()`, `pdf_convert()` and the OCR functions need a
#' renderer and are not provided; `pdf_data()` is not provided yet.
#'
#' @param pdf A path, a raw vector, or an open `pdf_file`.
#' @param opw,upw The owner and user passwords; `""` for none.
#' @param raw For `pdf_text()`: `TRUE` for the text in content-stream
#'   order.
#' @return As pdftools: `pdf_info()` a list of `version`, `pages`,
#'   `encrypted`, `linearized`, `keys`, `created`, `modified`, `metadata`,
#'   `locked`, `attachments` and `layout`; `pdf_text()` one string per
#'   page; `pdf_fonts()` a data frame of `name`, `type`, `embedded` and
#'   `file`; `pdf_pagesize()` a data frame of `top`, `right`, `bottom`,
#'   `left`, `width` and `height`; `pdf_toc()` a nested list of `title`,
#'   `is_open` and `children`; `pdf_attachments()` a list of attachments, each with
#'   `name`, `mime`, `created`, `modified`, `description` and `data`.
#' @name pdftools-compat
#' @examples
#' path <- system.file("examples", "hello.pdf", package = "zupdf")
#' pdf_info(path)$pages
#' pdf_text(path)
#' pdf_pagesize(path)
NULL

#' @rdname pdftools-compat
#' @export
pdf_info <- function(pdf, opw = "", upw = "") {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  p <- x$pdf
  m <- pdf_meta(p)
  limits <- zpd_limits(p)
  info <- zpd_doc_dict(p, "info")
  cat <- zpd_doc_dict(p, "catalog")
  keys <- info[!names(info) %in% c("CreationDate", "ModDate")]
  keys <- keys[vapply(
    keys,
    function(v) is.character(v) && length(v) == 1L,
    TRUE
  )]
  keys <- lapply(keys, as.character)
  local <- function(t) .POSIXct(as.numeric(t), tz = "")
  list(
    version = m$version,
    pages = m$pages,
    encrypted = m$encryption != "none",
    linearized = zpd_linearized(p),
    keys = keys,
    created = local(m$created),
    modified = local(m$modified),
    metadata = zpd_xmp(p, cat),
    locked = FALSE,
    attachments = length(zpd_embedded_files(p, cat, limits)) > 0L,
    layout = zpd_layout(cat$PageLayout)
  )
}

#' @rdname pdftools-compat
#' @export
pdf_text <- function(pdf, opw = "", upw = "", raw = FALSE) {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  t <- as.vector(pdf_page_text(
    x$pdf,
    layout = if (isTRUE(raw)) "raw" else "reading"
  ))
  # pdftools ends every line, the last included, with a line break.
  ifelse(nzchar(t), paste0(t, "\n"), t)
}

#' @rdname pdftools-compat
#' @export
pdf_fonts <- function(pdf, opw = "", upw = "") {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  p <- x$pdf
  ft <- pdf_font_table(p)
  type <- vapply(ft$object, function(n) zpd_poppler_font_type(p, n), "")
  out <- data.frame(
    name = ifelse(is.na(ft$name), "", ft$name),
    type = type,
    embedded = ft$embedded,
    file = ifelse(ft$embedded, "", NA_character_)
  )
  class(out) <- c("tbl_df", "tbl", "data.frame")
  out
}

#' @rdname pdftools-compat
#' @export
pdf_pagesize <- function(pdf, opw = "", upw = "") {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  pg <- pdf_pages(x$pdf)
  mb <- do.call(rbind, pg$media_box)
  data.frame(
    top = mb[, 2],
    right = mb[, 3],
    bottom = mb[, 4],
    left = mb[, 1],
    width = mb[, 3] - mb[, 1],
    height = mb[, 4] - mb[, 2]
  )
}

#' @rdname pdftools-compat
#' @export
pdf_toc <- function(pdf, opw = "", upw = "") {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  p <- x$pdf
  cat <- zpd_doc_dict(p, "catalog")
  outlines <- zpd_deref(p, cat$Outlines)
  if (!is.list(outlines) || is.null(outlines$First)) {
    return(list())
  }
  seen <- new.env(parent = emptyenv())
  limit <- zpd_limits(p)$max_objects
  list(
    title = "",
    is_open = TRUE,
    children = zpd_outline_items(p, outlines$First, seen, limit, 0L)
  )
}

#' @rdname pdftools-compat
#' @export
pdf_attachments <- function(pdf, opw = "", upw = "") {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  p <- x$pdf
  cat <- zpd_doc_dict(p, "catalog")
  files <- zpd_embedded_files(p, cat, zpd_limits(p))
  lapply(files, function(f) zpd_attachment(p, f$name, f$spec))
}

#' qpdf-compatible assembly
#'
#' These functions take qpdf's arguments and do what qpdf does, so code
#' written for qpdf runs with `library(zupdf)` in place of `library(qpdf)`.
#' They are [pdf_copy_pages()] underneath: pdfio writes the output, so its
#' bytes differ from qpdf's, but its pages, their content and their order
#' are the same. Document-level parts, such as outlines and forms, are not
#' carried over. `pdf_compress()` and `pdf_overlay_stamp()` are not
#' provided.
#'
#' @param input A path (for `pdf_combine()`, paths), or an open `pdf_file`.
#' @param output The output path, or `NULL` for qpdf's default next to the
#'   input: for `pdf_split()` a prefix, to which `_1.pdf`, `_2.pdf`, ... are
#'   added.
#' @param password The password for the input, or `""`.
#' @param pages Page numbers to keep (`pdf_subset()`) or rotate
#'   (`pdf_rotate_pages()`); any R index into the pages, such as `-1`.
#' @param angle Degrees, a multiple of 90.
#' @param relative `TRUE` to add `angle` to each page's rotation, `FALSE` to
#'   set it.
#' @return `pdf_length()` the page count; the others the output path or
#'   paths, as qpdf returns them.
#' @name qpdf-compat
#' @examples
#' path <- system.file("examples", "hello.pdf", package = "zupdf")
#' pdf_length(path)
#' out <- pdf_subset(path, pages = 2, output = tempfile(fileext = ".pdf"))
#' pdf_length(out)
NULL

#' @rdname qpdf-compat
#' @export
pdf_length <- function(input, password = "") {
  x <- zpd_compat_input(input, password, sys.call())
  on.exit(x$done())
  length(x$pdf)
}

#' @rdname qpdf-compat
#' @export
pdf_split <- function(input, output = NULL, password = "") {
  call <- sys.call()
  x <- zpd_compat_input(input, password, call)
  on.exit(x$done())
  if (!length(output)) {
    output <- sub("\\.pdf$", "", x$path)
  }
  n <- length(x$pdf)
  out <- sprintf("%s_%d.pdf", output, seq_len(n))
  for (i in seq_len(n)) {
    zpd_compat_write(x$pdf, i, out[[i]], call = call)
  }
  normalizePath(out, mustWork = FALSE)
}

#' @rdname qpdf-compat
#' @export
pdf_subset <- function(input, pages = 1, output = NULL, password = "") {
  call <- sys.call()
  x <- zpd_compat_input(input, password, call)
  on.exit(x$done())
  if (!length(output)) {
    output <- sub("\\.pdf$", "_output.pdf", x$path)
  }
  output <- normalizePath(output, mustWork = FALSE)
  pages <- zpd_compat_pages(x$pdf, pages, call)
  zpd_compat_write(x$pdf, pages, output, call = call)
  output
}

#' @rdname qpdf-compat
#' @export
pdf_combine <- function(input, output = NULL, password = "") {
  call <- sys.call()
  if (inherits(input, "pdf_file")) {
    input <- list(input)
  }
  if (!length(input)) {
    zpd_invalid_argument("input", "`input` must name at least one file.", call)
  }
  opened <- lapply(input, zpd_compat_input, password = password, call = call)
  on.exit(
    for (x in opened) {
      x$done()
    }
  )
  if (!length(output)) {
    output <- sub("\\.pdf$", "_combined.pdf", opened[[1]]$path)
  }
  output <- normalizePath(output, mustWork = FALSE)
  w <- pdf_new()
  for (x in opened) {
    pdf_copy_pages(w, x$pdf)
  }
  pdf_save(w, output)
  output
}

#' @rdname qpdf-compat
#' @export
pdf_rotate_pages <- function(
  input,
  pages,
  angle = 90,
  relative = FALSE,
  output = NULL,
  password = ""
) {
  call <- sys.call()
  x <- zpd_compat_input(input, password, call)
  on.exit(x$done())
  if (!length(output)) {
    output <- sub("\\.pdf$", "_output.pdf", x$path)
  }
  output <- normalizePath(output, mustWork = FALSE)
  pages <- zpd_compat_pages(x$pdf, pages, call)
  if (
    !is.numeric(angle) ||
      length(angle) != 1L ||
      !is.finite(angle) ||
      angle %% 90 != 0
  ) {
    zpd_invalid_argument("angle", "`angle` must be a multiple of 90.", call)
  }
  w <- pdf_new()
  rot <- as.integer(angle %% 360)
  for (i in seq_len(length(x$pdf))) {
    if (i %in% pages) {
      zpd_unwrap(
        .Call(zupdf_writer_copy_pages, w, x$pdf, i, rot, !isTRUE(relative)),
        "Cannot copy the pages",
        call,
        default = "zupdf_write_error"
      )
    } else {
      pdf_copy_pages(w, x$pdf, i)
    }
  }
  pdf_save(w, output)
  output
}

# ---- shared ------------------------------------------------------------------

# Opens a pdftools-style `pdf` (path, raw vector or pdf_file) with the user
# password, else the owner password. list(pdf, done), where done() closes
# what was opened here and leaves a caller's pdf_file open.
zpd_compat_open <- function(pdf, opw, upw, call = NULL) {
  if (inherits(pdf, "pdf_file")) {
    zpd_check_open(pdf, call = call)
    return(list(pdf = pdf, done = function() NULL))
  }
  pw <- if (nzchar(upw)) {
    upw
  } else if (nzchar(opw)) {
    opw
  } else {
    NULL
  }
  p <- pdf_open(pdf, password = pw)
  list(pdf = p, done = function() pdf_close(p))
}

# A qpdf-style `input`: a path, normalised as qpdf does, or a pdf_file.
# list(pdf, path, done).
zpd_compat_input <- function(input, password = "", call = NULL) {
  if (inherits(input, "pdf_file")) {
    zpd_check_open(input, call = call)
    return(list(
      pdf = input,
      path = attr(input, "path", exact = TRUE),
      done = function() NULL
    ))
  }
  if (!is.character(input) || length(input) != 1L || is.na(input)) {
    zpd_invalid_argument("input", "input should contain exactly one file", call)
  }
  path <- normalizePath(input, mustWork = FALSE)
  p <- pdf_open(path, password = if (nzchar(password)) password else NULL)
  list(pdf = p, path = path, done = function() pdf_close(p))
}

# qpdf's page selection: any R index into the pages.
zpd_compat_pages <- function(pdf, pages, call = NULL) {
  sel <- seq_len(length(pdf))[pages]
  if (anyNA(sel) || !length(sel)) {
    zpd_invalid_argument("pages", "Selected pages out of range", call)
  }
  sel
}

zpd_compat_write <- function(pdf, pages, output, call = NULL) {
  w <- pdf_new()
  pdf_copy_pages(w, pdf, pages)
  pdf_save(w, output)
}

zpd_doc_dict <- function(pdf, which) {
  zpd_unwrap(
    .Call(zupdf_doc_dict, pdf, which, zpd_depth_int(zpd_limits(pdf)$max_depth)),
    "Cannot read the document dictionary",
    limits = zpd_limits(pdf)
  )
}

zpd_layout <- function(x) {
  map <- c(
    SinglePage = "single_page",
    OneColumn = "one_column",
    TwoColumnLeft = "two_column_left",
    TwoColumnRight = "two_column_right",
    TwoPageLeft = "two_page_left",
    TwoPageRight = "two_page_right"
  )
  v <- zpd_chr(x)
  if (is.na(v) || !v %in% names(map)) "no_layout" else map[[v]]
}

zpd_xmp <- function(pdf, cat) {
  ref <- cat$Metadata
  if (!inherits(ref, "pdf_ref")) {
    return("")
  }
  s <- tryCatch(pdf_stream(pdf, unclass(ref)[[1L]]), zupdf_error = function(e) {
    NULL
  })
  if (is.null(s) || !isTRUE(attr(s, "decoded"))) {
    return("")
  }
  s <- as.vector(s)
  s <- s[s != as.raw(0)]
  out <- rawToChar(s)
  Encoding(out) <- "UTF-8"
  out
}

zpd_linearized <- function(pdf) {
  objs <- suppressWarnings(pdf_objects(pdf))
  for (n in utils::head(objs$number, 3L)) {
    v <- tryCatch(pdf_object(pdf, n), zupdf_error = function(e) NULL)
    if (is.list(v) && "Linearized" %in% names(v)) {
      return(TRUE)
    }
  }
  FALSE
}

# poppler's font type names, as pdftools reports them.
zpd_poppler_font_type <- function(pdf, n) {
  d <- pdf_object(pdf, n)
  sub <- zpd_chr(d$Subtype)
  file_key <- function(d) {
    fd <- zpd_deref(pdf, d$FontDescriptor)
    if (!is.list(fd)) {
      return(NA_character_)
    }
    k <- intersect(c("FontFile", "FontFile2", "FontFile3"), names(fd))
    if (length(k)) k[[1]] else NA_character_
  }
  if (identical(sub, "Type0")) {
    desc <- zpd_deref(pdf, d$DescendantFonts)
    cid <- if (length(desc)) zpd_deref(pdf, desc[[1L]]) else list()
    if (identical(zpd_chr(cid$Subtype), "CIDFontType2")) {
      return("cid_truetype")
    }
    return(
      if (identical(file_key(cid), "FontFile3")) "cid_type0c" else "cid_type0"
    )
  }
  switch(
    if (is.na(sub)) "" else sub,
    Type1 = ,
    MMType1 = if (identical(file_key(d), "FontFile3")) "type1c" else "type1",
    TrueType = "truetype",
    Type3 = "type3",
    "unknown"
  )
}

# The outline items from `first` along /Next, each with its children,
# guarded against cycles and bounded by max_objects.
zpd_outline_items <- function(pdf, first, seen, limit, depth) {
  items <- list()
  ref <- first
  while (inherits(ref, "pdf_ref")) {
    key <- as.character(unclass(ref)[[1L]])
    if (!is.null(seen[[key]]) || length(ls(seen)) >= limit || depth > 64L) {
      break
    }
    assign(key, TRUE, envir = seen)
    item <- pdf_object(pdf, unclass(ref)[[1L]])
    if (!is.list(item)) {
      break
    }
    title <- if (is.character(item$Title)) item$Title[[1]] else ""
    children <- if (inherits(item$First, "pdf_ref")) {
      zpd_outline_items(pdf, item$First, seen, limit, depth + 1L)
    } else {
      list()
    }
    # A positive /Count marks an item shown open (PDF 2.0, 12.3.3).
    is_open <- is.numeric(item$Count) && item$Count > 0
    items[[length(items) + 1L]] <- list(
      title = title,
      is_open = is_open,
      children = children
    )
    ref <- item$Next
  }
  items
}

# The /EmbeddedFiles name tree's entries: list(list(name, spec)).
zpd_embedded_files <- function(pdf, cat, limits) {
  names_dict <- zpd_deref(pdf, cat$Names)
  root <- if (is.list(names_dict)) {
    zpd_deref(pdf, names_dict$EmbeddedFiles)
  } else {
    NULL
  }
  out <- list()
  seen <- new.env(parent = emptyenv())
  walk <- function(node, depth) {
    if (!is.list(node) || depth > limits$max_depth) {
      return()
    }
    nm <- zpd_deref(pdf, node$Names)
    if (is.list(nm)) {
      for (i in seq(1L, length(nm) - 1L, by = 2L)) {
        out[[length(out) + 1L]] <<- list(
          name = as.character(nm[[i]]),
          spec = nm[[i + 1L]]
        )
      }
    }
    kids <- zpd_deref(pdf, node$Kids)
    for (k in if (is.list(kids)) kids else list()) {
      key <- as.character(unclass(k)[[1L]])
      if (inherits(k, "pdf_ref") && is.null(seen[[key]])) {
        assign(key, TRUE, envir = seen)
        walk(zpd_deref(pdf, k), depth + 1L)
      }
    }
  }
  walk(root, 0L)
  out
}

zpd_attachment <- function(pdf, name, spec) {
  spec <- zpd_deref(pdf, spec)
  ef <- if (is.list(spec)) zpd_deref(pdf, spec$EF) else NULL
  ref <- if (is.list(ef)) (if (!is.null(ef$UF)) ef$UF else ef$F) else NULL
  data <- raw()
  mime <- NA_character_
  created <- modified <- .POSIXct(NA_real_)
  if (inherits(ref, "pdf_ref")) {
    n <- unclass(ref)[[1L]]
    sd <- pdf_object(pdf, n)
    mime <- zpd_chr(sd$Subtype)
    params <- zpd_deref(pdf, sd$Params)
    if (is.list(params)) {
      if (inherits(params$CreationDate, "POSIXct")) {
        created <- params$CreationDate
      }
      if (inherits(params$ModDate, "POSIXct")) modified <- params$ModDate
    }
    data <- as.vector(pdf_stream(pdf, n))
  }
  fname <- if (is.list(spec)) {
    if (is.character(spec$UF)) {
      spec$UF
    } else if (is.character(spec$F)) {
      spec$F
    } else {
      name
    }
  } else {
    name
  }
  list(
    name = fname,
    mime = mime,
    created = created,
    modified = modified,
    description = if (is.list(spec) && is.character(spec$Desc)) {
      spec$Desc
    } else {
      ""
    },
    data = data
  )
}
