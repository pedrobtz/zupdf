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

#endif
