/* The .Call entry points, one declaration each; src/init.c registers them.
 * Only zpd_*.c files include pdfio's headers. */
#ifndef ZPD_R_H
#define ZPD_R_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

SEXP zupdf_build_info(void);

/* zpd_file.c */
SEXP zupdf_open(SEXP path, SEXP password, SEXP owned);
SEXP zupdf_close(SEXP ptr);
SEXP zupdf_is_open(SEXP ptr);
SEXP zupdf_counts(SEXP ptr);
SEXP zupdf_meta(SEXP ptr);
SEXP zupdf_pages(SEXP ptr, SEXP max_depth);
SEXP zupdf_page_xobjects(SEXP ptr, SEXP page, SEXP max_depth);
SEXP zupdf_native_raster(SEXP bytes, SEXP width, SEXP height, SEXP channels);

/* zpd_text.c */
SEXP zupdf_page_text(SEXP ptr, SEXP pages, SEXP raw, SEXP max_depth, SEXP max_stream);
SEXP zupdf_page_tokens(SEXP ptr, SEXP page, SEXP max_stream);

/* zpd_object.c */
SEXP zupdf_objects(SEXP ptr);
SEXP zupdf_object(SEXP ptr, SEXP number, SEXP max_depth);
SEXP zupdf_stream(SEXP ptr, SEXP number, SEXP decode, SEXP max_stream);
SEXP zupdf_doc_dict(SEXP ptr, SEXP which, SEXP max_depth);

/* zpd_writer.c */
SEXP zupdf_writer_new(SEXP version, SEXP media_box);
SEXP zupdf_writer_is_open(SEXP ptr);
SEXP zupdf_writer_font(SEXP ptr, SEXP kind, SEXP name);
SEXP zupdf_writer_image_file(SEXP ptr, SEXP path, SEXP interpolate);
SEXP zupdf_writer_image_data(SEXP ptr, SEXP bytes, SEXP width, SEXP height,
                             SEXP colors, SEXP alpha, SEXP interpolate);
SEXP zupdf_writer_page(SEXP ptr, SEXP media_box, SEXP crop_box, SEXP dict,
                       SEXP ops, SEXP nums, SEXP strs, SEXP max_depth);
SEXP zupdf_writer_save(SEXP ptr, SEXP created, SEXP deterministic);
SEXP zupdf_writer_copy_pages(SEXP ptr, SEXP file, SEXP pages, SEXP rotate, SEXP absolute);
SEXP zupdf_writer_set_meta(SEXP ptr, SEXP keys, SEXP values, SEXP modified);
SEXP zupdf_writer_set_encryption(SEXP ptr, SEXP method, SEXP permissions, SEXP owner, SEXP user);

/* zpd_roundtrip.c */
SEXP zupdf_value_roundtrip(SEXP x, SEXP max_depth);

#endif
