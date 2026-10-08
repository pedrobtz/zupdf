# The marker classes of design section 6 and the check that a value can be
# written to PDF. C converts (src/zpd_value.c); these give the classes a
# readable form and refuse what has no PDF form before C sees it.

#' @export
format.pdf_name <- function(x, ...) paste0("/", unclass(x))

#' @export
print.pdf_name <- function(x, ...) {
  writeLines(format(x))
  invisible(x)
}

#' @export
format.pdf_ref <- function(x, ...) {
  paste(unclass(x)[[1L]], attr(x, "generation", exact = TRUE), "R")
}

#' @export
print.pdf_ref <- function(x, ...) {
  writeLines(format(x))
  invisible(x)
}

#' @export
format.pdf_binary <- function(x, ...) {
  paste0("<", paste(format(unclass(x)), collapse = ""), ">")
}

#' @export
print.pdf_binary <- function(x, ...) {
  writeLines(format(x))
  invisible(x)
}

# Checks that `x`, a list, can be written as a PDF dictionary (named) or
# array (unnamed): every element a list of the same kind, NULL, a raw
# vector, or a length-one logical, number or string that is not NA, with
# names that are all present and distinct. Raises zupdf_invalid_argument
# naming `arg` and the path to the fault; max_depth bounds the walk.
zpd_check_value <- function(x, arg, max_depth, call = NULL) {
  fail <- function(path, what) {
    zpd_invalid_argument(
      arg,
      sprintf("`%s%s` %s.", arg, path, what),
      call = call
    )
  }
  walk <- function(v, path, depth) {
    if (depth > max_depth) {
      zpd_limit_error(
        "max_depth",
        max_depth,
        sprintf("`%s` nests deeper than `max_depth` (%s).", arg, max_depth),
        call = call
      )
    }
    if (is.null(v) || is.raw(v)) {
      return(invisible())
    }
    if (is.list(v) && !is.object(v)) {
      nm <- names(v)
      if (
        !is.null(nm) && (anyNA(nm) || !all(nzchar(nm)) || anyDuplicated(nm))
      ) {
        fail(path, "must have names that are all present and distinct")
      }
      for (i in seq_along(v)) {
        sub <- if (is.null(nm)) sprintf("[[%d]]", i) else paste0("$", nm[[i]])
        walk(v[[i]], paste0(path, sub), depth + 1L)
      }
      return(invisible())
    }
    if (inherits(v, "POSIXct") && length(v) == 1L && !is.na(v)) {
      return(invisible())
    }
    if (inherits(v, "pdf_ref") && length(v) == 1L && !is.na(v)) {
      return(invisible())
    }
    ok <- (is.logical(v) || is.numeric(v) || is.character(v)) &&
      length(v) == 1L &&
      !is.na(v) &&
      (!is.numeric(v) || is.finite(v))
    if (!ok) {
      fail(
        path,
        "must be NULL, a list, a raw vector, or a single value that is not NA"
      )
    }
    invisible()
  }
  walk(x, "", 0L)
}

# Writes a list as an object of a one-page PDF in memory and returns
# list(bytes, number); the tests read it back with pdf_object().
zpd_value_roundtrip <- function(x, max_depth = 64L) {
  zpd_check_value(x, "x", max_depth)
  zpd_unwrap(
    .Call(zupdf_value_roundtrip, x, as.integer(max_depth)),
    "Cannot write the value",
    limits = list(max_depth = max_depth)
  )
}
