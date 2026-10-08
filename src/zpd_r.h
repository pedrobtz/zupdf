/* The .Call entry points, one declaration each; src/init.c registers them.
 * Only zpd_*.c files include pdfio's headers. */
#ifndef ZPD_R_H
#define ZPD_R_H

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

SEXP zupdf_build_info(void);

#endif
