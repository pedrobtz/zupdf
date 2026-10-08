# Design section 6, every row both ways: written by zupdf through pdfio,
# read back through pdf_object().

test_that("null, booleans and numbers round-trip", {
  x <- list(n = NULL, t = TRUE, f = FALSE, i = 42L, neg = -7L, d = 2.5)
  back <- roundtrip(x)
  expect_null(back$n)
  expect_true("n" %in% names(back))
  expect_true(back$t)
  expect_false(back$f)
  expect_identical(back$i, 42L)
  expect_identical(back$neg, -7L)
  expect_identical(back$d, 2.5)
})

test_that("whole numbers become integers only within R's integer range", {
  back <- roundtrip(list(a = 3, big = 2^40))
  expect_identical(back$a, 3L)
  expect_identical(back$big, 2^40)
})

test_that("strings round-trip, ASCII and not", {
  x <- list(a = "plain", u = "héllo ☺ \U0001d11e", e = "")
  back <- roundtrip(x)
  expect_identical(back$a, "plain")
  expect_identical(back$u, x$u)
  expect_identical(Encoding(back$u), "UTF-8")
  expect_identical(back$e, "")
})

test_that("names, binary strings, dates and references keep their classes", {
  x <- list(
    nm = structure("Page", class = "pdf_name"),
    b = structure(as.raw(c(0, 1, 255)), class = "pdf_binary"),
    raw = as.raw(c(9, 8)),
    when = .POSIXct(1700000000, tz = "UTC")
  )
  back <- roundtrip(x)
  expect_identical(back$nm, x$nm)
  expect_identical(back$b, x$b)
  expect_identical(back$raw, structure(as.raw(c(9, 8)), class = "pdf_binary"))
  expect_identical(back$when, x$when)
})

test_that("a reference to an object in the file round-trips", {
  # Object 1 exists in every file pdfio writes (the catalog comes later,
  # but the first object created is number 1).
  back <- roundtrip(list(self = structure(1L, class = "pdf_ref")))
  expect_s3_class(back$self, "pdf_ref")
  expect_identical(as.integer(unclass(back$self)), 1L)
  expect_identical(attr(back$self, "generation"), 0L)
})

test_that("arrays and dictionaries nest", {
  x <- list(
    arr = list(1L, "two", list(3L, list(four = 4L))),
    dict = list(inner = list(k = TRUE))
  )
  back <- roundtrip(x)
  expect_identical(back$arr[[1]], 1L)
  expect_identical(back$arr[[3]][[2]]$four, 4L)
  expect_true(back$dict$inner$k)
  expect_null(names(back$arr))
})

test_that("a null inside an array is kept", {
  back <- roundtrip(list(a = list(1L, NULL, 3L)))
  expect_length(back$a, 3L)
  expect_null(back$a[[2]])
})

test_that("an unnamed list is written as an array", {
  back <- roundtrip(list(1L, "x"))
  expect_identical(back, list(1L, "x"))
})

test_that("dictionary keys come back in pdfio's sorted order", {
  back <- roundtrip(list(b = 1L, a = 2L, c = 3L))
  expect_identical(names(back), c("a", "b", "c"))
})

test_that("values with no PDF form are refused before C sees them", {
  bad <- list(
    list(a = NA),
    list(a = c(1, 2)),
    list(a = NA_character_),
    list(a = Inf),
    list(a = mean),
    stats::setNames(list(1, 2), c("a", "")),
    stats::setNames(list(1, 2), c("a", "a"))
  )
  for (x in bad) {
    expect_zupdf_error(zpd_value_roundtrip(x), "zupdf_invalid_argument")
  }
})

test_that("writing is bounded by max_depth", {
  x <- list(a = list(list(list(list(1L)))))
  expect_zupdf_error(
    zpd_value_roundtrip(x, max_depth = 3L),
    "zupdf_limit_error",
    limit = "max_depth"
  )
  expect_identical(roundtrip(x, max_depth = 5L)$a[[1]][[1]][[1]][[1]], 1L)
})

test_that("a reference to a missing object is refused", {
  expect_zupdf_error(
    zpd_value_roundtrip(list(r = structure(99L, class = "pdf_ref"))),
    "zupdf_invalid_argument"
  )
})

test_that("pdf_binary and pdf_ref print readably", {
  expect_identical(
    format(structure(as.raw(c(1, 255)), class = "pdf_binary")),
    "<01ff>"
  )
  expect_output(print(structure("X", class = "pdf_name")), "/X", fixed = TRUE)
  expect_output(
    print(structure(3L, generation = 0L, class = "pdf_ref")),
    "3 0 R",
    fixed = TRUE
  )
  expect_output(print(structure(as.raw(1), class = "pdf_binary")), "<01>")
})
