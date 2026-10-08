#' Copy pages between files
#'
#' Copies pages of an open file into a writer, after the pages it already
#' has, each with everything it uses (fonts, images, forms), so the result
#' stands alone. Splitting, merging, reordering and rotating are all this:
#' copy the pages wanted, in the order wanted, from each file in turn.
#'
#' @inheritParams pdf_save
#' @param pdf A `pdf_file` from [pdf_open()]; it must stay open until the
#'   writer is saved.
#' @param pages Page numbers, in the order to copy them (repeats allowed), or
#'   `NULL` for every page.
#' @param rotate Degrees to add to each copied page's rotation, a multiple
#'   of 90.
#' @return `w`, invisibly.
#' @export
#' @examples
#' src <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' w <- pdf_new()
#' pdf_copy_pages(w, src, pages = c(2, 1), rotate = 90)
#' out <- pdf_open(pdf_save(w))
#' pdf_pages(out)$rotate
#' pdf_close(out)
#' pdf_close(src)
pdf_copy_pages <- function(w, pdf, pages = NULL, rotate = 0) {
  call <- sys.call()
  zpd_check_writer(w, call = call)
  zpd_check_open(pdf, call = call)
  pages <- zpd_check_pages(pdf, pages, call = call)
  ok <- is.numeric(rotate) &&
    length(rotate) == 1L &&
    is.finite(rotate) &&
    rotate %% 90 == 0
  if (!ok) {
    zpd_invalid_argument("rotate", "`rotate` must be a multiple of 90.", call)
  }
  zpd_unwrap(
    .Call(
      zupdf_writer_copy_pages,
      w,
      pdf,
      pages,
      as.integer(rotate %% 360),
      FALSE
    ),
    "Cannot copy the pages",
    call,
    default = "zupdf_write_error"
  )
  invisible(w)
}

#' Document metadata for the writer
#'
#' Sets the written file's information: title, author, subject, keywords,
#' creator, language and modification date. Text may be any Unicode; it is
#' written so that every reader decodes it. The creation date is
#' [pdf_new()]'s `created`.
#'
#' @inheritParams pdf_save
#' @param ... Named values: `title`, `author`, `subject`, `keywords`,
#'   `creator` and `language` (such as `"en-GB"`) are strings; `modified` is
#'   a `POSIXct`.
#' @return `w`, invisibly.
#' @export
#' @examples
#' w <- pdf_new()
#' pdf_set_meta(w, title = "A report", author = "Me", language = "en-GB")
#' pdf_page_end(pdf_page_new(w))
#' out <- pdf_open(pdf_save(w))
#' pdf_meta(out)[c("title", "author", "language")]
#' pdf_close(out)
pdf_set_meta <- function(w, ...) {
  call <- sys.call()
  zpd_check_writer(w, call = call)
  args <- list(...)
  known <- c(
    title = "Title",
    author = "Author",
    subject = "Subject",
    keywords = "Keywords",
    creator = "Creator",
    language = "Lang",
    modified = ""
  )
  nm <- names(args)
  if (
    length(args) &&
      (is.null(nm) || !all(nm %in% names(known)) || anyDuplicated(nm))
  ) {
    zpd_invalid_argument(
      "...",
      sprintf(
        "`...` takes named values among %s, each once.",
        paste(names(known), collapse = ", ")
      ),
      call
    )
  }
  modified <- NA_real_
  if (!is.null(args$modified)) {
    m <- args$modified
    if (!inherits(m, "POSIXct") || length(m) != 1L || is.na(m)) {
      zpd_invalid_argument(
        "modified",
        "`modified` must be one POSIXct time.",
        call
      )
    }
    modified <- as.numeric(m)
    args$modified <- NULL
  }
  for (k in names(args)) {
    zpd_check_string(args[[k]], k, call = call)
  }
  zpd_unwrap(
    .Call(
      zupdf_writer_set_meta,
      w,
      unname(known[names(args)]),
      enc2utf8(vapply(args, identity, "")),
      modified
    ),
    "Cannot set the metadata",
    call,
    default = "zupdf_write_error"
  )
  invisible(w)
}

#' Encrypt the written file
#'
#' Encrypts the file the writer will produce and sets what readers may do
#' with it. Call it first, before any page, font or image: pdfio fixes the
#' keys before the first object is written.
#'
#' AES-128 is the method to use; RC4-128 is there for readers that know
#' nothing newer. AES-256 is not offered for writing (design section 7).
#' With no user password anyone can open the file and the permissions ask
#' readers to behave; with one, it is needed to open the file, and the
#' owner password (which defaults to a random one) unlocks everything.
#'
#' @inheritParams pdf_save
#' @param user,owner Passwords, or `NULL`.
#' @param method `"aes128"` or `"rc4128"`.
#' @param permissions `"all"`, or any of `"print"`, `"modify"`, `"copy"`,
#'   `"annotate"`, `"forms"`, `"reading"`, `"assemble"`, `"print_high"`;
#'   `character()` for none.
#' @return `w`, invisibly.
#' @export
#' @examples
#' w <- pdf_new()
#' pdf_set_encryption(w, user = "secret", permissions = c("print", "copy"))
#' page <- pdf_page_new(w)
#' pdf_draw_text(page, 72, 700, "For your eyes only")
#' pdf_page_end(page)
#' bytes <- pdf_save(w)
#' pdf <- pdf_open(bytes, password = "secret")
#' pdf_meta(pdf)[c("encryption", "permissions")]
#' pdf_close(pdf)
pdf_set_encryption <- function(
  w,
  user = NULL,
  owner = NULL,
  method = c("aes128", "rc4128"),
  permissions = "all"
) {
  call <- sys.call()
  zpd_check_writer(w, call = call)
  method <- zpd_match_arg(method, c("aes128", "rc4128"), "method", call)
  for (a in c("user", "owner")) {
    v <- get(a)
    if (!is.null(v)) {
      zpd_check_string(v, a, call = call)
    }
  }
  if (
    !is.character(permissions) ||
      anyNA(permissions) ||
      !all(permissions %in% c("all", names(zpd_permission_bits)))
  ) {
    zpd_invalid_argument(
      "permissions",
      sprintf(
        "`permissions` must be \"all\" or among %s.",
        paste0("\"", names(zpd_permission_bits), "\"", collapse = ", ")
      ),
      call
    )
  }
  bits <- if ("all" %in% permissions) {
    -1L
  } else {
    as.integer(sum(zpd_permission_bits[unique(permissions)]))
  }
  code <- c(rc4128 = 2L, aes128 = 3L)[[method]]
  zpd_unwrap(
    .Call(
      zupdf_writer_set_encryption,
      w,
      code,
      bits,
      if (is.null(owner)) NULL else enc2utf8(owner),
      if (is.null(user)) NULL else enc2utf8(user)
    ),
    "Cannot set the encryption",
    call,
    default = "zupdf_write_error"
  )
  invisible(w)
}
