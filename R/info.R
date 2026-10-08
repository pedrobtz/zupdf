# Default limits, design section 12. Every reader takes its defaults from
# here, so zupdf_info() reports what pdf_open() enforces.
zpd_default_limits <- function() {
  list(
    max_size = 1024^3,
    max_objects = 1e6,
    max_stream = 256 * 1024^2,
    max_depth = 64L,
    max_pages = 1e5
  )
}

#' Build information
#'
#' Reports the bundled pdfio version, the patches applied to it, the zlib it
#' was linked against, the pdfio features this build lacks, and the default
#' limits.
#'
#' @return A list of class `zupdf_info` with elements:
#'   * `pdfio_version`: version of the bundled pdfio, e.g. `"1.6.5"`. Its
#'     `ttf` library ships inside the same release.
#'   * `patches`: the local patches applied to it, in order.
#'   * `zlib_version`: version of the zlib linked at build time.
#'   * `absent`: features of later pdfio releases this build lacks, such as
#'     `"lzw"` decoding.
#'   * `limits`: the default `max_size`, `max_objects`, `max_stream`,
#'     `max_depth` and `max_pages` of `pdf_open()`.
#'   * `smoke_ok`: `TRUE` if the bundled pdfio wrote a one-page file in
#'     memory.
#' @export
#' @examples
#' zupdf_info()
zupdf_info <- function() {
  info <- .Call(zupdf_build_info)
  structure(
    list(
      pdfio_version = info$pdfio_version,
      patches = info$patches,
      zlib_version = info$zlib_version,
      absent = info$absent,
      limits = zpd_default_limits(),
      smoke_ok = info$smoke_ok
    ),
    class = "zupdf_info"
  )
}

#' @export
format.zupdf_info <- function(x, ...) {
  lim <- x$limits
  fmt <- function(v) format(v, scientific = FALSE, big.mark = "")
  c(
    "<zupdf_info>",
    paste0("pdfio:       ", x$pdfio_version),
    paste0("patches:     ", paste(x$patches, collapse = ", ")),
    paste0("zlib:        ", x$zlib_version),
    paste0("absent:      ", paste(x$absent, collapse = ", ")),
    paste0("max_size:    ", fmt(lim$max_size), " bytes"),
    paste0("max_objects: ", fmt(lim$max_objects)),
    paste0("max_stream:  ", fmt(lim$max_stream), " bytes"),
    paste0("max_depth:   ", lim$max_depth),
    paste0("max_pages:   ", fmt(lim$max_pages)),
    paste0("self-test:   ", if (isTRUE(x$smoke_ok)) "ok" else "FAILED")
  )
}

#' @export
print.zupdf_info <- function(x, ...) {
  writeLines(format(x, ...))
  invisible(x)
}
