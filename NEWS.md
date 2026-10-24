# zupdf 0.1.0

* First release: reads, assembles and writes PDF files through a bundled
  copy of pdfio, with no system library beyond zlib.
* Untrusted input is bounded as a whole, not only stream by stream:
  `max_stream` covers everything one page's text walk reads, each form
  counted every time it is drawn; `max_objects` is enforced while the
  cross-reference table is read; copying refuses references nested deeper
  than 2 048 values. Text extraction can be interrupted inside a page.
* `pdf_copy_pages()` and the qpdf functions copy only the pages asked for:
  links and annotations that point at other pages lead to the copies or to
  null, and pages take only inheritable attributes from the page tree. The
  qpdf functions refuse to overwrite an input.
* Passwords are written and tried in PDFDocEncoding, as the standard says;
  the pdftools readers try the user password, then the owner password.
* `pdf_save()` keeps the writer open when the destination cannot be
  written, and a write that fails afterwards keeps the file in the
  condition's `bytes` field. A page that fails in `pdf_page_end()` never
  blocks saving the rest.
* Every error is a classed `zupdf_error`, malformed values in a file
  included. `deterministic = TRUE` hashes the whole file for its
  identifier.
* `pdf_text_width()` measures text for layout. Four vignettes: inspecting a
  PDF, assembling PDFs, writing a report from R, and switching from
  pdftools and qpdf.
* pdftools's and qpdf's non-rendering functions under their own names and
  arguments: `pdf_info()`, `pdf_text()`, `pdf_fonts()`, `pdf_pagesize()`,
  `pdf_toc()`, `pdf_attachments()`, `pdf_data()`, `pdf_length()`, `pdf_split()`,
  `pdf_subset()`, `pdf_combine()` and `pdf_rotate_pages()`, so
  `library(zupdf)` can stand in for either package where no rendering is
  needed.
* `pdf_copy_pages()` copies pages between files, with rotation;
  `pdf_set_meta()` sets the document information; `pdf_set_encryption()`
  encrypts with AES-128 or RC4-128 and sets permissions.
* A writer: `pdf_new()` starts a file, `pdf_page_new()` and `pdf_page_end()`
  add pages, `pdf_draw_text()`, `pdf_draw()` and `pdf_draw_image()` draw
  text, paths and images, `pdf_font()` and `pdf_image_new()` make fonts
  (base-14 or embedded TrueType/OpenType) and images (PNG, JPEG or R
  images), and `pdf_save()` returns or writes the bytes. `deterministic =
  TRUE` makes the output reproducible. `pdf_paper()` gives paper sizes.
* `pdf_page_text()` extracts each page's text in reading order or stream
  order, through ToUnicode maps, font encodings and Form XObjects, with
  U+FFFD and a count for characters no font maps. `pdf_page_tokens()`
  lists a content stream's tokens.
* `pdf_font_table()` lists the fonts; `pdf_page_images()` a page's images;
  `pdf_image()` reads an image's samples, or a `nativeRaster` for 8-bit RGB
  and grey.
* `pdf_objects()` lists every object; `pdf_object()` reads one object's
  value as R values, with marker classes for names (`pdf_name`),
  references (`pdf_ref`) and byte strings (`pdf_binary`); `pdf_stream()`
  reads a stream, decoded (FlateDecode) or as stored, bounded by
  `max_stream`.
* `pdf_open()` opens a PDF from a path, a raw vector or a connection, with
  an optional password (a string, or a function called only when the file
  needs one), under limits on input size, object count and page count.
  `pdf_close()` closes it.
* `pdf_meta()` reads the version, page count, information dictionary,
  identifier, encryption and permissions; `pdf_pages()` the page boxes,
  rotation and content-stream count, with inherited attributes.
* `zupdf_info()` reports the bundled pdfio (1.6.5, with its ttf library),
  the local patches, the zlib it was linked against, the features this
  build lacks and the default limits.
