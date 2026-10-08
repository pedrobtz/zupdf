# Argument checks shared by the exported functions. Each raises
# zupdf_invalid_argument naming the argument.

# `...` must be empty: it only forces the arguments after it to be named.
zpd_check_dots <- function(..., call = NULL) {
  if (...length() > 0L) {
    zpd_invalid_argument(
      "...",
      "Arguments after `...` must be named; unused arguments were given.",
      call = call
    )
  }
}

# A limit is a positive whole number, or Inf (design section 12).
zpd_check_limit <- function(value, name, call = NULL) {
  ok <- is.numeric(value) &&
    length(value) == 1L &&
    !is.na(value) &&
    value > 0 &&
    (is.infinite(value) || value == floor(value))
  if (!ok) {
    zpd_invalid_argument(
      name,
      sprintf("`%s` must be a positive whole number or Inf.", name),
      call = call
    )
  }
  as.numeric(value)
}

zpd_check_limits <- function(limits, call = NULL) {
  for (name in names(limits)) {
    limits[[name]] <- zpd_check_limit(limits[[name]], name, call = call)
  }
  limits
}

# max_depth as the C int the walks compare against.
zpd_depth_int <- function(max_depth) {
  as.integer(min(max_depth, .Machine$integer.max))
}

zpd_check_string <- function(value, name, call = NULL) {
  if (!is.character(value) || length(value) != 1L || is.na(value)) {
    zpd_invalid_argument(
      name,
      sprintf("`%s` must be a single string.", name),
      call = call
    )
  }
  value
}
