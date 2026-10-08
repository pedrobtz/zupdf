# Changelog

## zupdf 0.0.0.9000

- Development version, built stage by stage; see the roadmap.
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
