# zupdf 0.0.0.9000

* Development version, built stage by stage; see the roadmap.
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
