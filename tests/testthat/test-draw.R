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
  })
  ops <- reread(bytes, function(p) {
    t <- pdf_page_tokens(p, 1)
    t$value[t$type == "operator"]
  })
  for (op in c(
    "m",
    "l",
    "c",
    "h",
    "re",
    "f",
    "S",
    "f*",
    "rg",
    "RG",
    "w",
    "q",
    "Q"
  )) {
    expect_true(op %in% ops, label = op)
  }
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

test_that("a hundred-page report writes quickly", {
  skip_heavy()
  t <- system.time(written(
    function(page) {
      for (i in 1:40) {
        pdf_draw_text(
          page,
          72,
          800 - i * 18,
          sprintf("Line %d of the report", i)
        )
      }
      pdf_draw(page, data.frame(op = "rect", x = 60, y = 60, w = 470, h = 740))
    },
    pages = 100L
  ))
  expect_lt(t[["elapsed"]], 5)
})
