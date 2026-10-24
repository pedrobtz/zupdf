#' Images on a page
#'
#' Lists the images in a page's resources: the image XObjects it can draw.
#' Images inside Form XObjects and inline images are not listed. An
#' XObject whose dictionary cannot be read is listed with `NA` in every
#' column but `object` and `name`, and the errors become one
#' `zupdf_warning`, as in [pdf_objects()].
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
    call = call,
    limits = limits
  )
  na_info <- list(
    width = NA_integer_,
    height = NA_integer_,
    bits = NA_integer_,
    color_space = NA_character_,
    filter = NA_character_
  )
  info <- zpd_rows(xo$number, na_info, call = call, function(n) {
    d <- pdf_object(pdf, n)
    if (!identical(zpd_chr(zpd_key(d, "Subtype")), "Image")) {
      return(NULL)
    }
    zpd_image_info(pdf, d)
  })
  rows <- list()
  for (k in seq_along(xo$number)) {
    if (!is.null(info[[k]])) {
      rows[[length(rows) + 1L]] <- c(
        list(object = zpd_counts(xo$number[[k]]), name = xo$name[[k]]),
        info[[k]]
      )
    }
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
#' w <- pdf_new()
#' img <- pdf_image_new(w, as.raster(matrix(c("red", "blue"), 1)))
#' page <- pdf_page_new(w)
#' pdf_draw_image(page, img, 72, 600, 200, 100)
#' pdf_page_end(page)
#' pdf <- pdf_open(pdf_save(w))
#' n <- pdf_page_images(pdf, 1)$object
#' pdf_image(pdf, n, as = "raw")
#' pdf_image(pdf, n, as = "native")
#' pdf_close(pdf)
pdf_image <- function(pdf, n, as = c("raw", "native")) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  n <- zpd_check_number(n, "n", call = call)
  as <- zpd_match_arg(as, c("raw", "native"), "as", call = call)
  d <- pdf_object(pdf, n)
  if (!identical(zpd_chr(zpd_key(d, "Subtype")), "Image")) {
    zpd_invalid_argument("n", "The object is not an image.", call = call)
  }
  info <- zpd_image_info(pdf, d)
  stored <- info$filter %in% c("DCTDecode", "JPXDecode", "JBIG2Decode")
  bytes <- pdf_stream(pdf, n, decode = !stored)
  if (as == "native") {
    cs <- info$color_space
    channels <- if (identical(cs, "ICCBased")) {
      zpd_icc_channels(pdf, d)
    } else if (identical(cs, "DeviceRGB")) {
      3L
    } else if (identical(cs, "DeviceGray")) {
      1L
    } else {
      # An image mask has no colour space; Indexed, CMYK and others are
      # not converted.
      NA_integer_
    }
    if (
      !isTRUE(attr(bytes, "decoded")) ||
        !channels %in% c(1L, 3L) ||
        !identical(info$bits, 8L)
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
  cs <- zpd_deref(pdf, zpd_key(d, "ColorSpace"))
  cs <- if (is.list(cs)) {
    if (length(cs)) zpd_chr(cs[[1L]]) else NA_character_
  } else {
    zpd_chr(cs)
  }
  filter <- zpd_deref(pdf, zpd_key(d, "Filter"))
  filter <- if (is.list(filter)) {
    if (length(filter)) zpd_chr(filter[[length(filter)]]) else NA_character_
  } else {
    zpd_chr(filter)
  }
  list(
    width = zpd_int(pdf, zpd_key(d, "Width")),
    height = zpd_int(pdf, zpd_key(d, "Height")),
    bits = zpd_int(pdf, zpd_key(d, "BitsPerComponent")),
    color_space = cs,
    filter = filter
  )
}

# The number of components of an [/ICCBased stream] colour space, its /N.
zpd_icc_channels <- function(pdf, d) {
  cs <- zpd_deref(pdf, zpd_key(d, "ColorSpace"))
  if (!is.list(cs) || length(cs) < 2L) {
    return(NA_integer_)
  }
  icc <- zpd_deref(pdf, cs[[2L]])
  zpd_int(pdf, zpd_key(icc, "N"))
}
