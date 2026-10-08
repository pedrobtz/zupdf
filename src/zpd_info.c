/* zupdf_info(): what was built (design section 5). The vendored version and
 * the patch series are compiled in, so the report describes this binary;
 * tools/verify-vendor checks ZPD_PDFIO_VERSION against PROVENANCE and
 * test-info.R checks the patch list. */

#include <string.h>

#include "zpd_r.h"

#include "pdfio.h"
#include "pdfio-content.h"
#include <zlib.h>

#define ZPD_PDFIO_VERSION "1.6.5"

/* The patch series of tools/patches/, in order, without the .patch suffix. */
static const char *zpd_patches[] = {
    "0001-visibility-override",
    "0002-no-stdio",
    "0003-date-buffer",
    "0004-undefined-behaviour",
};

/* Features pdfio 1.7.0 adds that the 1.6.5 pin lacks (design section 9).
   zupdf_info() lists them until the pin moves (D12). */
static const char *zpd_absent[] = {
    "lzw",
    "gif",
    "object_streams",
    "page_accessors",
    "windows_unicode_paths",
};

#define ZPD_COUNT(a) (sizeof(a) / sizeof((a)[0]))

/* ---- self-test: write a one-page PDF into memory ------------------------- */

typedef struct {
    unsigned char head[8];
    size_t n;
} zpd_smoke_buf;

static ssize_t zpd_smoke_out(void *ctx, const void *data, size_t len)
{
    zpd_smoke_buf *b = ctx;
    size_t room = sizeof(b->head) - (b->n < sizeof(b->head) ? b->n : sizeof(b->head));
    size_t take = len < room ? len : room;
    if (take)
        memcpy(b->head + b->n, data, take);
    b->n += len;
    return (ssize_t) len;
}

/* Records nothing and stops on errors, continues on warnings: the self-test
   only asks whether the write succeeded. */
static bool zpd_smoke_error(pdfio_file_t *pdf, const char *message, void *data)
{
    (void) pdf;
    (void) data;
    return strncmp(message, "WARNING:", 8) == 0;
}

/* pdfio, its Flate writer and zlib together produce a file that starts with
   the PDF header and is closed without error. */
static int zpd_smoke_writes(void)
{
    zpd_smoke_buf buf = {{0}, 0};
    pdfio_rect_t box = {0.0, 0.0, 612.0, 792.0};
    pdfio_file_t *pdf = pdfioFileCreateOutput(zpd_smoke_out, &buf, "1.7", &box,
                                              &box, zpd_smoke_error, NULL);
    if (!pdf)
        return 0;
    pdfio_dict_t *dict = pdfioDictCreate(pdf);
    pdfio_stream_t *st = dict ? pdfioFileCreatePage(pdf, dict) : NULL;
    int ok = st != NULL;
    if (st) {
        ok = pdfioContentPathRect(st, 72.0, 72.0, 100.0, 100.0) &&
             pdfioContentStroke(st);
        ok = pdfioStreamClose(st) && ok;
    }
    ok = pdfioFileClose(pdf) && ok;
    return ok && buf.n > 64 && memcmp(buf.head, "%PDF-1.7", 8) == 0;
}

/* ---- the report ---------------------------------------------------------- */

static SEXP zpd_strings(const char **x, size_t n)
{
    SEXP out = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n));
    for (size_t i = 0; i < n; i++)
        SET_STRING_ELT(out, (R_xlen_t) i, Rf_mkChar(x[i]));
    UNPROTECT(1);
    return out;
}

SEXP zupdf_build_info(void)
{
    const char *names[] = {"pdfio_version", "pdfio_header_version",
                           "zlib_version",  "patches",
                           "absent",        "smoke_ok",
                           ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString(ZPD_PDFIO_VERSION));
    SET_VECTOR_ELT(out, 1, Rf_mkString(PDFIO_VERSION));
    SET_VECTOR_ELT(out, 2, Rf_mkString(zlibVersion()));
    SET_VECTOR_ELT(out, 3, zpd_strings(zpd_patches, ZPD_COUNT(zpd_patches)));
    SET_VECTOR_ELT(out, 4, zpd_strings(zpd_absent, ZPD_COUNT(zpd_absent)));
    SET_VECTOR_ELT(out, 5, Rf_ScalarLogical(zpd_smoke_writes()));
    UNPROTECT(1);
    return out;
}
