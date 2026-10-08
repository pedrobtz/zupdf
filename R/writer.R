#' Start a new PDF file
#'
#' Creates a writer. Add pages with [pdf_page_new()], draw on them, end each
#' with [pdf_page_end()], and finish with [pdf_save()]. Fonts and images are
#' made once with [pdf_font()] and [pdf_image_new()] and drawn on any page.
#'
#' Two things in a PDF normally come from the clock and the random source:
#' the creation date and the file identifier. The date is always `created`.
#' With `deterministic = TRUE` the identifier is a hash of the file's
#' content, so the same calls produce the same bytes, which tests and
#' reproducible builds can pin. Encrypted files are never byte-stable, since
#' their keys are random.
#'
#' @param version The PDF version to write, such as `"1.7"` or `"2.0"`.
#' @param media_box The default page size, `c(x1, y1, x2, y2)` in points;
#'   see [pdf_paper()].
#' @param created The creation date, a `POSIXct`.
#' @param deterministic `TRUE` to derive the file identifier from the
#'   content.
#' @param ... Must be empty.
#' @return A `pdf_writer`.
#' @seealso [pdf_draw_text()], [pdf_draw()], [pdf_draw_image()].
#' @export
#' @examples
#' w <- pdf_new(media_box = pdf_paper("a5"))
#' page <- pdf_page_new(w)
#' pdf_draw_text(page, 72, 500, "Hello from zupdf.", size = 18)
#' pdf_page_end(page)
#' bytes <- pdf_save(w)
#' pdf <- pdf_open(bytes)
#' pdf_page_text(pdf)
#' pdf_close(pdf)
pdf_new <- function(
  version = "2.0",
  media_box = pdf_paper("a4"),
  created = Sys.time(),
  deterministic = FALSE,
  ...
) {
  call <- sys.call()
  zpd_check_dots(..., call = call)
  if (
    !is.character(version) ||
      length(version) != 1L ||
      !grepl("^[12]\\.[0-9]$", version)
  ) {
    zpd_invalid_argument(
      "version",
      "`version` must be a PDF version such as \"1.7\" or \"2.0\".",
      call
    )
  }
  media_box <- zpd_check_box(media_box, "media_box", call = call)
  if (
    !inherits(created, "POSIXct") || length(created) != 1L || is.na(created)
  ) {
    zpd_invalid_argument("created", "`created` must be one POSIXct time.", call)
  }
  if (!isTRUE(deterministic) && !isFALSE(deterministic)) {
    zpd_invalid_argument(
      "deterministic",
      "`deterministic` must be TRUE or FALSE.",
      call
    )
  }
  ptr <- zpd_unwrap(
    .Call(zupdf_writer_new, version, media_box),
    "Cannot create the PDF file",
    call,
    default = "zupdf_write_error"
  )
  state <- new.env(parent = emptyenv())
  state$fonts <- list()
  state$open_pages <- 0L
  structure(
    ptr,
    state = state,
    created = as.numeric(created),
    deterministic = deterministic,
    class = "pdf_writer"
  )
}

#' Finish a PDF file
#'
#' Writes the trailer and returns the file's bytes, or writes them to a
#' file or connection. Every page must have been ended. The writer cannot
#' be used afterwards.
#'
#' @param w A `pdf_writer` from [pdf_new()].
#' @param file `NULL` to return the bytes, a path, or a connection.
#' @return The bytes as a raw vector when `file` is `NULL`, else `file`,
#'   invisibly.
#' @export
#' @examples
#' w <- pdf_new()
#' pdf_page_end(pdf_page_new(w))
#' length(pdf_save(w))
pdf_save <- function(w, file = NULL) {
  call <- sys.call()
  zpd_check_writer(w, call = call)
  state <- attr(w, "state", exact = TRUE)
  if (state$open_pages > 0L) {
    zpd_abort(
      "zupdf_write_error",
      sprintf(
        "%d page%s not ended; call pdf_page_end() first.",
        state$open_pages,
        if (state$open_pages == 1L) " is" else "s are"
      ),
      call = call
    )
  }
  if (
    !is.null(file) &&
      !inherits(file, "connection") &&
      !(is.character(file) && length(file) == 1L && !is.na(file))
  ) {
    zpd_invalid_argument(
      "file",
      "`file` must be NULL, a path or a connection.",
      call
    )
  }
  bytes <- zpd_unwrap(
    .Call(
      zupdf_writer_save,
      w,
      attr(w, "created", exact = TRUE),
      attr(w, "deterministic", exact = TRUE)
    ),
    "Cannot finish the PDF file",
    call,
    default = "zupdf_write_error"
  )
  if (is.null(file)) {
    return(bytes)
  }
  if (is.character(file)) {
    tryCatch(
      writeBin(bytes, file),
      error = function(e) {
        zpd_abort(
          "zupdf_io_error",
          sprintf("Cannot write '%s': %s", file, conditionMessage(e)),
          call = call
        )
      }
    )
  } else {
    if (!isOpen(file)) {
      open(file, "wb")
      on.exit(close(file), add = TRUE)
    }
    writeBin(bytes, file)
  }
  invisible(file)
}

#' Fonts for the writer
#'
#' Makes a font object a writer can draw text with. A base-14 font is named
#' (such as `"Helvetica"` or `"Times-Bold"`) and not embedded; it shows the
#' characters of Windows code page 1252 and prints `?` for others. A
#' TrueType or OpenType file is embedded, with the glyphs the text uses,
#' and shows any character it has. There is no system font lookup: give the
#' path.
#'
#' [pdf_draw_text()] also takes a base-14 name or a path directly and makes
#' the font the first time.
#'
#' @inheritParams pdf_save
#' @param x A base-14 font name or a path to a `.ttf` or `.otf` file.
#' @return A `pdf_writer_font`.
#' @export
#' @examples
#' w <- pdf_new()
#' bold <- pdf_font(w, "Helvetica-Bold")
#' page <- pdf_page_new(w)
#' pdf_draw_text(page, 72, 750, "A heading", font = bold, size = 16)
#' pdf_page_end(page)
#' bytes <- pdf_save(w)
pdf_font <- function(w, x) {
  call <- sys.call()
  zpd_check_writer(w, call = call)
  zpd_check_string(x, "x", call = call)
  zpd_writer_font(w, x, call = call)
}

zpd_base14 <- c(
  "Courier",
  "Courier-Bold",
  "Courier-BoldOblique",
  "Courier-Oblique",
  "Helvetica",
  "Helvetica-Bold",
  "Helvetica-BoldOblique",
  "Helvetica-Oblique",
  "Symbol",
  "Times-Bold",
  "Times-BoldItalic",
  "Times-Italic",
  "Times-Roman",
  "ZapfDingbats"
)

# The font for a name or path, made once per writer.
zpd_writer_font <- function(w, x, call = NULL) {
  state <- attr(w, "state", exact = TRUE)
  if (!is.null(state$fonts[[x]])) {
    return(state$fonts[[x]])
  }
  if (x %in% zpd_base14) {
    kind <- "base"
  } else if (file.exists(x) && !dir.exists(x)) {
    kind <- "file"
  } else {
    zpd_invalid_argument(
      "font",
      sprintf(
        "'%s' is neither a base-14 font name nor a font file; zupdf does not look up system fonts.",
        x
      ),
      call = call
    )
  }
  k <- zpd_unwrap(
    .Call(zupdf_writer_font, w, kind, x),
    "Cannot load the font",
    call,
    default = "zupdf_font_error"
  )
  font <- structure(
    list(writer = w, handle = k, name = x),
    class = "pdf_writer_font"
  )
  state$fonts[[x]] <- font
  font
}

#' @export
print.pdf_writer_font <- function(x, ...) {
  writeLines(sprintf("<pdf_writer_font> %s", x$name))
  invisible(x)
}

#' Images for the writer
#'
#' Makes an image object a writer can draw with [pdf_draw_image()]: from a
#' PNG or JPEG file (JPEG data is copied as it is), or from an R image: a
#' `nativeRaster`, a `raster` or character matrix of colours, a numeric
#' matrix of grey levels in 0 to 1, or a numeric array of height x width x
#' 3 (RGB) or 4 (RGBA) channels in 0 to 1, such as `png::readPNG()`
#' returns. Transparency is kept.
#'
#' @inheritParams pdf_save
#' @param x A path, or an image as above.
#' @param interpolate `TRUE` to let viewers smooth the image when scaling.
#' @return A `pdf_writer_image` with the image's `width` and `height` in
#'   pixels.
#' @export
#' @examples
#' w <- pdf_new()
#' img <- pdf_image_new(w, as.raster(matrix(c("red", "blue"), 1)))
#' page <- pdf_page_new(w)
#' pdf_draw_image(page, img, 72, 600, 200, 100)
#' pdf_page_end(page)
#' bytes <- pdf_save(w)
pdf_image_new <- function(w, x, interpolate = TRUE) {
  call <- sys.call()
  zpd_check_writer(w, call = call)
  if (!isTRUE(interpolate) && !isFALSE(interpolate)) {
    zpd_invalid_argument(
      "interpolate",
      "`interpolate` must be TRUE or FALSE.",
      call
    )
  }
  if (is.character(x) && length(x) == 1L && is.null(dim(x))) {
    if (!file.exists(x) || dir.exists(x)) {
      zpd_abort(
        "zupdf_io_error",
        sprintf("Cannot read the image: '%s' does not exist.", x),
        call = call
      )
    }
    k <- zpd_unwrap(
      .Call(zupdf_writer_image_file, w, path.expand(x), interpolate),
      "Cannot read the image",
      call
    )
    dims <- c(NA_integer_, NA_integer_)
  } else {
    img <- zpd_image_bytes(x, call = call)
    k <- zpd_unwrap(
      .Call(
        zupdf_writer_image_data,
        w,
        img$bytes,
        img$width,
        img$height,
        img$colors,
        img$alpha,
        interpolate
      ),
      "Cannot make the image",
      call
    )
    dims <- c(img$width, img$height)
  }
  structure(
    list(writer = w, handle = k, width = dims[[1]], height = dims[[2]]),
    class = "pdf_writer_image"
  )
}

#' @export
print.pdf_writer_image <- function(x, ...) {
  writeLines(sprintf("<pdf_writer_image> %s x %s", x$width, x$height))
  invisible(x)
}

# An R image as 8-bit samples, top row first: list(bytes, width, height,
# colors (1 or 3), alpha).
zpd_image_bytes <- function(x, call = NULL) {
  bad <- function() {
    zpd_invalid_argument(
      "x",
      paste(
        "`x` must be a path, a nativeRaster, a raster, a colour matrix,",
        "a grey matrix or an RGB or RGBA array."
      ),
      call = call
    )
  }
  to8 <- function(v) as.raw(round(pmin(pmax(v, 0), 1) * 255))
  if (inherits(x, "nativeRaster")) {
    h <- nrow(x)
    wd <- ncol(x)
    # A nativeRaster stores its pixels row by row, whatever its dim says,
    # each an int 0xAABBGGRR.
    v <- as.integer(x)
    r <- bitwAnd(v, 255L)
    g <- bitwAnd(bitwShiftR(v, 8L), 255L)
    b <- bitwAnd(bitwShiftR(v, 16L), 255L)
    a <- bitwAnd(bitwShiftR(v, 24L), 255L)
    bytes <- as.raw(rbind(r, g, b, a))
    return(list(
      bytes = bytes,
      width = wd,
      height = h,
      colors = 3L,
      alpha = TRUE
    ))
  }
  if (inherits(x, "raster") || (is.matrix(x) && is.character(x))) {
    m <- as.matrix(x)
    h <- nrow(m)
    wd <- ncol(m)
    rgba <- grDevices::col2rgb(as.vector(t(m)), alpha = TRUE)
    return(list(
      bytes = as.raw(rgba),
      width = wd,
      height = h,
      colors = 3L,
      alpha = TRUE
    ))
  }
  if (is.numeric(x) && is.matrix(x)) {
    return(list(
      bytes = to8(as.vector(t(x))),
      width = ncol(x),
      height = nrow(x),
      colors = 1L,
      alpha = FALSE
    ))
  }
  if (is.numeric(x) && length(dim(x)) == 3L && dim(x)[[3]] %in% c(3L, 4L)) {
    h <- dim(x)[[1]]
    wd <- dim(x)[[2]]
    ch <- dim(x)[[3]]
    # Pixel-interleaved, row by row: channel varies fastest.
    v <- aperm(x, c(3L, 2L, 1L))
    return(list(
      bytes = to8(as.vector(v)),
      width = wd,
      height = h,
      colors = 3L,
      alpha = ch == 4L
    ))
  }
  bad()
}

# ---- checks ------------------------------------------------------------------

zpd_check_writer <- function(w, call = NULL) {
  if (!inherits(w, "pdf_writer")) {
    zpd_invalid_argument("w", "`w` must be a pdf_writer.", call = call)
  }
  if (!.Call(zupdf_writer_is_open, w)) {
    zpd_abort(
      "zupdf_write_error",
      "The writer is closed: pdf_save() has been called.",
      call = call
    )
  }
  invisible(w)
}

zpd_check_box <- function(box, name, call = NULL) {
  ok <- is.numeric(box) &&
    length(box) == 4L &&
    all(is.finite(box)) &&
    box[[3]] > box[[1]] &&
    box[[4]] > box[[2]]
  if (!ok) {
    zpd_invalid_argument(
      name,
      sprintf("`%s` must be c(x1, y1, x2, y2) with x2 > x1 and y2 > y1.", name),
      call = call
    )
  }
  as.numeric(box)
}

#' @export
print.pdf_writer <- function(x, ...) {
  open <- .Call(zupdf_writer_is_open, x)
  writeLines(if (open) "<pdf_writer>" else "<pdf_writer> (saved)")
  invisible(x)
}
