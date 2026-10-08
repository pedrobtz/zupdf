#' zupdf: read, assemble and write PDF files
#'
#' zupdf opens PDF files and reads their metadata, pages, objects, streams,
#' fonts, images and text; copies pages between files to split, merge,
#' rotate and reorder them; and writes new PDF files from R with text, paths
#' and images. It never renders a page to pixels: for that, use pdftools.
#' It bundles the pdfio C library, so it needs no system library beyond
#' zlib.
#'
#' @section Reading:
#' [pdf_open()] opens a file, from a path, raw vector or connection, under
#' limits on size, objects, streams and nesting that make hostile input
#' safe. [pdf_meta()], [pdf_pages()], [pdf_page_text()], [pdf_font_table()],
#' [pdf_page_images()] and [pdf_image()] read it; [pdf_objects()],
#' [pdf_object()] and [pdf_stream()] reach every object.
#'
#' @section Writing:
#' [pdf_new()] starts a file; [pdf_page_new()] and [pdf_page_end()] add
#' pages; [pdf_draw_text()], [pdf_draw()] and [pdf_draw_image()] draw on
#' them; [pdf_copy_pages()] copies pages from other files;
#' [pdf_set_meta()] and [pdf_set_encryption()] set information and
#' encryption; [pdf_save()] finishes.
#'
#' @section pdftools and qpdf:
#' Their functions that need no renderer exist here under their own names
#' and arguments ([pdftools-compat], [qpdf-compat]), so `library(zupdf)` can
#' stand in for either package. Attaching zupdf after them masks theirs.
#'
#' @seealso [zupdf-conditions] for the errors zupdf raises; [zupdf_info()]
#'   for the bundled library.
#' @keywords package
"_PACKAGE"

## usethis namespace: start
#' @useDynLib zupdf, .registration = TRUE
## usethis namespace: end
NULL
