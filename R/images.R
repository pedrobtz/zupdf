#' Images on a page
#'
#' Lists the images in a page's resources: the image XObjects it can draw.
#' Images inside Form XObjects and inline images are not listed.
#'
#' @inheritParams pdf_page_tokens
#' @return A data frame with columns `object` (for [pdf_image()]), `name`
#'   (the resource name the content stream uses), `width`, `height`,
#'   `bits` (bits per component), `color_space` (such as `"DeviceRGB"`, or
#'   the family of an array colour space, such as `"ICCBased"`) and
#'   `filter` (the last filter, such as `"DCTDecode"` for JPEG, or `NA`).
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_page_images(pdf, 1)
#' pdf_close(pdf)
pdf_page_images <- function(pdf, i) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  i <- zpd_check_pages(pdf, i, single = TRUE, arg = "i", call = call)
  limits <- zpd_limits(pdf)
  xo <- zpd_unwrap(
    .Call(zupdf_page_xobjects, pdf, i, zpd_depth_int(limits$max_depth)),
    "Cannot read the page's resources",
    call,
    limits = limits
  )
  rows <- list()
  for (k in seq_along(xo$number)) {
    d <- pdf_object(pdf, xo$number[[k]])
    if (!identical(zpd_chr(d$Subtype), "Image")) {
      next
    }
    info <- zpd_image_info(pdf, d)
    rows[[length(rows) + 1L]] <- c(
      list(object = zpd_counts(xo$number[[k]]), name = xo$name[[k]]),
      info
    )
  }
  if (length(rows) == 0L) {
    return(data.frame(
      object = integer(),
      name = character(),
      width = integer(),
      height = integer(),
      bits = integer(),
      color_space = character(),
      filter = character()
    ))
  }
  col <- function(f, type) vapply(rows, function(r) r[[f]], type)
  data.frame(
    object = col("object", 1L),
    name = col("name", ""),
    width = col("width", 1L),
    height = col("height", 1L),
    bits = col("bits", 1L),
    color_space = col("color_space", ""),
    filter = col("filter", "")
  )
}

#' One image's samples
#'
#' Reads an image XObject. With `as = "raw"` the samples come back as
#' bytes: decoded when the filter is `FlateDecode` or none, and as stored
#' otherwise, so a JPEG (`DCTDecode`) image is its JPEG file, for
#' `jpeg::readJPEG()`. zupdf decodes no JPEG itself. With `as = "native"`,
#' an 8-bit `DeviceRGB` or `DeviceGray` image (or `ICCBased` with 3 or 1
#' components) that zupdf can decode comes back as a `nativeRaster`, for
#' [grid::grid.raster()] or [graphics::rasterImage()].
#'
#' @inheritParams pdf_object
#' @param as `"raw"` or `"native"`.
#' @return For `"raw"`, a raw vector with attributes `width`, `height`,
#'   `bits`, `color_space`, `filter` and `decoded`. For `"native"`, a
#'   `nativeRaster`.
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' imgs <- pdf_page_images(pdf, 1)
#' imgs
#' pdf_close(pdf)
pdf_image <- function(pdf, n, as = c("raw", "native")) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  n <- zpd_check_number(n, "n", call = call)
  as <- zpd_match_arg(as, c("raw", "native"), "as", call)
  d <- pdf_object(pdf, n)
  if (!is.list(d) || !identical(zpd_chr(d$Subtype), "Image")) {
    zpd_invalid_argument("n", "The object is not an image.", call = call)
  }
  info <- zpd_image_info(pdf, d)
  stored <- info$filter %in% c("DCTDecode", "JPXDecode", "JBIG2Decode")
  bytes <- pdf_stream(pdf, n, decode = !stored)
  if (as == "native") {
    channels <- c(DeviceRGB = 3L, DeviceGray = 1L)[info$color_space]
    if (info$color_space == "ICCBased") {
      channels <- zpd_icc_channels(pdf, d)
    }
    if (
      !isTRUE(attr(bytes, "decoded")) ||
        is.na(channels) ||
        !channels %in% c(1L, 3L) ||
        info$bits != 8L
    ) {
      zpd_abort(
        "zupdf_unsupported_input",
        paste0(
          "Only 8-bit RGB or grey images that zupdf can decode convert to a ",
          "nativeRaster; use `as = \"raw\"`."
        ),
        call = call
      )
    }
    out <- .Call(
      zupdf_native_raster,
      bytes,
      info$width,
      info$height,
      as.integer(channels)
    )
    if (is.null(out)) {
      zpd_abort(
        "zupdf_parse_error",
        "The image has fewer samples than its size says.",
        call = call
      )
    }
    return(out)
  }
  structure(
    as.vector(bytes),
    width = info$width,
    height = info$height,
    bits = info$bits,
    color_space = info$color_space,
    filter = info$filter,
    decoded = attr(bytes, "decoded")
  )
}

zpd_image_info <- function(pdf, d) {
  cs <- zpd_deref(pdf, d$ColorSpace)
  cs <- if (is.list(cs)) zpd_chr(cs[[1L]]) else zpd_chr(cs)
  filter <- zpd_deref(pdf, d$Filter)
  filter <- if (is.list(filter)) {
    zpd_chr(filter[[length(filter)]])
  } else {
    zpd_chr(filter)
  }
  int <- function(x) if (is.null(x)) NA_integer_ else as.integer(x)
  list(
    width = int(d$Width),
    height = int(d$Height),
    bits = int(d$BitsPerComponent),
    color_space = cs,
    filter = filter
  )
}

zpd_icc_channels <- function(pdf, d) {
  cs <- zpd_deref(pdf, d$ColorSpace)
  if (!is.list(cs) || length(cs) < 2L) {
    return(NA_integer_)
  }
  icc <- zpd_deref(pdf, cs[[2L]])
  if (is.list(icc) && !is.null(icc$N)) as.integer(icc$N) else NA_integer_
}
