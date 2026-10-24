# The writer cases whose bytes are pinned in fixtures/hashes.tsv (design
# section 15: each writer function's bytes under deterministic = TRUE), by
# name. Each returns the bytes of one deterministic file. A change here
# changes the bytes: record the new hashes for every zlib in the table.
pinned_cases <- list(
  hello = function() {
    written(function(page) pdf_draw_text(page, 72, 700, "Hello"))
  },
  text = function() {
    written(function(page) {
      pdf_draw_text(page, 72, 700, "Café €5", font = "Times-Bold", size = 14)
      pdf_draw_text(
        page,
        c(72, 300),
        600,
        c("left\nlines", "right"),
        colour = "navy",
        align = "right",
        line_height = 1.5
      )
    })
  },
  font_file = function() {
    written(function(page) {
      pdf_draw_text(
        page,
        72,
        700,
        "Łódź — ß",
        font = pdf_font(page$writer, fixture("OpenSans-Regular.ttf"))
      )
    })
  },
  draw = function() {
    written(function(page) {
      pdf_draw(
        page,
        list(x = c(10, 20, 30), y = c(10, 20, 10)),
        fill = "red",
        stroke = "blue",
        width = 2,
        close = TRUE
      )
      pdf_draw(
        page,
        data.frame(
          op = c("move", "curve", "line", "close", "rect"),
          x = c(100, 200, 200, NA, 300),
          y = c(100, 100, 50, NA, 300),
          x1 = c(NA, 120, NA, NA, NA),
          y1 = c(NA, 150, NA, NA, NA),
          x2 = c(NA, 180, NA, NA, NA),
          y2 = c(NA, 150, NA, NA, NA),
          w = c(NA, NA, NA, NA, 50),
          h = c(NA, NA, NA, NA, 20)
        ),
        fill = "#00ff00",
        rule = "evenodd"
      )
    })
  },
  image_r = function() {
    written(function(page) {
      w <- page$writer
      grey <- pdf_image_new(w, matrix(c(0, 0.5, 1, 1), 2), interpolate = FALSE)
      rgba <- pdf_image_new(w, array(seq(0, 1, length.out = 24), c(2, 3, 4)))
      ras <- pdf_image_new(w, as.raster(matrix(c("red", "#0000FF80"), 1)))
      pdf_draw_image(page, grey, 72, 600, 100, 100)
      pdf_draw_image(page, rgba, 200, 600, 100, 100)
      pdf_draw_image(page, ras, 330, 600, 100, 50)
    })
  },
  image_file = function() {
    written(function(page) {
      png <- pdf_image_new(page$writer, fixture("pdfio-color.png"))
      jpg <- pdf_image_new(page$writer, fixture("color.jpg"))
      pdf_draw_image(page, png, 72, 500, 100, 100)
      pdf_draw_image(page, jpg, 200, 500, 100, 100)
    })
  },
  page = function() {
    w <- pdf_new(
      media_box = pdf_paper("letter"),
      created = as.POSIXct("2024-01-02 03:04:05", tz = "UTC"),
      deterministic = TRUE
    )
    page <- pdf_page_new(
      w,
      media_box = pdf_paper("a5"),
      crop_box = c(10, 10, 400, 500),
      dict = list(Rotate = 90L, UserUnit = 1L)
    )
    pdf_page_end(page)
    pdf_save(w)
  },
  copy = function() {
    src <- pdf_open(minimal_pdf(text = c("one", "two", "three")))
    on.exit(pdf_close(src))
    w <- pdf_new(
      created = as.POSIXct("2024-01-02 03:04:05", tz = "UTC"),
      deterministic = TRUE
    )
    pdf_copy_pages(w, src, pages = c(3, 1), rotate = 90)
    pdf_save(w)
  },
  meta = function() {
    w <- pdf_new(
      created = as.POSIXct("2024-01-02 03:04:05", tz = "UTC"),
      deterministic = TRUE
    )
    pdf_set_meta(
      w,
      title = "Pinned",
      author = "Zoë",
      language = "en-GB",
      modified = as.POSIXct("2024-07-02 23:30:00", tz = "UTC")
    )
    pdf_page_end(pdf_page_new(w))
    pdf_save(w)
  }
)

# The pinned hashes, with every case's MD5 for the zlib versions recorded.
pinned_hashes <- function() {
  utils::read.delim(
    fixture("hashes.tsv"),
    colClasses = "character",
    comment.char = "#"
  )
}
