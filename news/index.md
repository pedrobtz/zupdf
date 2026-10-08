# Changelog

## zupdf 0.0.0.9000

- First release: reads, assembles and writes PDF files through a bundled
  copy of pdfio, with no system library beyond zlib.
- [`pdf_text_width()`](https://pedrobtz.github.io/zupdf/reference/pdf_text_width.md)
  measures text for layout. Four vignettes: inspecting a PDF, assembling
  PDFs, writing a report from R, and switching from pdftools and qpdf.
- pdftools’s and qpdf’s non-rendering functions under their own names
  and arguments:
  [`pdf_info()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md),
  [`pdf_text()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md),
  [`pdf_fonts()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md),
  [`pdf_pagesize()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md),
  [`pdf_toc()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md),
  [`pdf_attachments()`](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md),
  [`pdf_data()`](https://pedrobtz.github.io/zupdf/reference/pdf_data.md),
  [`pdf_length()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md),
  [`pdf_split()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md),
  [`pdf_subset()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md),
  [`pdf_combine()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md)
  and
  [`pdf_rotate_pages()`](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md),
  so [`library(zupdf)`](https://github.com/pedrobtz/zupdf) can stand in
  for either package where no rendering is needed.
- [`pdf_copy_pages()`](https://pedrobtz.github.io/zupdf/reference/pdf_copy_pages.md)
  copies pages between files, with rotation;
  [`pdf_set_meta()`](https://pedrobtz.github.io/zupdf/reference/pdf_set_meta.md)
  sets the document information;
  [`pdf_set_encryption()`](https://pedrobtz.github.io/zupdf/reference/pdf_set_encryption.md)
  encrypts with AES-128 or RC4-128 and sets permissions.
- A writer:
  [`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md)
  starts a file,
  [`pdf_page_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md)
  and
  [`pdf_page_end()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md)
  add pages,
  [`pdf_draw_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_text.md),
  [`pdf_draw()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw.md)
  and
  [`pdf_draw_image()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_image.md)
  draw text, paths and images,
  [`pdf_font()`](https://pedrobtz.github.io/zupdf/reference/pdf_font.md)
  and
  [`pdf_image_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_image_new.md)
  make fonts (base-14 or embedded TrueType/OpenType) and images (PNG,
  JPEG or R images), and
  [`pdf_save()`](https://pedrobtz.github.io/zupdf/reference/pdf_save.md)
  returns or writes the bytes. `deterministic = TRUE` makes the output
  reproducible.
  [`pdf_paper()`](https://pedrobtz.github.io/zupdf/reference/pdf_paper.md)
  gives paper sizes.
- [`pdf_page_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_text.md)
  extracts each page’s text in reading order or stream order, through
  ToUnicode maps, font encodings and Form XObjects, with U+FFFD and a
  count for characters no font maps.
  [`pdf_page_tokens()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_tokens.md)
  lists a content stream’s tokens.
- [`pdf_font_table()`](https://pedrobtz.github.io/zupdf/reference/pdf_font_table.md)
  lists the fonts;
  [`pdf_page_images()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_images.md)
  a page’s images;
  [`pdf_image()`](https://pedrobtz.github.io/zupdf/reference/pdf_image.md)
  reads an image’s samples, or a `nativeRaster` for 8-bit RGB and grey.
- [`pdf_objects()`](https://pedrobtz.github.io/zupdf/reference/pdf_objects.md)
  lists every object;
  [`pdf_object()`](https://pedrobtz.github.io/zupdf/reference/pdf_object.md)
  reads one object’s value as R values, with marker classes for names
  (`pdf_name`), references (`pdf_ref`) and byte strings (`pdf_binary`);
  [`pdf_stream()`](https://pedrobtz.github.io/zupdf/reference/pdf_stream.md)
  reads a stream, decoded (FlateDecode) or as stored, bounded by
  `max_stream`.
- [`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md)
  opens a PDF from a path, a raw vector or a connection, with an
  optional password (a string, or a function called only when the file
  needs one), under limits on input size, object count and page count.
  [`pdf_close()`](https://pedrobtz.github.io/zupdf/reference/pdf_close.md)
  closes it.
- [`pdf_meta()`](https://pedrobtz.github.io/zupdf/reference/pdf_meta.md)
  reads the version, page count, information dictionary, identifier,
  encryption and permissions;
  [`pdf_pages()`](https://pedrobtz.github.io/zupdf/reference/pdf_pages.md)
  the page boxes, rotation and content-stream count, with inherited
  attributes.
- [`zupdf_info()`](https://pedrobtz.github.io/zupdf/reference/zupdf_info.md)
  reports the bundled pdfio (1.6.5, with its ttf library), the local
  patches, the zlib it was linked against, the features this build lacks
  and the default limits.
