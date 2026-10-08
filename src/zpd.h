/* Internal declarations shared by the zpd_*.c files. Only these files
 * include pdfio's headers. */
#ifndef ZPD_H
#define ZPD_H

#include "zpd_r.h"

#include "pdfio.h"

/* What pdfio reported through the error callback during one .Call: the
   first error (pdfio stops at it) and the first warning with a count. R
   raises them after the call returns (R/conditions.R), never during it. */
typedef struct zpd_record {
    char error[1024];
    int nerror;
    char warning[1024];
    int nwarning;
} zpd_record;

void zpd_record_reset(zpd_record *rec);

/* The value every .Call that reaches pdfio returns: list(status, value,
   detail, nwarning, warning). `status` is "ok", "pdfio" (pdfio refused;
   `detail` is its message), "closed", or a limit's name. */
SEXP zpd_result(const char *status, SEXP value, const zpd_record *rec);

/* A pdf_file (design sections 4 and 13): everything pdfio allocates for an
 * open file lives here, owned by one external pointer whose finalizer
 * closes the file and removes a temporary copy. */
typedef struct zpd_file {
    pdfio_file_t *pdf;  /* NULL once closed */
    char *password;     /* the password to answer with, or NULL */
    int password_asked; /* times pdfio asked; answered only the first */
    char *tmpfile;      /* a spilled temporary copy to remove, or NULL */
    zpd_record rec;     /* what pdfio reported during the current call */
} zpd_file;

/* The error callback (D5): records and returns, never raises. Errors stop
   pdfio, warnings let it continue, as its default callback does. */
bool zpd_error_cb(pdfio_file_t *pdf, const char *message, void *data);

/* The handle behind a pdf_file, or NULL when it is closed or not one. */
zpd_file *zpd_file_get(SEXP ptr);

/* A character scalar from a PDF text string (zpd_string.c). */
SEXP zpd_mkchar_pdf(const char *s, size_t n);
SEXP zpd_string_or_na(const char *s);

#endif
