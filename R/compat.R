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
#' * `pdf_info()` and `pdf_attachments()` report an absent date as `NA`,
#'   where pdftools reports one second before 1970.
#' * `pdf_attachments()` names an attachment whose file specification has
#'   no file name by its key in the name tree, where pdftools reports `""`.
#'
#' [pdf_data()] has its own page. `pdf_render_page()`, `pdf_convert()` and
#' the OCR functions need a renderer and are not provided.
#'
#' @param pdf A path, a raw vector, or an open `pdf_file`.
#' @param opw,upw The owner and user passwords; `""` for none. The user
#'   password is tried first, then the owner password.
#' @param raw For `pdf_text()`: `TRUE` for the text in content-stream
#'   order.
#' @return As pdftools: `pdf_info()` a list of `version`, `pages`,
#'   `encrypted`, `linearized`, `keys`, `created`, `modified`, `metadata`,
#'   `locked`, `attachments` and `layout`; `pdf_text()` one string per
#'   page; `pdf_fonts()` a data frame of `name`, `type`, `embedded` and
#'   `file`; `pdf_pagesize()` a data frame of `top`, `right`, `bottom`,
#'   `left`, `width` and `height`; `pdf_toc()` a nested list of `title`,
#'   `is_open` and `children`; `pdf_attachments()` a list of attachments,
#'   each with `name`, `mime`, `created`, `modified`, `description` and
#'   `data`.
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
  catalog <- zpd_doc_dict(p, "catalog")
  keys <- info[!names(info) %in% c("CreationDate", "ModDate")]
  keys <- keys[vapply(
    keys,
    function(v) is.character(v) && length(v) == 1L,
    TRUE
  )]
  keys <- lapply(keys, as.character)
  as_local_time <- function(x) .POSIXct(as.numeric(x), tz = "")
  list(
    version = m$version,
    pages = m$pages,
    encrypted = m$encryption != "none",
    linearized = zpd_linearized(p),
    keys = keys,
    created = as_local_time(m$created),
    modified = as_local_time(m$modified),
    metadata = zpd_xmp(p, catalog),
    locked = FALSE,
    attachments = length(zpd_embedded_files(p, catalog, limits)) > 0L,
    layout = zpd_layout(zpd_key(catalog, "PageLayout"))
  )
}

#' @rdname pdftools-compat
#' @export
pdf_text <- function(pdf, opw = "", upw = "", raw = FALSE) {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  text <- as.vector(pdf_page_text(
    x$pdf,
    layout = if (isTRUE(raw)) "raw" else "reading"
  ))
  # pdftools ends every line, the last included, with a line break.
  ifelse(nzchar(text), paste0(text, "\n"), text)
}

#' @rdname pdftools-compat
#' @export
pdf_fonts <- function(pdf, opw = "", upw = "") {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  p <- x$pdf
  ft <- pdf_font_table(p)
  # A font pdf_font_table() could not read (embedded NA) has warned already.
  type <- vapply(
    seq_along(ft$object),
    function(k) {
      if (is.na(ft$embedded[[k]])) {
        "unknown"
      } else {
        zpd_poppler_font_type(p, ft$object[[k]])
      }
    },
    ""
  )
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
  catalog <- zpd_doc_dict(p, "catalog")
  outlines <- zpd_deref(p, zpd_key(catalog, "Outlines"))
  first <- zpd_key(outlines, "First")
  if (is.null(first)) {
    return(list())
  }
  list(
    title = "",
    is_open = TRUE,
    children = zpd_outline(p, first, zpd_limits(p))
  )
}

#' @rdname pdftools-compat
#' @export
pdf_attachments <- function(pdf, opw = "", upw = "") {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  p <- x$pdf
  catalog <- zpd_doc_dict(p, "catalog")
  files <- zpd_embedded_files(p, catalog, zpd_limits(p))
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
#'   (first) input: its name without `.pdf`, in any case, followed by
#'   `_output.pdf` (`pdf_combine()`: `_combined.pdf`). For `pdf_split()` a
#'   prefix, to which `_1.pdf`, `_2.pdf`, ... are added. An output that
#'   would overwrite an input is refused, and a `pdf_file` read from a raw
#'   vector or a connection needs an explicit `output`.
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
  x <- zpd_compat_input(input, password, call = call)
  on.exit(x$done())
  output <- zpd_compat_output(
    output,
    list(x),
    "",
    call = call,
    normalise = FALSE
  )
  n <- length(x$pdf)
  out <- normalizePath(
    sprintf("%s_%d.pdf", output, seq_len(n)),
    mustWork = FALSE
  )
  zpd_compat_not_input(out, list(x), call = call)
  for (i in seq_len(n)) {
    zpd_compat_write(x$pdf, i, out[[i]])
  }
  out
}

#' @rdname qpdf-compat
#' @export
pdf_subset <- function(input, pages = 1, output = NULL, password = "") {
  call <- sys.call()
  x <- zpd_compat_input(input, password, call = call)
  on.exit(x$done())
  output <- zpd_compat_output(output, list(x), "_output.pdf", call = call)
  pages <- zpd_compat_pages(x$pdf, pages, call = call)
  zpd_compat_write(x$pdf, pages, output)
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
    zpd_invalid_argument(
      "input",
      "`input` must name at least one file.",
      call = call
    )
  }
  opened <- lapply(input, zpd_compat_input, password = password, call = call)
  on.exit(
    for (x in opened) {
      x$done()
    }
  )
  output <- zpd_compat_output(output, opened, "_combined.pdf", call = call)
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
  x <- zpd_compat_input(input, password, call = call)
  on.exit(x$done())
  output <- zpd_compat_output(output, list(x), "_output.pdf", call = call)
  pages <- zpd_compat_pages(x$pdf, pages, call = call)
  if (
    !is.numeric(angle) ||
      length(angle) != 1L ||
      !is.finite(angle) ||
      angle %% 90 != 0
  ) {
    zpd_invalid_argument(
      "angle",
      "`angle` must be a multiple of 90.",
      call = call
    )
  }
  w <- pdf_new()
  rot <- as.integer(angle %% 360)
  for (i in seq_len(length(x$pdf))) {
    if (i %in% pages) {
      zpd_unwrap(
        .Call(zupdf_writer_copy_pages, w, x$pdf, i, rot, !isTRUE(relative)),
        "Cannot copy the pages",
        call = call,
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
# password and, if that is refused, the owner password (design section
# 5.1). list(pdf, done), where done() closes what was opened here and
# leaves a caller's pdf_file open.
zpd_compat_open <- function(pdf, opw, upw, call = NULL) {
  if (inherits(pdf, "pdf_file")) {
    zpd_check_open(pdf, call = call)
    return(list(pdf = pdf, done = function() NULL))
  }
  zpd_check_string(opw, "opw", call = call)
  zpd_check_string(upw, "upw", call = call)
  pw <- unique(c(upw, opw)[nzchar(c(upw, opw))])
  if (length(pw) > 1L && inherits(pdf, "connection")) {
    # A second try needs the bytes again.
    pdf <- zpd_read_connection(pdf, zpd_default_limits()$max_size, call = call)
  }
  p <- tryCatch(
    pdf_open(pdf, password = if (length(pw)) pw[[1L]]),
    zupdf_password_error = function(e) {
      if (length(pw) < 2L) {
        stop(e)
      }
      pdf_open(pdf, password = pw[[2L]])
    }
  )
  list(pdf = p, done = function() pdf_close(p))
}

# A qpdf-style `input`: a path, normalised as qpdf does, or a pdf_file.
# list(pdf, path, done); `path` is NULL for a pdf_file read from a raw
# vector or a connection, which has no file of its own.
zpd_compat_input <- function(input, password = "", call = NULL) {
  if (inherits(input, "pdf_file")) {
    zpd_check_open(input, call = call)
    path <- if (identical(attr(input, "source", exact = TRUE), "path")) {
      normalizePath(attr(input, "path", exact = TRUE), mustWork = FALSE)
    }
    return(list(pdf = input, path = path, done = function() NULL))
  }
  if (!is.character(input) || length(input) != 1L || is.na(input)) {
    # qpdf's own message, word for word, as is "Selected pages out of range".
    zpd_invalid_argument(
      "input",
      "input should contain exactly one file",
      call = call
    )
  }
  path <- normalizePath(input, mustWork = FALSE)
  p <- pdf_open(path, password = if (nzchar(password)) password else NULL)
  list(pdf = p, path = path, done = function() pdf_close(p))
}

# The output path: `output` if given, else qpdf's default next to the first
# input, its name without ".pdf" (in any case) and with `suffix` added. An
# input with no file of its own has no default, and no output may be one
# of the inputs, which are still being read.
zpd_compat_output <- function(output, inputs, suffix, call, normalise = TRUE) {
  if (length(output)) {
    zpd_check_string(output, "output", call = call)
  } else {
    path <- inputs[[1L]]$path
    if (is.null(path)) {
      zpd_invalid_argument(
        "output",
        "`output` is needed for a PDF read from memory.",
        call = call
      )
    }
    output <- paste0(sub("\\.pdf$", "", path, ignore.case = TRUE), suffix)
  }
  if (!normalise) {
    return(output)
  }
  output <- normalizePath(output, mustWork = FALSE)
  zpd_compat_not_input(output, inputs, call = call)
  output
}

zpd_compat_not_input <- function(output, inputs, call) {
  paths <- unlist(lapply(inputs, `[[`, "path"))
  if (any(output %in% paths)) {
    zpd_invalid_argument(
      "output",
      "`output` must not overwrite an input.",
      call = call
    )
  }
}

# qpdf's page selection: any R index into the pages.
zpd_compat_pages <- function(pdf, pages, call = NULL) {
  sel <- seq_len(length(pdf))[pages]
  if (anyNA(sel) || !length(sel)) {
    zpd_invalid_argument("pages", "Selected pages out of range", call = call)
  }
  sel
}

zpd_compat_write <- function(pdf, pages, output) {
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

# The XMP stream's text. A damaged or missing stream is "" (poppler's
# answer), but a limit is the caller's and is raised, as everywhere else.
zpd_xmp <- function(pdf, catalog) {
  ref <- zpd_key(catalog, "Metadata")
  if (!inherits(ref, "pdf_ref")) {
    return("")
  }
  s <- zpd_or_null(pdf_stream(pdf, unclass(ref)[[1L]]))
  if (is.null(s) || !isTRUE(attr(s, "decoded"))) {
    return("")
  }
  s <- as.vector(s)
  s <- s[s != as.raw(0)]
  out <- rawToChar(s)
  Encoding(out) <- "UTF-8"
  out
}

# `expr`'s value, or NULL when it fails with a zupdf_error. A limit error
# is raised all the same: the limit is the caller's, not a fault of the
# file, and a value read past it would be wrong without a word.
zpd_or_null <- function(expr) {
  tryCatch(expr, zupdf_error = function(e) {
    if (inherits(e, "zupdf_limit_error")) {
      stop(e)
    }
    NULL
  })
}

# Whether one of the first objects is a linearisation dictionary. An object
# that cannot be read is not one, but a limit is raised, as in zpd_xmp().
zpd_linearized <- function(pdf) {
  objs <- suppressWarnings(pdf_objects(pdf))
  for (n in utils::head(objs$number, 3L)) {
    v <- zpd_or_null(pdf_object(pdf, n))
    if (is.list(v) && "Linearized" %in% names(v)) {
      return(TRUE)
    }
  }
  FALSE
}

# poppler's font type names, as pdftools reports them: the font's subtype,
# refined by its font file as poppler does. A FontFile2 makes a CID font
# TrueType; a FontFile3 of subtype Type1C or CIDFontType0C makes it CFF,
# and one of subtype OpenType adds "_ot". Checked against pdftools in
# test-compat.R.
zpd_poppler_font_type <- function(pdf, n) {
  d <- pdf_object(pdf, n)
  subtype <- zpd_chr(zpd_key(d, "Subtype"))
  cid <- identical(subtype, "Type0")
  if (cid) {
    desc <- zpd_deref(pdf, zpd_key(d, "DescendantFonts"))
    d <- if (is.list(desc) && length(desc)) zpd_deref(pdf, desc[[1L]])
    two <- identical(zpd_chr(zpd_key(d, "Subtype")), "CIDFontType2")
    type <- if (two) "cid_truetype" else "cid_type0"
  } else {
    type <- switch(
      if (is.na(subtype)) "" else subtype,
      Type1 = ,
      MMType1 = "type1",
      TrueType = "truetype",
      Type3 = return("type3"),
      return("unknown")
    )
  }
  fd <- zpd_deref(pdf, zpd_key(d, "FontDescriptor"))
  key <- intersect(c("FontFile", "FontFile2", "FontFile3"), names(fd))
  key <- if (is.list(fd) && length(key)) key[[1L]] else ""
  if (key == "FontFile2" && cid) {
    return("cid_truetype")
  }
  if (key != "FontFile3") {
    return(type)
  }
  # A stream object's value is its dictionary.
  ff <- zpd_deref(pdf, zpd_key(fd, "FontFile3"))
  ff_sub <- zpd_chr(zpd_key(ff, "Subtype"))
  if (ff_sub %in% c("Type1C", "CIDFontType0C")) {
    if (cid) "cid_type0c" else "type1c"
  } else if (ff_sub %in% "OpenType") {
    c(
      type1 = "type1c_ot",
      truetype = "truetype_ot",
      cid_type0 = "cid_type0c_ot",
      cid_truetype = "cid_truetype_ot"
    )[[type]]
  } else {
    type
  }
}

# The outline items from `first` along /Next, each with its children. A
# cycle ends a list, and the walk stops after max_objects items or below
# max_depth levels. It keeps its own stack rather than recursing, so a
# deep outline under a large max_depth cannot overflow R's.
zpd_outline <- function(pdf, first, limits) {
  seen <- new.env(parent = emptyenv())
  title <- character()
  is_open <- logical()
  parent <- integer()
  n <- 0L
  # Lists still to walk: each from `ref`, `depth` levels down, under item
  # `under` (0 for the top level).
  todo <- list(list(ref = first, depth = 0L, under = 0L))
  top <- 1L
  while (top > 0L) {
    job <- todo[[top]]
    top <- top - 1L
    ref <- job$ref
    while (inherits(ref, "pdf_ref")) {
      key <- as.character(unclass(ref)[[1L]])
      if (
        !is.null(seen[[key]]) ||
          n >= limits$max_objects ||
          job$depth > limits$max_depth
      ) {
        break
      }
      assign(key, TRUE, envir = seen)
      item <- pdf_object(pdf, unclass(ref)[[1L]])
      if (!is.list(item)) {
        break
      }
      n <- n + 1L
      item_title <- zpd_key(item, "Title")
      title[[n]] <- if (is.character(item_title) && length(item_title)) {
        item_title[[1L]]
      } else {
        ""
      }
      # A positive /Count marks an item shown open (PDF 2.0, 12.3.3).
      count <- zpd_key(item, "Count")
      is_open[[n]] <- is.numeric(count) && isTRUE(count[[1L]] > 0)
      parent[[n]] <- job$under
      child <- zpd_key(item, "First")
      if (inherits(child, "pdf_ref")) {
        top <- top + 1L
        todo[[top]] <- list(ref = child, depth = job$depth + 1L, under = n)
      }
      ref <- zpd_key(item, "Next")
    }
  }
  # Children come after their parent and in order, so building from the
  # last item back finds every item's children already built.
  kids <- split(seq_len(n), factor(parent, levels = 0:n))
  built <- vector("list", n)
  for (i in rev(seq_len(n))) {
    built[[i]] <- list(
      title = title[[i]],
      is_open = is_open[[i]],
      children = built[kids[[i + 1L]]]
    )
  }
  built[kids[[1L]]]
}

# The /EmbeddedFiles name tree's entries, in order: list(list(name, spec)).
# Like zpd_outline(), it keeps its own stack.
zpd_embedded_files <- function(pdf, catalog, limits) {
  names_dict <- zpd_deref(pdf, zpd_key(catalog, "Names"))
  root <- zpd_key(names_dict, "EmbeddedFiles")
  out <- list()
  k <- 0L
  seen <- new.env(parent = emptyenv())
  todo <- list(list(node = root, depth = 0L))
  top <- 1L
  while (top > 0L) {
    job <- todo[[top]]
    top <- top - 1L
    node <- zpd_deref(pdf, job$node)
    if (!is.list(node) || job$depth > limits$max_depth) {
      next
    }
    nm <- zpd_deref(pdf, zpd_key(node, "Names"))
    if (is.list(nm)) {
      # Key and value pairs; an odd last key has no value and is dropped.
      for (i in seq_len(length(nm) %/% 2L) * 2L - 1L) {
        k <- k + 1L
        out[[k]] <- list(name = zpd_chr(nm[[i]]), spec = nm[[i + 1L]])
      }
    }
    kids <- zpd_deref(pdf, zpd_key(node, "Kids"))
    fresh <- list()
    for (kid in if (is.list(kids)) kids else list()) {
      if (!inherits(kid, "pdf_ref")) {
        next
      }
      key <- as.character(unclass(kid)[[1L]])
      if (is.null(seen[[key]])) {
        assign(key, TRUE, envir = seen)
        fresh[[length(fresh) + 1L]] <- kid
      }
    }
    # Pushed last first, so the first kid is walked next.
    for (kid in rev(fresh)) {
      top <- top + 1L
      todo[[top]] <- list(node = kid, depth = job$depth + 1L)
    }
  }
  out
}

# One attachment as pdftools reports it: `name` is the name tree's key for
# the file specification `spec`.
zpd_attachment <- function(pdf, name, spec) {
  # A text entry: a string, not a name or anything else.
  text <- function(x) {
    if (is.character(x) && length(x) == 1L && !inherits(x, "pdf_name")) x
  }
  date <- function(x) if (inherits(x, "POSIXct")) x else .POSIXct(NA_real_)
  spec <- zpd_deref(pdf, spec)
  ef <- zpd_deref(pdf, zpd_key(spec, "EF"))
  ref <- zpd_key(ef, "UF")
  if (is.null(ref)) {
    ref <- zpd_key(ef, "F")
  }
  data <- raw()
  mime <- ""
  created <- modified <- .POSIXct(NA_real_)
  if (inherits(ref, "pdf_ref")) {
    n <- unclass(ref)[[1L]]
    sd <- pdf_object(pdf, n)
    subtype <- zpd_key(sd, "Subtype")
    if (is.character(subtype) && length(subtype) == 1L) {
      mime <- as.character(subtype)
    }
    params <- zpd_deref(pdf, zpd_key(sd, "Params"))
    created <- date(zpd_key(params, "CreationDate"))
    modified <- date(zpd_key(params, "ModDate"))
    data <- as.vector(pdf_stream(pdf, n))
  }
  fname <- text(zpd_key(spec, "UF"))
  if (is.null(fname)) {
    fname <- text(zpd_key(spec, "F"))
  }
  if (is.null(fname)) {
    fname <- if (is.na(name)) "" else name
  }
  desc <- text(zpd_key(spec, "Desc"))
  if (is.null(desc)) {
    desc <- ""
  }
  list(
    name = fname,
    mime = mime,
    created = created,
    modified = modified,
    description = desc,
    data = data
  )
}
