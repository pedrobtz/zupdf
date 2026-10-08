test_that("zpd_abort() raises the class under zupdf_error with its fields", {
  err <- tryCatch(
    zpd_abort("zupdf_parse_error", "m", object = 12L, detail = "bad xref"),
    error = identity
  )
  expect_identical(
    class(err),
    c("zupdf_parse_error", "zupdf_error", "error", "condition")
  )
  expect_identical(err$object, 12L)
  expect_identical(err$detail, "bad xref")
})

test_that("every design section 11 class can be raised and caught", {
  for (cls in zpd_condition_classes) {
    err <- tryCatch(zpd_abort(cls, "m"), zupdf_error = identity)
    expect_s3_class(err, cls)
    expect_s3_class(err, "error")
  }
})

test_that("zpd_abort() refuses a class outside the hierarchy", {
  expect_error(zpd_abort("zupdf_made_up", "m"))
})

test_that("zpd_invalid_argument() carries the argument's name", {
  expect_zupdf_error(
    zpd_invalid_argument("max_depth", "m"),
    "zupdf_invalid_argument",
    arg = "max_depth"
  )
})

test_that("zpd_limit_error() carries the limit and its value", {
  expect_zupdf_error(
    zpd_limit_error("max_stream", 1024, "m"),
    "zupdf_limit_error",
    limit = "max_stream",
    limit_value = 1024
  )
})

test_that("zpd_warn() raises a zupdf_warning", {
  w <- tryCatch(zpd_warn("m", count = 2L), warning = identity)
  expect_s3_class(w, "zupdf_warning")
  expect_identical(w$count, 2L)
})
