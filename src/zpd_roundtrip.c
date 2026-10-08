/* zupdf_value_roundtrip(): writes an R list as one object of a one-page PDF
 * in memory, so the tests can read it back through pdf_object() and check
 * design section 6 in both directions before the writer exists (roadmap
 * Stage 2). Internal: not exported. Stage 4's writer reuses
 * zpd_value_from_r() the same way.
 *
 * The file being written lives in an external pointer, so an R error while
 * the list is converted (which reads R strings) cannot leak it. */

#include <stdlib.h>
#include <string.h>

#include "zpd.h"

typedef struct {
    pdfio_file_t *pdf;
    unsigned char *buf;
    size_t n, cap;
    bool oom;
    zpd_record rec;
} zpd_membuf;

static ssize_t zpd_membuf_out(void *ctx, const void *data, size_t len)
{
    zpd_membuf *m = ctx;
    if (m->n + len > m->cap) {
        size_t cap = m->cap ? m->cap : 4096;
        while (cap < m->n + len)
            cap *= 2;
        unsigned char *grown = realloc(m->buf, cap);
        if (!grown) {
            m->oom = true;
            return -1;
        }
        m->buf = grown;
        m->cap = cap;
    }
    memcpy(m->buf + m->n, data, len);
    m->n += len;
    return (ssize_t) len;
}

static void zpd_membuf_finalize(SEXP ptr)
{
    zpd_membuf *m = R_ExternalPtrAddr(ptr);
    if (!m)
        return;
    if (m->pdf)
        pdfioFileClose(m->pdf);
    free(m->buf);
    free(m);
    R_ClearExternalPtr(ptr);
}

SEXP zupdf_value_roundtrip(SEXP x, SEXP max_depth)
{
    zpd_membuf *m = calloc(1, sizeof(*m));
    if (!m)
        return zpd_status("pdfio");
    zpd_record_reset(&m->rec);
    SEXP ptr = PROTECT(R_MakeExternalPtr(m, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(ptr, zpd_membuf_finalize, TRUE);

    pdfio_rect_t box = {0.0, 0.0, 612.0, 792.0};
    m->pdf = pdfioFileCreateOutput(zpd_membuf_out, m, "2.0", &box, &box,
                                   zpd_error_cb, &m->rec);
    if (!m->pdf) {
        UNPROTECT(1);
        return zpd_result("pdfio", R_NilValue, &m->rec);
    }

    pdfio_dict_t *dict;
    pdfio_array_t *array;
    const char *status = zpd_value_from_r(m->pdf, x, Rf_asInteger(max_depth), &dict, &array);
    if (status) {
        SEXP out = zpd_result(status, R_NilValue, &m->rec);
        UNPROTECT(1);
        return out;
    }
    pdfio_obj_t *obj = dict ? pdfioFileCreateObj(m->pdf, dict)
                            : pdfioFileCreateArrayObj(m->pdf, array);
    bool ok = obj && pdfioObjClose(obj);
    size_t number = obj ? pdfioObjGetNumber(obj) : 0;

    pdfio_dict_t *page = pdfioDictCreate(m->pdf);
    pdfio_stream_t *st = page ? pdfioFileCreatePage(m->pdf, page) : NULL;
    ok = ok && st && pdfioStreamClose(st);
    ok = pdfioFileClose(m->pdf) && ok && !m->oom;
    m->pdf = NULL;
    if (!ok) {
        SEXP out = zpd_result("pdfio", R_NilValue, &m->rec);
        UNPROTECT(1);
        return out;
    }

    const char *names[] = {"bytes", "number", ""};
    SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP bytes = Rf_allocVector(RAWSXP, (R_xlen_t) m->n);
    SET_VECTOR_ELT(v, 0, bytes);
    memcpy(RAW(bytes), m->buf, m->n);
    SET_VECTOR_ELT(v, 1, Rf_ScalarReal((double) number));
    SEXP out = zpd_result("ok", v, &m->rec);
    UNPROTECT(2);
    return out;
}
