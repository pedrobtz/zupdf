#' Page sizes and rotation
#'
#' One row per page, from each page's dictionary and the attributes it
#' inherits from the page tree (`MediaBox`, `CropBox`, `Rotate`).
#'
#' Boxes are `c(x1, y1, x2, y2)` in PDF points (1/72 inch), with the origin
#' at the bottom left. The crop box defaults to the media box and is clipped
#' to it. `width` and `height` are the crop box's, before rotation.
#'
#' @inheritParams pdf_meta
#' @return A data frame with columns `page`, `width`, `height`, `rotate`
#'   (0, 90, 180 or 270, clockwise), `media_box` and `crop_box` (list
#'   columns of four numbers, `NA` when the file gives none) and `streams`
#'   (the number of content streams).
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_pages(pdf)
#' pdf_close(pdf)
pdf_pages <- function(pdf) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  limits <- zpd_limits(pdf)
  v <- zpd_unwrap(
    .Call(zupdf_pages, pdf, zpd_depth_int(limits$max_depth)),
    "Cannot read the pages",
    call,
    limits = limits
  )
  n <- ncol(v$media)
  boxes <- function(m) lapply(seq_len(n), function(i) m[, i])
  crop <- v$crop
  out <- data.frame(
    page = seq_len(n),
    width = crop[3L, ] - crop[1L, ],
    height = crop[4L, ] - crop[2L, ],
    rotate = v$rotate
  )
  out$media_box <- boxes(v$media)
  out$crop_box <- boxes(crop)
  out$streams <- v$streams
  out
}
