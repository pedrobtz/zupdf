test_that("text in base-14 fonts reads back, CP1252 included", {
  bytes <- written(function(page) {
    pdf_draw_text(page, 72, 700, "Café €5 — ok")
    pdf_draw_text(page, 72, 650, "Bold", font = "Helvetica-Bold")
    pdf_draw_text(page, 72, 600, "Mono", font = "Courier", size = 9)
  })
  expect_identical(
    as.vector(reread(bytes)),
    "Café €5 — ok\nBold\nMono"
  )
  fonts <- reread(bytes, pdf_font_table)
  expect_setequal(fonts$name, c("Helvetica", "Helvetica-Bold", "Courier"))
})

test_that("a character a base-14 font cannot show becomes ?", {
  bytes <- written(function(page) pdf_draw_text(page, 72, 700, "☺!"))
  expect_identical(as.vector(reread(bytes)), "?!")
})

test_that("an embedded TrueType font shows any character it has", {
  font <- fixture("OpenSans-Regular.ttf")
  bytes <- written(function(page) {
    pdf_draw_text(page, 72, 700, "Łódź — ß", font = font, size = 14)
  })
  expect_identical(as.vector(reread(bytes)), "Łódź — ß")
  f <- reread(bytes, pdf_font_table)
  expect_true(f$embedded[[1]])
  expect_identical(f$type[[1]], "Type0")
})

test_that("a font is made once per writer and fonts stay with their writer", {
  w <- pdf_new()
  a <- pdf_font(w, "Times-Roman")
  expect_identical(pdf_font(w, "Times-Roman")$handle, a$handle)
  expect_output(print(a), "Times-Roman")
  other <- pdf_new()
  page <- pdf_page_new(other)
  expect_zupdf_error(
    pdf_draw_text(page, 1, 1, "x", font = a),
    "zupdf_invalid_argument",
    arg = "font"
  )
})

test_that("an unknown font name or a file that is not a font is refused", {
  w <- pdf_new()
  page <- pdf_page_new(w)
  expect_zupdf_error(
    pdf_draw_text(page, 1, 1, "x", font = "Arial"),
    "zupdf_invalid_argument",
    arg = "font"
  )
  # The argument at fault is the caller's: `x` for pdf_font().
  expect_zupdf_error(
    pdf_font(w, "Arial"),
    "zupdf_invalid_argument",
    arg = "x"
  )
  expect_zupdf_error(
    pdf_text_width(w, "x", font = "Arial"),
    "zupdf_invalid_argument",
    arg = "font"
  )
  not_font <- withr::local_tempfile(fileext = ".ttf")
  writeBin(charToRaw("not a font"), not_font)
  expect_zupdf_error(pdf_font(w, not_font), "zupdf_font_error")
})

test_that("alignment, recycling and line breaks place text", {
  bytes <- written(function(page) {
    pdf_draw_text(page, 297, 700, "centre", align = "centre")
    pdf_draw_text(page, c(72, 400), 600, c("left", "right"), align = "left")
    pdf_draw_text(page, 72, 500, "one\ntwo", size = 10, line_height = 2)
  })
  expect_identical(
    as.vector(reread(bytes)),
    "centre\nleft right\none\ntwo"
  )
  tokens <- reread(bytes, function(p) pdf_page_tokens(p, 1))
  # "centre" is drawn left of 297 by half its width.
  x <- as.numeric(tokens$value[which(tokens$value == "Td")[1] - 2L])
  expect_lt(x, 297)
  expect_gt(x, 250)
})

test_that("pdf_draw_text() checks its arguments", {
  w <- pdf_new()
  page <- pdf_page_new(w)
  expect_zupdf_error(
    pdf_draw_text(page, NA, 1, "x"),
    "zupdf_invalid_argument",
    arg = "x"
  )
  expect_zupdf_error(
    pdf_draw_text(page, 1, 1, NA_character_),
    "zupdf_invalid_argument",
    arg = "text"
  )
  expect_zupdf_error(
    pdf_draw_text(page, 1, 1, "x", size = -1),
    "zupdf_invalid_argument",
    arg = "size"
  )
  expect_zupdf_error(
    pdf_draw_text(page, 1, 1, "x", colour = "nope"),
    "zupdf_invalid_argument",
    arg = "colour"
  )
  expect_zupdf_error(
    pdf_draw_text(page, 1, 1, "x", align = "middle"),
    "zupdf_invalid_argument",
    arg = "align"
  )
  expect_zupdf_error(
    pdf_draw_text(page, 1, 1, "x", oops = 3),
    "zupdf_invalid_argument",
    arg = "..."
  )
})

test_that("paths draw: points, operations, curves, rectangles", {
  bytes <- written(function(page) {
    pdf_draw(
      page,
      list(x = c(10, 20, 30), y = c(10, 20, 10)),
      fill = "red",
      close = TRUE
    )
    pdf_draw(
      page,
      data.frame(
        op = c("move", "curve", "line", "close"),
        x = c(100, 200, 200, NA),
        y = c(100, 100, 50, NA),
        x1 = c(NA, 120, NA, NA),
        y1 = c(NA, 150, NA, NA),
        x2 = c(NA, 180, NA, NA),
        y2 = c(NA, 150, NA, NA)
      ),
      stroke = "blue",
      width = 2
    )
    pdf_draw(
      page,
      data.frame(op = "rect", x = 300, y = 300, w = 50, h = 20),
      fill = "#00ff00",
      rule = "evenodd"
    )
    tri <- list(x = c(10, 20, 30), y = c(10, 20, 10))
    pdf_draw(page, tri, fill = "red", stroke = "blue", close = TRUE)
    pdf_draw(
      page,
      data.frame(op = "rect", x = 1, y = 2, w = 3, h = 4),
      fill = "red",
      stroke = "blue",
      rule = "evenodd"
    )
    pdf_draw(page, list(x = c(1, 2), y = c(3, 4)))
  })
  tokens <- reread(bytes, function(p) pdf_page_tokens(p, 1))
  ops <- tokens$value[tokens$type == "operator"]
  # One q ... Q group per pdf_draw() call, operators in order.
  calls <- split(ops, cumsum(ops == "q"))
  expect_identical(
    unname(calls),
    list(
      c("q", "rg", "w", "m", "l", "l", "h", "f", "Q"),
      c("q", "RG", "w", "m", "c", "l", "h", "S", "Q"),
      c("q", "rg", "w", "re", "f*", "Q"),
      c("q", "rg", "RG", "w", "m", "l", "l", "h", "B", "Q"),
      c("q", "rg", "RG", "w", "re", "B*", "Q"),
      c("q", "RG", "w", "m", "l", "S", "Q")
    )
  )
  # The operands of the fill-and-stroke call: red fill, blue stroke.
  v <- tokens$value
  q <- which(v == "q")[[4]]
  expect_identical(
    v[q + 1:8],
    c("1", "0", "0", "rg", "0", "0", "1", "RG")
  )
  expect_identical(v[which(v == "re")[2] - 4:1], c("1", "2", "3", "4"))
})

test_that("bad paths are refused", {
  w <- pdf_new()
  page <- pdf_page_new(w)
  bad <- list(
    list(x = 1),
    list(x = 1, y = 1),
    list(x = c(1, 2), y = 1),
    data.frame(op = "jump", x = 1, y = 1),
    data.frame(op = "line", x = 1, y = 1),
    data.frame(op = c("move", "curve"), x = c(1, 2), y = c(1, 2)),
    data.frame(op = "rect", x = 1, y = 1)
  )
  for (p in bad) {
    expect_zupdf_error(
      pdf_draw(page, p),
      "zupdf_invalid_argument",
      arg = "path"
    )
  }
  expect_zupdf_error(
    pdf_draw(page, list(x = 1:2, y = 1:2), width = -1),
    "zupdf_invalid_argument",
    arg = "width"
  )
  expect_zupdf_error(
    pdf_draw(page, list(x = 1:2, y = 1:2), rule = "x"),
    "zupdf_invalid_argument",
    arg = "rule"
  )
})

# ---- images -----------------------------------------------------------------

test_that("images from R round-trip their samples", {
  w <- pdf_new(deterministic = TRUE)
  gray <- pdf_image_new(
    w,
    matrix(c(0, 0.5, 1, 1), 2, byrow = TRUE),
    interpolate = FALSE
  )
  rgb <- pdf_image_new(
    w,
    array(
      c(1, 0, 0, 1, 0, 1, 0, 0, 1, 1, 1, 1)[c(
        1,
        4,
        7,
        10,
        2,
        5,
        8,
        11,
        3,
        6,
        9,
        12
      )],
      c(2, 2, 3)
    )
  )
  ras <- pdf_image_new(w, as.raster(matrix(c("red", "blue"), 1)))
  expect_identical(c(gray$width, gray$height), c(2L, 2L))
  expect_output(print(ras), "2 x 1")
  page <- pdf_page_new(w)
  pdf_draw_image(page, gray, 72, 600, 100, 100)
  pdf_draw_image(page, rgb, 200, 600, 100, 100)
  pdf_draw_image(page, ras, 330, 600, 100, 50)
  pdf_page_end(page)
  bytes <- pdf_save(w)

  pdf <- pdf_open(bytes)
  withr::defer(pdf_close(pdf))
  im <- pdf_page_images(pdf, 1)
  expect_identical(nrow(im), 3L)
  g <- pdf_image(pdf, im$object[im$color_space == "DeviceGray"][[1]])
  expect_identical(as.vector(g), as.raw(c(0, 128, 255, 255)))
  expect_identical(c(attr(g, "width"), attr(g, "height")), c(2L, 2L))
})

test_that("RGB arrays, rasters and their alpha are written sample for sample", {
  # 2 rows by 3 columns, every sample different, so a transposed or
  # reordered array cannot match.
  h <- 2L
  wd <- 3L
  v <- array((1:(h * wd * 4)) * 10 / 255, c(h, wd, 4))
  # Expected: row by row from the top, pixel by pixel, channel fastest.
  rows <- function(a, ch) {
    as.raw(round(as.vector(aperm(a[,, ch, drop = FALSE], c(3, 2, 1))) * 255))
  }
  ras <- as.raster(matrix(
    c("red", "#0000FF80", "#00FF00", "white", "black", "#12345678"),
    h,
    byrow = TRUE
  ))
  nr <- structure(
    c(-16776961L, 2130771712L),
    dim = c(1L, 2L),
    class = "nativeRaster",
    channels = 4L
  )
  w <- pdf_new(deterministic = TRUE)
  imgs <- list(
    rgb = pdf_image_new(w, v[,, 1:3]),
    rgba = pdf_image_new(w, v),
    ras = pdf_image_new(w, ras),
    nr = pdf_image_new(w, nr)
  )
  page <- pdf_page_new(w)
  for (img in imgs) {
    pdf_draw_image(page, img, 10, 10, 10, 10)
  }
  pdf_page_end(page)
  pdf <- pdf_open(pdf_save(w))
  withr::defer(pdf_close(pdf))
  im <- pdf_page_images(pdf, 1)
  # Each image and its soft mask (NULL for none), by its handle's name.
  read <- function(img) {
    n <- im$object[im$name == paste0("Im", img$handle)]
    mask <- pdf_object(pdf, n)$SMask
    list(
      rgb = as.vector(pdf_image(pdf, n)),
      alpha = if (!is.null(mask)) as.vector(pdf_image(pdf, as.integer(mask)))
    )
  }
  got <- read(imgs$rgb)
  expect_identical(got$rgb, rows(v, 1:3))
  expect_null(got$alpha)
  got <- read(imgs$rgba)
  expect_identical(got$rgb, rows(v, 1:3))
  expect_identical(got$alpha, rows(v, 4))

  cols <- grDevices::col2rgb(t(as.matrix(ras)), alpha = TRUE)
  got <- read(imgs$ras)
  expect_identical(got$rgb, as.raw(cols[1:3, ]))
  expect_identical(got$alpha, as.raw(cols[4, ]))

  # 0xFF0000FF is opaque red, 0x7F00FF00 half-transparent green.
  got <- read(imgs$nr)
  expect_identical(got$rgb, as.raw(c(255, 0, 0, 0, 255, 0)))
  expect_identical(got$alpha, as.raw(c(255, 127)))
})

test_that("an RGBA PNG is drawn from png::readPNG(), not from the file", {
  # pdfio reads PNG files without libpng and has no alpha (colour type 6).
  w <- pdf_new()
  expect_zupdf_error(
    pdf_image_new(w, fixture("pdfio-rgba.png")),
    "zupdf_unsupported_input"
  )
  skip_if_not_installed("png")
  a <- png::readPNG(fixture("pdfio-rgba.png"))
  img <- pdf_image_new(w, a)
  expect_identical(c(img$width, img$height), dim(a)[2:1])
  page <- pdf_page_new(w)
  pdf_draw_image(page, img, 0, 0, 100, 100)
  pdf_page_end(page)
  pdf <- pdf_open(pdf_save(w))
  withr::defer(pdf_close(pdf))
  n <- pdf_page_images(pdf, 1)$object
  px <- as.vector(pdf_image(pdf, n))
  alpha <- as.vector(pdf_image(pdf, as.integer(pdf_object(pdf, n)$SMask)))
  expect_identical(px, as.raw(round(as.vector(aperm(a[,, 1:3], 3:1)) * 255)))
  expect_identical(alpha, as.raw(round(as.vector(t(a[,, 4])) * 255)))
})

test_that("a nativeRaster is drawn with its alpha", {
  nr <- structure(
    c(-16776961L, 2130771712L),
    dim = c(1L, 2L),
    class = "nativeRaster",
    channels = 4L
  )
  bytes <- written(function(page) {
    img <- pdf_image_new(page$writer, nr)
    pdf_draw_image(page, img, 10, 10, 20, 10)
  })
  im <- reread(bytes, function(p) pdf_page_images(p, 1))
  expect_identical(im$width, 2L)
  # The alpha channel becomes a soft mask: a second image object.
  objs <- reread(bytes, pdf_objects)
  expect_identical(sum(objs$subtype %in% "Image"), 2L)
})

test_that("PNG and JPEG files are embedded", {
  bytes <- written(function(page) {
    png <- pdf_image_new(page$writer, fixture("pdfio-color.png"))
    jpg <- pdf_image_new(page$writer, fixture("color.jpg"))
    pdf_draw_image(page, png, 72, 500, 100, 100)
    pdf_draw_image(page, jpg, 200, 500, 100, 100)
  })
  im <- reread(bytes, function(p) pdf_page_images(p, 1))
  expect_identical(nrow(im), 2L)
  expect_true("DCTDecode" %in% im$filter)
})

test_that("an image from a file reports its size in pixels", {
  w <- pdf_new()
  png <- pdf_image_new(w, fixture("pdfio-color.png"))
  jpg <- pdf_image_new(w, fixture("color.jpg"))
  page <- pdf_page_new(w)
  pdf_draw_image(page, png, 72, 500, 100, 100)
  pdf_draw_image(page, jpg, 200, 500, 100, 100)
  pdf_page_end(page)
  im <- reread(pdf_save(w), function(p) pdf_page_images(p, 1))
  expect_identical(c(png$width, png$height), c(im$width[1], im$height[1]))
  expect_identical(c(jpg$width, jpg$height), c(im$width[2], im$height[2]))
  expect_output(print(png), sprintf("%d x %d", im$width[1], im$height[1]))
})

test_that("bad images are refused by class", {
  w <- pdf_new()
  expect_zupdf_error(pdf_image_new(w, "no-such.png"), "zupdf_io_error")
  gif <- withr::local_tempfile(fileext = ".gif")
  writeBin(c(charToRaw("GIF89a"), as.raw(c(1, 0, 1, 0)), raw(64)), gif)
  expect_zupdf_error(pdf_image_new(w, gif), "zupdf_unsupported_input")
  expect_zupdf_error(
    pdf_image_new(w, list(1)),
    "zupdf_invalid_argument",
    arg = "x"
  )
  page <- pdf_page_new(w)
  expect_zupdf_error(
    pdf_draw_image(page, "x", 1, 1, 1, 1),
    "zupdf_invalid_argument",
    arg = "image"
  )
  other <- pdf_new()
  img <- pdf_image_new(other, matrix(1, 1, 1))
  expect_zupdf_error(
    pdf_draw_image(page, img, 1, 1, 1, 1),
    "zupdf_invalid_argument",
    arg = "image"
  )
})

test_that("each page of a report costs the same, however many came before", {
  # Structural, not a timing: a page that kept or replayed what earlier
  # pages drew would grow with the page count. Only object numbers gain a
  # digit, so the 20th page's bytes are within 1% of the 2nd's.
  report <- function(pages) {
    written(
      function(page) {
        for (i in 1:10) {
          pdf_draw_text(
            page,
            72,
            800 - i * 18,
            sprintf("Line %d of the report", i)
          )
        }
        pdf_draw(
          page,
          data.frame(op = "rect", x = 60, y = 60, w = 470, h = 740)
        )
      },
      pages = pages
    )
  }
  n <- vapply(c(1L, 2L, 19L, 20L), function(p) length(report(p)), 1L)
  second <- n[[2]] - n[[1]]
  twentieth <- n[[4]] - n[[3]]
  expect_lt(abs(twentieth - second) / second, 0.01)
  text <- reread(report(20L))
  expect_length(text, 20L)
  expect_identical(text[[20]], text[[1]])
})

test_that("pdf_text_width() measures as pdf_draw_text() draws", {
  w <- pdf_new()
  widths <- pdf_text_width(w, c("", "i", "W", "Hello"), size = 10)
  expect_identical(widths[[1]], 0)
  expect_lt(widths[[2]], widths[[3]])
  # Helvetica's "Hello" is 2.389 em: H 722, e 556, l 222, l 222, o 556.
  expect_equal(widths[[4]], 22.78, tolerance = 1e-6)
  expect_equal(pdf_text_width(w, "Hello", size = 20), 2 * widths[[4]])
  ttf <- pdf_text_width(
    w,
    "Hello",
    font = fixture("OpenSans-Regular.ttf"),
    size = 10
  )
  expect_gt(ttf, 0)
  expect_zupdf_error(
    pdf_text_width(w, NA_character_),
    "zupdf_invalid_argument",
    arg = "text"
  )
  expect_zupdf_error(
    pdf_text_width(w, "x", size = 0),
    "zupdf_invalid_argument",
    arg = "size"
  )
})

test_that("a long path and many calls are recorded whole and in order", {
  # Recording is linear: a 20,000-point path once took seconds.
  n <- 20000L
  w <- pdf_new()
  page <- pdf_page_new(w)
  pdf_draw(page, list(x = seq_len(n) / 40, y = rep(c(10, 20), n / 2)))
  for (i in 1:200) {
    pdf_draw_text(page, 72, 800 - i * 3, sprintf("t%d", i), size = 3)
  }
  # save, stroke_rgb, line_width, move, lines, paint, restore; then
  # save, fill_rgb, text, restore per call.
  expect_output(print(page), sprintf("%d operations", n + 5L + 4L * 200L))
  pdf_page_end(page)
  bytes <- pdf_save(w)
  ops <- reread(bytes, function(p) {
    t <- pdf_page_tokens(p, 1)
    t$value[t$type == "operator"]
  })
  expect_identical(sum(ops == "l"), n - 1L)
  text <- reread(bytes, function(p) pdf_page_text(p, layout = "raw"))
  expect_identical(
    strsplit(as.vector(text), "\n")[[1]],
    sprintf("t%d", 1:200)
  )
})

test_that("line_height must be one positive number", {
  w <- pdf_new()
  page <- pdf_page_new(w)
  for (lh in list(c(1, 2), 0, -1, NA_real_, "1")) {
    expect_zupdf_error(
      pdf_draw_text(page, 10, 10, "a\nb", line_height = lh),
      "zupdf_invalid_argument",
      arg = "line_height"
    )
  }
  pdf_page_end(page)
  expect_type(pdf_save(w), "raw")
})
