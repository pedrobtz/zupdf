#' Document metadata
#'
#' Reads the document's version, page count, information dictionary,
#' identifier, encryption and permissions.
#'
#' Strings are returned as UTF-8: pdfio converts UTF-16 strings as it reads
#' them, and a string that is not valid UTF-8 is read as PDFDocEncoding.
#'
#' @param pdf A `pdf_file` from [pdf_open()].
#' @return A list with elements:
#'   * `version`: the PDF version, such as `"1.7"`.
#'   * `pages`: the page count.
#'   * `title`, `author`, `subject`, `keywords`, `creator`, `producer`,
#'     `language`: strings, `NA` where absent.
#'   * `created`, `modified`: `POSIXct` in UTC, `NA` where absent.
#'   * `id`: the file identifier, two hexadecimal strings, or `character()`.
#'   * `encryption`: one of `"none"`, `"rc4-40"`, `"rc4-128"`, `"aes-128"`,
#'     `"aes-256"`.
#'   * `permissions`: what the file allows, a subset of `"print"`,
#'     `"modify"`, `"copy"`, `"annotate"`, `"forms"`, `"reading"`,
#'     `"assemble"`, `"print_high"`.
#' @export
#' @examples
#' pdf <- pdf_open(system.file("examples", "hello.pdf", package = "zupdf"))
#' pdf_meta(pdf)
#' pdf_close(pdf)
pdf_meta <- function(pdf) {
  call <- sys.call()
  zpd_check_open(pdf, call = call)
  v <- zpd_unwrap(.Call(zupdf_meta, pdf), "Cannot read the metadata", call)
  utc <- function(t) .POSIXct(t, tz = "UTC")
  list(
    version = v$version,
    pages = zpd_count(v$pages),
    title = v$title,
    author = v$author,
    subject = v$subject,
    keywords = v$keywords,
    creator = v$creator,
    producer = v$producer,
    language = v$language,
    created = utc(v$created),
    modified = utc(v$modified),
    id = v$id,
    encryption = zpd_encryption_names[[v$encryption + 1L]],
    permissions = zpd_permission_names(v$permissions)
  )
}

# pdfio_encryption_t, in enumerator order.
zpd_encryption_names <- c("none", "rc4-40", "rc4-128", "aes-128", "aes-256")

# pdfio_permission_t's bits (PDF 2.0, table 22).
zpd_permission_bits <- c(
  print = 0x0004,
  modify = 0x0008,
  copy = 0x0010,
  annotate = 0x0020,
  forms = 0x0100,
  reading = 0x0200,
  assemble = 0x0400,
  print_high = 0x0800
)

zpd_permission_names <- function(bits) {
  set <- bitwAnd(bits, zpd_permission_bits) != 0L
  names(zpd_permission_bits)[set]
}

# A count as an integer where it fits, a double beyond.
zpd_count <- function(n) {
  if (n <= .Machine$integer.max) as.integer(n) else n
}
