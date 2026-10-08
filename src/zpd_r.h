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

/* zpd_roundtrip.c */
SEXP zupdf_value_roundtrip(SEXP x, SEXP max_depth);

#endif
