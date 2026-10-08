# zupdf: read, assemble and write PDF files

zupdf opens PDF files and reads their metadata, pages, objects, streams,
fonts, images and text; copies pages between files to split, merge,
rotate and reorder them; and writes new PDF files from R with text,
paths and images. It never renders a page to pixels: for that, use
pdftools. It bundles the pdfio C library, so it needs no system library
beyond zlib.

## Reading

[`pdf_open()`](https://pedrobtz.github.io/zupdf/reference/pdf_open.md)
opens a file, from a path, raw vector or connection, under limits on
size, objects, streams and nesting that make hostile input safe.
[`pdf_meta()`](https://pedrobtz.github.io/zupdf/reference/pdf_meta.md),
[`pdf_pages()`](https://pedrobtz.github.io/zupdf/reference/pdf_pages.md),
[`pdf_page_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_text.md),
[`pdf_font_table()`](https://pedrobtz.github.io/zupdf/reference/pdf_font_table.md),
[`pdf_page_images()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_images.md)
and
[`pdf_image()`](https://pedrobtz.github.io/zupdf/reference/pdf_image.md)
read it;
[`pdf_objects()`](https://pedrobtz.github.io/zupdf/reference/pdf_objects.md),
[`pdf_object()`](https://pedrobtz.github.io/zupdf/reference/pdf_object.md)
and
[`pdf_stream()`](https://pedrobtz.github.io/zupdf/reference/pdf_stream.md)
reach every object.

## Writing

[`pdf_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_new.md)
starts a file;
[`pdf_page_new()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md)
and
[`pdf_page_end()`](https://pedrobtz.github.io/zupdf/reference/pdf_page_new.md)
add pages;
[`pdf_draw_text()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_text.md),
[`pdf_draw()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw.md)
and
[`pdf_draw_image()`](https://pedrobtz.github.io/zupdf/reference/pdf_draw_image.md)
draw on them;
[`pdf_copy_pages()`](https://pedrobtz.github.io/zupdf/reference/pdf_copy_pages.md)
copies pages from other files;
[`pdf_set_meta()`](https://pedrobtz.github.io/zupdf/reference/pdf_set_meta.md)
and
[`pdf_set_encryption()`](https://pedrobtz.github.io/zupdf/reference/pdf_set_encryption.md)
set information and encryption;
[`pdf_save()`](https://pedrobtz.github.io/zupdf/reference/pdf_save.md)
finishes.

## pdftools and qpdf

Their functions that need no renderer exist here under their own names
and arguments
([pdftools-compat](https://pedrobtz.github.io/zupdf/reference/pdftools-compat.md),
[qpdf-compat](https://pedrobtz.github.io/zupdf/reference/qpdf-compat.md)),
so [`library(zupdf)`](https://github.com/pedrobtz/zupdf) can stand in
for either package. Attaching zupdf after them masks theirs.

## See also

[zupdf-conditions](https://pedrobtz.github.io/zupdf/reference/zupdf-conditions.md)
for the errors zupdf raises;
[`zupdf_info()`](https://pedrobtz.github.io/zupdf/reference/zupdf_info.md)
for the bundled library.

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Other contributors:

- Michael R Sweet (pdfio and ttf, bundled in src/vendor/pdfio)
  \[copyright holder\]

- Adobe (Adobe Glyph List, in src/zpd_glyphs.h) \[copyright holder\]
