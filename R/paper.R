#' Paper sizes
#'
#' Page sizes as media boxes for [pdf_new()] and [pdf_page_new()]: the ISO
#' A and B series and the North American letter, legal and tabloid sizes,
#' in PDF points (1/72 inch).
#'
#' @param name A size, such as `"a4"`, `"b5"` or `"letter"`; case is
#'   ignored.
#' @param landscape `TRUE` to swap width and height.
#' @return `c(0, 0, width, height)`.
#' @export
#' @examples
#' pdf_paper("a4")
#' pdf_paper("letter", landscape = TRUE)
pdf_paper <- function(name, landscape = FALSE) {
  call <- sys.call()
  sizes <- zpd_paper_sizes()
  key <- if (is.character(name) && length(name) == 1L) tolower(name) else ""
  if (!key %in% names(sizes)) {
    zpd_invalid_argument(
      "name",
      sprintf(
        "`name` must be one of %s.",
        paste0("\"", names(sizes), "\"", collapse = ", ")
      ),
      call = call
    )
  }
  if (!isTRUE(landscape) && !isFALSE(landscape)) {
    zpd_invalid_argument(
      "landscape",
      "`landscape` must be TRUE or FALSE.",
      call
    )
  }
  wh <- sizes[[key]]
  if (landscape) {
    wh <- rev(wh)
  }
  c(0, 0, wh)
}

# Width and height in points, ISO sizes rounded to 0.01 point.
zpd_paper_sizes <- function() {
  mm <- function(w, h) round(c(w, h) * 72 / 25.4, 2)
  iso <- list()
  aw <- 841
  ah <- 1189
  bw <- 1000
  bh <- 1414
  for (i in 0:10) {
    iso[[paste0("a", i)]] <- mm(aw, ah)
    iso[[paste0("b", i)]] <- mm(bw, bh)
    next_a <- c(floor(ah / 2), aw)
    aw <- next_a[[1]]
    ah <- next_a[[2]]
    next_b <- c(floor(bh / 2), bw)
    bw <- next_b[[1]]
    bh <- next_b[[2]]
  }
  c(
    iso,
    list(
      letter = c(612, 792),
      legal = c(612, 1008),
      tabloid = c(792, 1224)
    )
  )
}
