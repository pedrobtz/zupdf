/* Internal declarations shared by the zpd_*.c files. Only these files
 * include pdfio's headers.
 *
 * The first half is R-free: zpd_core.c, zpd_lex.c, zpd_font.c and the walk
 * in zpd_text.c compile with -DZPD_STANDALONE for the fuzz target
 * (fuzz/fuzz_pdf.c) and the lint gate's standalone pass. */
#ifndef ZPD_H
#define ZPD_H

#include <stdbool.h>
#include <stddef.h>

#ifndef ZPD_STANDALONE
#include "zpd_r.h"
#endif

#include "pdfio.h"

/* ---- R-free ----------------------------------------------------------------- */

/* What pdfio reported through the error callback during one call: the
   first error (pdfio stops at it) and the first warning with a count. R
   raises them after the call returns (R/conditions.R), never during it. */
typedef struct zpd_record {
    char error[1024];
    int nerror;
    char warning[1024];
    int nwarning;
} zpd_record;

void zpd_record_reset(zpd_record *rec);

/* The error callback (D5): records and returns, never raises. Errors stop
   pdfio, warnings let it continue, as its default callback does. */
bool zpd_error_cb(pdfio_file_t *pdf, const char *message, void *data);

/* A pdf_file (design sections 4 and 13): everything pdfio allocates for an
 * open file lives here, owned by one external pointer whose finalizer
 * closes the file and removes a temporary copy. */
typedef struct zpd_file {
    pdfio_file_t *pdf;  /* NULL once closed */
    char *password;     /* the password to answer with, or NULL */
    int password_asked; /* times pdfio asked; answered only the first */
    char *tmpfile;      /* a spilled temporary copy to remove, or NULL */
    unsigned char *scratch; /* a stream read's buffer until R has copied it */
    struct zpd_font_cache *fonts; /* fonts loaded for text, by object */
    struct zpd_text_ctx *text;    /* the text walk's memory, during a call */
    zpd_record rec;     /* what pdfio reported during the current call */
} zpd_file;

/* zpd_text.c: free the text walk's memory and the font cache. */
void zpd_text_release(zpd_file *h);
void zpd_fonts_release(zpd_file *h);

/* zpd_core.c: pdfio's dictionary getters do not follow indirect
   references; these do, one level. zpd_inherited() finds the dictionary
   that supplies an inheritable page attribute through /Parent, bounded by
   max_depth (*deep is set when the bound is reached). */
pdfio_dict_t *zpd_dict_dict(pdfio_dict_t *dict, const char *key);
pdfio_array_t *zpd_dict_array(pdfio_dict_t *dict, const char *key);
pdfio_dict_t *zpd_inherited(pdfio_dict_t *dict, const char *key, int max_depth, int *deep);

/* A number read from a file, as an int clamped to [lo, hi] (NaN as 0):
   converting an out-of-range double to an integer is undefined. Every
   file-derived number becomes an integer through this (the fuzzer found
   the first that did not). */
static inline int zpd_clamp_int(double d, int lo, int hi)
{
    return d != d ? 0 : d <= (double) lo ? lo : d >= (double) hi ? hi : (int) d;
}

/* ---- R ---------------------------------------------------------------------- */

#ifndef ZPD_STANDALONE

/* The value every .Call that reaches pdfio returns: list(status, value,
   detail, nwarning, warning). `status` is "ok", "pdfio" (pdfio refused;
   `detail` is its message), "closed", or a limit's name. */
SEXP zpd_result(const char *status, SEXP value, const zpd_record *rec);

/* A result with a status and no pdfio record, such as "closed". */
SEXP zpd_status(const char *status);

/* The handle behind a pdf_file, or NULL when it is closed or not one. */
zpd_file *zpd_file_get(SEXP ptr);

/* zpd_value.c: PDF values to R and back (design section 6). `value` is a
   pdfio _pdfio_value_t; *deep is set when max_depth is reached. */
SEXP zpd_value_to_r(void *value, int max_depth, int *deep);
SEXP zpd_ref(size_t number, unsigned short generation);
void *zpd_obj_value(pdfio_obj_t *obj);
bool zpd_obj_has_stream(pdfio_obj_t *obj);
const char *zpd_value_from_r(pdfio_file_t *pdf, SEXP x, int max_depth,
                             pdfio_dict_t **dict, pdfio_array_t **array);
bool zpd_dict_set_text(pdfio_file_t *pdf, pdfio_dict_t *dict, const char *key, const char *utf8);
pdfio_obj_t *zpd_info_obj(pdfio_file_t *pdf);
SEXP zpd_catalog_to_r(pdfio_file_t *pdf, int max_depth, int *deep);

/* A character scalar from a PDF text string (zpd_string.c). */
SEXP zpd_mkchar_pdf(const char *s, size_t n);
SEXP zpd_string_or_na(const char *s);
bool zpd_is_utf16be(const unsigned char *b, size_t n);
SEXP zpd_mkchar_utf16be(const unsigned char *b, size_t n);

#endif /* !ZPD_STANDALONE */

#endif
