# A pdf_page records its drawing operations here and writes them in one
# call at pdf_page_end() (src/zpd_writer.c explains why). The codes match
# the enum in src/zpd_writer.c.
zpd_ops <- c(
  save = 1L,
  restore = 2L,
  fill_rgb = 3L,
  stroke_rgb = 4L,
  line_width = 5L,
  move = 6L,
  line = 7L,
  curve = 8L,
  close = 9L,
  rect = 10L,
  paint = 11L,
  text = 12L,
  image = 13L
)

#' Pages for the writer
#'
#' `pdf_page_new()` starts a page; drawing functions record onto it; and
#' `pdf_page_end()` writes it, after the pages already ended. Several pages
#' may be open at once. [pdf_save()] refuses a writer with a page not
#' ended.
#'
#' @inheritParams pdf_save
#' @param media_box,crop_box The page's boxes, `c(x1, y1, x2, y2)` in
#'   points, or `NULL` for the writer's default size.
#' @param dict `NULL`, or a named list of further page dictionary entries
#'   as R values (see [pdf_object()] for the mapping), such as
#'   `list(Rotate = 90L)`.
#' @param page A `pdf_page`.
#' @return `pdf_page_new()`: a `pdf_page`. `pdf_page_end()`: the page,
#'   invisibly.
#' @export
#' @examples
#' w <- pdf_new()
#' page <- pdf_page_new(w, media_box = pdf_paper("a6"))
#' pdf_draw_text(page, 20, 380, "A small page")
#' pdf_page_end(page)
#' bytes <- pdf_save(w)
pdf_page_new <- function(w, media_box = NULL, crop_box = NULL, dict = NULL) {
  call <- sys.call()
  zpd_check_writer(w, call = call)
  if (!is.null(media_box)) {
    media_box <- zpd_check_box(media_box, "media_box", call)
  }
  if (!is.null(crop_box)) {
    crop_box <- zpd_check_box(crop_box, "crop_box", call)
  }
  if (!is.null(dict)) {
    if (!is.list(dict) || is.object(dict) || is.null(names(dict))) {
      zpd_invalid_argument("dict", "`dict` must be a named list.", call)
    }
    zpd_check_value(dict, "dict", 64L, call = call)
  }
  page <- new.env(parent = emptyenv())
  page$writer <- w
  page$media_box <- media_box
  page$crop_box <- crop_box
  page$dict <- dict
  page$ops <- integer()
  page$nums <- numeric()
  page$strs <- character()
  page$ended <- FALSE
  state <- attr(w, "state", exact = TRUE)
  state$open_pages <- state$open_pages + 1L
  class(page) <- "pdf_page"
  page
}

#' @rdname pdf_page_new
#' @export
pdf_page_end <- function(page) {
  call <- sys.call()
  zpd_check_page(page, call = call)
  w <- page$writer
  zpd_unwrap(
    .Call(
      zupdf_writer_page,
      w,
      page$media_box,
      page$crop_box,
      page$dict,
      page$ops,
      page$nums,
      page$strs,
      64L
    ),
    "Cannot write the page",
    call,
    default = "zupdf_write_error",
    limits = list(max_depth = 64L)
  )
  page$ended <- TRUE
  state <- attr(w, "state", exact = TRUE)
  state$open_pages <- state$open_pages - 1L
  invisible(page)
}

#' @export
print.pdf_page <- function(x, ...) {
  writeLines(sprintf(
    "<pdf_page> %d operation%s%s",
    length(x$ops),
    if (length(x$ops) == 1L) "" else "s",
    if (x$ended) ", ended" else ""
  ))
  invisible(x)
}

zpd_check_page <- function(page, call = NULL) {
  if (!inherits(page, "pdf_page")) {
    zpd_invalid_argument("page", "`page` must be a pdf_page.", call = call)
  }
  if (page$ended) {
    zpd_abort(
      "zupdf_write_error",
      "The page has been ended; start a new one with pdf_page_new().",
      call = call
    )
  }
  zpd_check_writer(page$writer, call = call)
}

zpd_record <- function(page, op, nums = numeric(), str = NULL) {
  page$ops <- c(page$ops, zpd_ops[[op]])
  page$nums <- c(page$nums, nums)
  if (!is.null(str)) {
    page$strs <- c(page$strs, str)
  }
}

# A colour as three numbers in 0 to 1, or NULL for none ("transparent",
# NA or NULL). Alpha is not kept.
zpd_rgb <- function(colour, arg, call = NULL) {
  if (is.null(colour)) {
    return(NULL)
  }
  if (length(colour) != 1L) {
    zpd_invalid_argument(arg, sprintf("`%s` must be one colour.", arg), call)
  }
  if (is.na(colour) || identical(colour, "transparent")) {
    return(NULL)
  }
  rgb <- tryCatch(grDevices::col2rgb(colour), error = function(e) NULL)
  if (is.null(rgb)) {
    zpd_invalid_argument(
      arg,
      sprintf("`%s` is not a colour R knows.", arg),
      call
    )
  }
  as.numeric(rgb) / 255
}

zpd_check_numbers <- function(x, name, call = NULL) {
  if (!is.numeric(x) || length(x) < 1L || !all(is.finite(x))) {
    zpd_invalid_argument(
      name,
      sprintf("`%s` must be finite numbers.", name),
      call = call
    )
  }
  as.numeric(x)
}

#' Draw text
#'
#' Draws text on a page with its baseline starting at (`x`, `y`), in PDF
#' points from the bottom left. `x`, `y` and `text` are recycled, so one
#' call can draw many strings; a string with line breaks is drawn as lines
#' `line_height` times the size apart. zupdf does not wrap text.
#'
#' @param page A `pdf_page` from [pdf_page_new()].
#' @param x,y The start of the baseline, in points.
#' @param text The text, UTF-8.
#' @param font A base-14 font name, a font file path, or a font from
#'   [pdf_font()].
#' @param size The font size in points.
#' @param ... Must be empty.
#' @param colour The text colour, any colour R knows.
#' @param align `"left"`, `"centre"` or `"right"`: where `x` is on the line.
#' @param line_height The distance between lines, in multiples of `size`.
#' @return `page`, invisibly.
#' @export
#' @examples
#' w <- pdf_new()
#' page <- pdf_page_new(w)
#' pdf_draw_text(page, 297, 800, "Centred", size = 20, align = "centre")
#' pdf_draw_text(page, 72, 700, "Two\nlines", colour = "navy")
#' pdf_page_end(page)
#' bytes <- pdf_save(w)
pdf_draw_text <- function(
  page,
  x,
  y,
  text,
  font = "Helvetica",
  size = 12,
  ...,
  colour = "black",
  align = c("left", "centre", "right"),
  line_height = 1.2
) {
  call <- sys.call()
  zpd_check_page(page, call = call)
  zpd_check_dots(..., call = call)
  x <- zpd_check_numbers(x, "x", call)
  y <- zpd_check_numbers(y, "y", call)
  if (!is.character(text) || length(text) < 1L || anyNA(text)) {
    zpd_invalid_argument("text", "`text` must be strings, not NA.", call)
  }
  size <- zpd_check_numbers(size, "size", call)
  line_height <- zpd_check_numbers(line_height, "line_height", call)
  if (length(size) != 1L || size <= 0) {
    zpd_invalid_argument("size", "`size` must be one positive number.", call)
  }
  align <- zpd_match_arg(align, c("left", "centre", "right"), "align", call)
  rgb <- zpd_rgb(colour, "colour", call)
  font <- zpd_font_arg(page$writer, font, call)

  n <- max(length(x), length(y), length(text))
  x <- rep_len(x, n)
  y <- rep_len(y, n)
  text <- rep_len(enc2utf8(text), n)
  shift <- c(left = 0, centre = 1, right = 2)[[align]]
  zpd_record(page, "save")
  if (!is.null(rgb)) {
    zpd_record(page, "fill_rgb", rgb)
  }
  for (i in seq_len(n)) {
    lines <- strsplit(text[[i]], "\n", fixed = TRUE)[[1]]
    for (j in seq_along(lines)) {
      yy <- y[[i]] - (j - 1) * size * line_height
      zpd_record(
        page,
        "text",
        c(font$handle, size, x[[i]], yy, shift),
        lines[[j]]
      )
    }
  }
  zpd_record(page, "restore")
  invisible(page)
}

zpd_font_arg <- function(w, font, call = NULL) {
  if (inherits(font, "pdf_writer_font")) {
    if (!identical(font$writer, w)) {
      zpd_invalid_argument("font", "The font belongs to another writer.", call)
    }
    return(font)
  }
  zpd_check_string(font, "font", call = call)
  zpd_writer_font(w, font, call = call)
}

#' Draw paths
#'
#' Draws a path and fills it, strokes it, or both. A path is either points,
#' joined by straight lines (a data frame or list with `x` and `y`), or a
#' data frame of operations: column `op` is one of `"move"`, `"line"`,
#' `"curve"`, `"close"` or `"rect"`; `"move"` and `"line"` use `x` and `y`;
#' `"curve"` draws a cubic Bezier curve through control points `x1`, `y1`
#' and `x2`, `y2` to `x`, `y`; `"rect"` draws a rectangle with corner `x`,
#' `y` and size `w`, `h`. Coordinates are PDF points from the bottom left.
#'
#' @inheritParams pdf_draw_text
#' @param path The path, as above.
#' @param fill,stroke Colours, or `NULL` for none. With neither, the path is
#'   stroked in black.
#' @param width The line width in points.
#' @param close `TRUE` to close a path given as points.
#' @param rule The fill rule, `"winding"` or `"evenodd"`.
#' @return `page`, invisibly.
#' @export
#' @examples
#' w <- pdf_new()
#' page <- pdf_page_new(w)
#' pdf_draw(page, list(x = c(72, 300, 186), y = c(600, 600, 750)),
#'   fill = "gold", stroke = "black", close = TRUE)
#' pdf_draw(page, data.frame(op = "rect", x = 72, y = 400, w = 200, h = 100),
#'   fill = "steelblue")
#' pdf_page_end(page)
#' bytes <- pdf_save(w)
pdf_draw <- function(
  page,
  path,
  fill = NULL,
  stroke = NULL,
  width = 1,
  ...,
  close = FALSE,
  rule = c("winding", "evenodd")
) {
  call <- sys.call()
  zpd_check_page(page, call = call)
  zpd_check_dots(..., call = call)
  fill <- zpd_rgb(fill, "fill", call)
  stroke <- if (is.null(fill) && is.null(stroke)) {
    c(0, 0, 0)
  } else {
    zpd_rgb(stroke, "stroke", call)
  }
  width <- zpd_check_numbers(width, "width", call)
  if (length(width) != 1L || width < 0) {
    zpd_invalid_argument(
      "width",
      "`width` must be one number, 0 or more.",
      call
    )
  }
  rule <- zpd_match_arg(rule, c("winding", "evenodd"), "rule", call)
  if (!isTRUE(close) && !isFALSE(close)) {
    zpd_invalid_argument("close", "`close` must be TRUE or FALSE.", call)
  }
  steps <- zpd_path_steps(path, close, call)

  zpd_record(page, "save")
  if (!is.null(fill)) {
    zpd_record(page, "fill_rgb", fill)
  }
  if (!is.null(stroke)) {
    zpd_record(page, "stroke_rgb", stroke)
  }
  zpd_record(page, "line_width", width)
  for (s in steps) {
    zpd_record(page, s$op, s$nums)
  }
  mode <- (!is.null(fill)) + 2L * (!is.null(stroke))
  zpd_record(page, "paint", c(mode, rule == "evenodd"))
  zpd_record(page, "restore")
  invisible(page)
}

# A path as a list of steps, list(op, nums), checked.
zpd_path_steps <- function(path, close, call = NULL) {
  bad <- function(what) {
    zpd_invalid_argument("path", paste0("`path` ", what), call)
  }
  if (!is.list(path) || is.null(path$x) || is.null(path$y)) {
    bad("must be points (x and y) or a data frame of operations (op).")
  }
  num <- function(v, name) {
    if (is.null(v) || !is.numeric(v)) {
      bad(sprintf("needs a numeric column `%s`.", name))
    }
    v
  }
  x <- num(path$x, "x")
  y <- num(path$y, "y")
  if (length(x) != length(y)) {
    bad("must have as many y as x.")
  }
  if (is.null(path$op)) {
    if (length(x) < 2L || !all(is.finite(c(x, y)))) {
      bad("must have two or more finite points.")
    }
    steps <- c(
      list(list(op = "move", nums = c(x[[1]], y[[1]]))),
      lapply(seq_along(x)[-1], function(i) {
        list(op = "line", nums = c(x[[i]], y[[i]]))
      })
    )
    if (close) {
      steps <- c(steps, list(list(op = "close", nums = numeric())))
    }
    return(steps)
  }
  op <- as.character(path$op)
  if (
    length(op) != length(x) ||
      anyNA(op) ||
      !all(op %in% c("move", "line", "curve", "close", "rect"))
  ) {
    bad("has an `op` that is not move, line, curve, close or rect.")
  }
  if (op[[1]] %in% c("line", "curve", "close")) {
    bad("must start with move or rect.")
  }
  finite <- function(v, i, name) {
    if (!is.finite(v[[i]])) {
      bad(sprintf("row %d needs a finite `%s`.", i, name))
    }
    v[[i]]
  }
  lapply(seq_along(op), function(i) {
    switch(
      op[[i]],
      move = ,
      line = list(op = op[[i]], nums = c(finite(x, i, "x"), finite(y, i, "y"))),
      close = list(op = "close", nums = numeric()),
      curve = {
        x1 <- num(path$x1, "x1")
        y1 <- num(path$y1, "y1")
        x2 <- num(path$x2, "x2")
        y2 <- num(path$y2, "y2")
        list(
          op = "curve",
          nums = c(
            finite(x1, i, "x1"),
            finite(y1, i, "y1"),
            finite(x2, i, "x2"),
            finite(y2, i, "y2"),
            finite(x, i, "x"),
            finite(y, i, "y")
          )
        )
      },
      rect = {
        w <- num(path$w, "w")
        h <- num(path$h, "h")
        list(
          op = "rect",
          nums = c(
            finite(x, i, "x"),
            finite(y, i, "y"),
            finite(w, i, "w"),
            finite(h, i, "h")
          )
        )
      }
    )
  })
}

#' Draw images
#'
#' Draws an image from [pdf_image_new()] into the rectangle with its lower
#' left corner at (`x`, `y`), `width` by `height` points.
#'
#' @inheritParams pdf_draw_text
#' @param image A `pdf_writer_image`.
#' @param width,height The size on the page, in points.
#' @return `page`, invisibly.
#' @export
#' @examples
#' w <- pdf_new()
#' img <- pdf_image_new(w, matrix(seq(0, 1, length.out = 16), 4))
#' page <- pdf_page_new(w)
#' pdf_draw_image(page, img, 72, 500, 144, 144)
#' pdf_page_end(page)
#' bytes <- pdf_save(w)
pdf_draw_image <- function(page, image, x, y, width, height) {
  call <- sys.call()
  zpd_check_page(page, call = call)
  if (!inherits(image, "pdf_writer_image")) {
    zpd_invalid_argument("image", "`image` must be from pdf_image_new().", call)
  }
  if (!identical(image$writer, page$writer)) {
    zpd_invalid_argument("image", "The image belongs to another writer.", call)
  }
  v <- c(
    zpd_check_numbers(x, "x", call),
    zpd_check_numbers(y, "y", call),
    zpd_check_numbers(width, "width", call),
    zpd_check_numbers(height, "height", call)
  )
  if (length(v) != 4L) {
    zpd_invalid_argument(
      "x",
      "`x`, `y`, `width` and `height` must be single numbers.",
      call
    )
  }
  zpd_record(page, "image", c(image$handle, v))
  invisible(page)
}

#' Measure text
#'
#' The width of each string in points, as [pdf_draw_text()] would draw it
#' in `font` at `size`: from the base-14 metrics or the embedded font's
#' glyphs. zupdf does no text layout; this is what layout needs, such as
#' wrapping a paragraph to a column.
#'
#' @inheritParams pdf_font
#' @param text Strings, UTF-8.
#' @param font A base-14 font name, a font file path, or a font from
#'   [pdf_font()].
#' @param size The font size in points.
#' @return A numeric vector of widths in points.
#' @export
#' @examples
#' w <- pdf_new()
#' pdf_text_width(w, c("narrow", "a much wider string"), size = 12)
pdf_text_width <- function(w, text, font = "Helvetica", size = 12) {
  call <- sys.call()
  zpd_check_writer(w, call = call)
  if (!is.character(text) || anyNA(text)) {
    zpd_invalid_argument("text", "`text` must be strings, not NA.", call)
  }
  size <- zpd_check_numbers(size, "size", call)
  if (length(size) != 1L || size <= 0) {
    zpd_invalid_argument("size", "`size` must be one positive number.", call)
  }
  font <- zpd_font_arg(w, font, call)
  zpd_unwrap(
    .Call(zupdf_writer_measure, w, font$handle, enc2utf8(text), size),
    "Cannot measure the text",
    call,
    default = "zupdf_write_error"
  )
}
