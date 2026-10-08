#' Words and their positions
#'
#' pdftools's `pdf_data()`: one data frame per page, a row per word, with
#' the word's box and whether a space follows it. Words come from zupdf's
#' text walk ([pdf_page_text()]): glyphs on one baseline, in their writing
#' direction, split at spaces and at gaps of a word space or more, in
#' reading order. Boxes are in points from the top left, as pdftools gives
#' them, each rounded to whole points: the box around the word's glyphs,
#' each glyph its advance from the font's descent to its ascent (from the
#' font descriptor, a Type 3 font's bounding box, or the base-14 metrics).
#' They agree with poppler's to within a point or two.
#'
#' @inheritParams pdftools-compat
#' @param font_info `TRUE` to add each word's `font_name` and `font_size`.
#' @return A list with a data frame per page, with columns `width`,
#'   `height`, `x`, `y`, `space` and `text`, and with `font_info`,
#'   `font_name` and `font_size`.
#' @export
#' @examples
#' path <- system.file("examples", "hello.pdf", package = "zupdf")
#' pdf_data(path)[[1]]
pdf_data <- function(pdf, font_info = FALSE, opw = "", upw = "") {
  x <- zpd_compat_open(pdf, opw, upw, sys.call())
  on.exit(x$done())
  p <- x$pdf
  limits <- zpd_limits(p)
  heights <- pdf_pages(p)$media_box
  lapply(seq_len(length(p)), function(i) {
    g <- zpd_unwrap(
      .Call(
        zupdf_page_glyphs,
        p,
        i,
        zpd_depth_int(limits$max_depth),
        limits$max_stream
      ),
      "Cannot extract the text",
      limits = limits
    )
    zpd_words(g, heights[[i]][[4]], isTRUE(font_info))
  })
}

# Glyphs (in stream order) to words: the rows pdf_data() returns. A word is
# a run of glyphs along one baseline in their own writing direction (so a
# rotated axis label is one word), ended by a space, a gap of 0.15 em or
# more, or a change of line. Its box is the page-aligned box around its
# glyphs, each taken as its advance from the font's descent to its ascent
# (from its descriptor, its bounding box or the base-14 metrics).
zpd_words <- function(g, page_top, font_info) {
  n <- length(g$text)
  words <- list()
  cur <- NULL
  flush <- function(space) {
    if (!is.null(cur) && nzchar(cur$text)) {
      cur$space <- space
      words[[length(words) + 1L]] <<- cur
    }
    cur <<- NULL
  }
  for (i in seq_len(n)) {
    size <- if (g$size[[i]] > 0) g$size[[i]] else 1
    dx <- g$x1[[i]] - g$x0[[i]]
    dy <- g$y1[[i]] - g$y0[[i]]
    len <- sqrt(dx^2 + dy^2)
    u <- if (len > 1e-6) {
      c(dx, dy) / len
    } else if (is.null(cur)) {
      c(1, 0)
    } else {
      cur$u
    }
    blank <- grepl("^[[:space:]]*$", g$text[[i]])
    if (!is.null(cur)) {
      v <- c(g$x0[[i]] - cur$ox, g$y0[[i]] - cur$oy)
      perp <- abs(cur$u[[1]] * v[[2]] - cur$u[[2]] * v[[1]])
      gap <- sum(cur$u * c(g$x0[[i]] - cur$ex, g$y0[[i]] - cur$ey))
      same_line <- sum(u * cur$u) > 0.95 && perp <= 0.3 * max(size, cur$size)
      if (!same_line || gap < -0.6 * size || gap > 3 * size) {
        flush(FALSE)
      } else if (blank || gap > 0.15 * size) {
        flush(TRUE)
      }
    }
    if (blank) {
      next
    }
    if (is.null(cur)) {
      cur <- list(
        ox = g$x0[[i]],
        oy = g$y0[[i]],
        ex = g$x0[[i]],
        ey = g$y0[[i]],
        u = u,
        size = size,
        text = "",
        font = g$font[[i]],
        px = numeric(),
        py = numeric()
      )
    }
    # The glyph's outline: its advance, from the font's descent to its
    # ascent across the baseline.
    up <- c(-u[[2]], u[[1]]) * size
    cx <- c(g$x0[[i]], g$x1[[i]])
    cy <- c(g$y0[[i]], g$y1[[i]])
    asc <- g$ascent[[i]]
    desc <- g$descent[[i]]
    cur$px <- c(cur$px, cx + desc * up[[1]], cx + asc * up[[1]])
    cur$py <- c(cur$py, cy + desc * up[[2]], cy + asc * up[[2]])
    cur$text <- paste0(cur$text, g$text[[i]])
    cur$ex <- g$x1[[i]]
    cur$ey <- g$y1[[i]]
    cur$size <- max(cur$size, size)
  }
  flush(FALSE)
  if (!length(words)) {
    out <- data.frame(
      width = integer(),
      height = integer(),
      x = integer(),
      y = integer(),
      space = logical(),
      text = character()
    )
  } else {
    col <- function(f) vapply(words, f, numeric(1))
    left <- col(function(w) min(w$px))
    right <- col(function(w) max(w$px))
    bottom <- col(function(w) min(w$py))
    top <- col(function(w) max(w$py))
    # Reading order: by line (the start's baseline, top first), then left
    # to right.
    ord <- order(round(-col(function(w) w$oy)), col(function(w) w$ox))
    out <- data.frame(
      width = as.integer(round(right - left)),
      height = as.integer(round(top - bottom)),
      x = as.integer(round(left)),
      y = as.integer(round(page_top - top)),
      space = vapply(words, `[[`, TRUE, "space"),
      text = vapply(words, `[[`, "", "text")
    )
    if (font_info) {
      out$font_name <- vapply(
        words,
        function(w) {
          if (is.na(w$font)) "" else w$font
        },
        ""
      )
      out$font_size <- col(function(w) w$size)
    }
    out <- out[ord, , drop = FALSE]
    rownames(out) <- NULL
  }
  if (font_info && !"font_name" %in% names(out)) {
    out$font_name <- character()
    out$font_size <- numeric()
  }
  class(out) <- c("tbl_df", "tbl", "data.frame")
  out
}
