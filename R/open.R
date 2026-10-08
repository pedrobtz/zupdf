#' Open a PDF file
#'
#' Opens a PDF for reading. pdfio reads the file lazily, through its
#' cross-reference table, so opening is cheap and later calls go back to
#' the file. The handle keeps the file open until [pdf_close()] or until it
#' is garbage collected.
#'
#' A PDF is a common carrier of hostile input, so opening is bounded by
#' limits. `max_size` is checked before anything is read; `max_objects` and
#' `max_pages` right after the cross-reference table is read; `max_stream`
#' and `max_depth` by the functions that decode streams and walk nested
#' values. Each limit is a positive whole number or `Inf`.
#'
#' @param x A path to a PDF file, a raw vector holding one, a connection to
#'   read one from, or an open `pdf_file`, which is returned unchanged.
#'   Raw vectors and connections are written to a temporary file, which the
#'   handle removes when it is closed.
#' @param password `NULL` for none, a string, or a function of the file
#'   name that returns one. A function is called only when the file turns
#'   out to need a password.
#' @param ... Must be empty.
#' @param max_size Largest input, in bytes.
#' @param max_objects Most objects in the cross-reference table.
#' @param max_stream Largest decoded stream, in bytes.
#' @param max_depth Deepest nesting of values, Form XObjects and the page
#'   tree.
#' @param max_pages Most pages.
#' @return A `pdf_file`. `length()` gives its page count.
#' @seealso [pdf_meta()], [pdf_pages()], [zupdf-conditions].
#' @export
#' @examples
#' path <- system.file("examples", "hello.pdf", package = "zupdf")
#' pdf <- pdf_open(path)
#' pdf
#' length(pdf)
#' pdf_close(pdf)
pdf_open <- function(
  x,
  password = NULL,
  ...,
  max_size = 1024^3,
  max_objects = 1e6,
  max_stream = 256 * 1024^2,
  max_depth = 64,
  max_pages = 1e5
) {
  call <- sys.call()
  zpd_check_dots(..., call = call)
  if (inherits(x, "pdf_file")) {
    zpd_check_open(x, call = call)
    return(x)
  }
  limits <- zpd_check_limits(
    list(
      max_size = max_size,
      max_objects = max_objects,
      max_stream = max_stream,
      max_depth = max_depth,
      max_pages = max_pages
    ),
    call = call
  )
  if (
    !is.null(password) &&
      !is.function(password) &&
      !(is.character(password) && length(password) == 1L && !is.na(password))
  ) {
    zpd_invalid_argument(
      "password",
      "`password` must be NULL, a single string or a function.",
      call = call
    )
  }

  input <- zpd_input(x, limits$max_size, call = call)
  opened <- FALSE
  if (input$owned) {
    on.exit(if (!opened) unlink(input$path), add = TRUE)
  }

  first <- if (is.function(password)) NULL else password
  res <- .Call(zupdf_open, input$path, first, input$owned)
  if (
    is.function(password) &&
      res$status == "pdfio" &&
      zpd_pdfio_class(res$detail) == "zupdf_password_error"
  ) {
    pw <- password(input$name)
    zpd_check_string(pw, "password", call = call)
    res <- .Call(zupdf_open, input$path, pw, input$owned)
  }
  ptr <- zpd_unwrap(res, "Cannot open the PDF file", call = call)
  opened <- TRUE

  pdf <- structure(
    ptr,
    path = input$name,
    source = input$source,
    limits = limits,
    class = "pdf_file"
  )
  zpd_check_counts(pdf, limits, call = call)
  pdf
}

#' Close a PDF file
#'
#' Closes the file and removes any temporary copy [pdf_open()] made. Every
#' other function refuses a closed handle. Closing twice is harmless.
#'
#' @param pdf A `pdf_file`.
#' @return `NULL`, invisibly.
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_close(pdf)
#' pdf_close(pdf)
pdf_close <- function(pdf) {
  if (!inherits(pdf, "pdf_file")) {
    zpd_invalid_argument("pdf", "`pdf` must be a pdf_file.", call = sys.call())
  }
  .Call(zupdf_close, pdf)
  invisible(NULL)
}

# ---- input ------------------------------------------------------------------

# Resolves `x` to a file pdfio can open (design section 10): list(path,
# owned, source, name). `owned` marks a temporary copy the handle removes.
zpd_input <- function(x, max_size, call = NULL) {
  if (is.raw(x)) {
    zpd_check_size(length(x), max_size, call = call)
    return(zpd_spill(x, "raw", "<raw vector>"))
  }
  if (inherits(x, "connection")) {
    name <- summary(x)$description
    bytes <- zpd_read_connection(x, max_size, call = call)
    return(zpd_spill(bytes, "connection", name))
  }
  if (is.character(x) && length(x) == 1L && !is.na(x)) {
    path <- path.expand(x)
    if (!file.exists(path) || dir.exists(path)) {
      zpd_abort(
        "zupdf_io_error",
        sprintf("Cannot open the PDF file: '%s' does not exist.", x),
        call = call
      )
    }
    zpd_check_size(file.size(path), max_size, call = call)
    return(list(path = path, owned = FALSE, source = "path", name = x))
  }
  zpd_invalid_argument(
    "x",
    "`x` must be a path, a raw vector, a connection or a pdf_file.",
    call = call
  )
}

zpd_check_size <- function(size, max_size, call = NULL) {
  if (size > max_size) {
    # GUARD: max_size
    zpd_limit_error(
      "max_size",
      max_size,
      sprintf(
        "The input is larger than `max_size` (%s bytes).",
        format(max_size, scientific = FALSE, big.mark = "")
      ),
      call = call
    )
  }
}

# Reads a connection in 1 MiB blocks, refusing it as soon as it passes
# max_size, so a large or endless stream is never held whole.
zpd_read_connection <- function(con, max_size, call = NULL) {
  if (!isOpen(con)) {
    open(con, "rb")
    on.exit(close(con), add = TRUE)
  }
  chunks <- list()
  total <- 0
  repeat {
    block <- readBin(con, "raw", n = 1048576L)
    if (length(block) == 0L) {
      break
    }
    total <- total + length(block)
    zpd_check_size(total, max_size, call = call)
    chunks[[length(chunks) + 1L]] <- block
  }
  if (length(chunks) == 0L) raw() else do.call(c, chunks)
}

zpd_spill <- function(bytes, source, name) {
  path <- tempfile("zupdf-", fileext = ".pdf")
  writeBin(bytes, path)
  list(path = path, owned = TRUE, source = source, name = name)
}

# max_objects and max_pages, checked right after the cross-reference table
# is read (design section 12). A file over either is closed before the
# condition is raised.
zpd_check_counts <- function(pdf, limits, call = NULL) {
  counts <- zpd_unwrap(.Call(zupdf_counts, pdf), "Cannot read the PDF file")
  if (counts[[1L]] > limits$max_objects) {
    # GUARD: max_objects
    zpd_count_limit(pdf, "max_objects", "objects", limits, call)
  }
  if (counts[[2L]] > limits$max_pages) {
    # GUARD: max_pages
    zpd_count_limit(pdf, "max_pages", "pages", limits, call)
  }
}

# Closes the file, then raises the limit error for `name`.
zpd_count_limit <- function(pdf, name, what, limits, call) {
  pdf_close(pdf)
  zpd_limit_error(
    name,
    limits[[name]],
    sprintf(
      "The PDF file has more %s than `%s` (%s).",
      what,
      name,
      format(limits[[name]], scientific = FALSE, big.mark = "")
    ),
    call = call
  )
}

# ---- the handle -------------------------------------------------------------

zpd_check_open <- function(pdf, call = NULL) {
  if (!inherits(pdf, "pdf_file")) {
    zpd_invalid_argument("pdf", "`pdf` must be a pdf_file.", call = call)
  }
  if (!.Call(zupdf_is_open, pdf)) {
    zpd_invalid_argument("pdf", "The PDF file is closed.", call = call)
  }
  invisible(pdf)
}

zpd_limits <- function(pdf) attr(pdf, "limits", exact = TRUE)

#' @export
length.pdf_file <- function(x) {
  zpd_check_open(x, call = sys.call())
  pages <- zpd_unwrap(.Call(zupdf_counts, x), "Cannot read the PDF file")[[2L]]
  as.integer(pages)
}

#' @export
format.pdf_file <- function(x, ...) {
  path <- attr(x, "path", exact = TRUE)
  if (!.Call(zupdf_is_open, x)) {
    return(c("<pdf_file> (closed)", paste0("  ", path)))
  }
  m <- pdf_meta(x)
  c(
    "<pdf_file>",
    paste0("  ", path),
    sprintf(
      "  PDF %s, %s page%s, %s",
      m$version,
      format(m$pages, big.mark = ""),
      if (m$pages == 1) "" else "s",
      if (m$encryption == "none") "not encrypted" else m$encryption
    )
  )
}

#' @export
print.pdf_file <- function(x, ...) {
  writeLines(format(x, ...))
  invisible(x)
}
