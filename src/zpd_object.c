/* Objects and streams (design sections 5, 6 and 12): the object table, one
 * object's value, and one object's stream. */

#include <math.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "zpd.h"

/* Errors pdfio reports for one broken object should not stop a table of a
   million: they become warnings, counted, the first kept. */
static void zpd_errors_to_warnings(zpd_record *rec)
{
    if (rec->nerror == 0)
        return;
    if (rec->nwarning == 0)
        memcpy(rec->warning, rec->error, sizeof(rec->warning));
    rec->nwarning += rec->nerror;
    rec->nerror = 0;
    rec->error[0] = '\0';
}

static SEXP zpd_chr_or_na(const char *s)
{
    return s ? zpd_mkchar_pdf(s, strlen(s)) : NA_STRING;
}

/* zupdf_objects(ptr): list(number, generation, type, subtype, length), one
   element per object in the cross-reference table. `length` is the stored
   stream length, NA for an object without a stream. */
SEXP zupdf_objects(SEXP ptr)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    size_t n = pdfioFileGetNumObjs(h->pdf);

    const char *names[] = {"number", "generation", "type", "subtype", "length", ""};
    SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP num = Rf_allocVector(REALSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 0, num);
    SEXP gen = Rf_allocVector(INTSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 1, gen);
    SEXP type = Rf_allocVector(STRSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 2, type);
    SEXP sub = Rf_allocVector(STRSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 3, sub);
    SEXP len = Rf_allocVector(REALSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 4, len);

    for (size_t i = 0; i < n; i++) {
        pdfio_obj_t *obj = pdfioFileGetObj(h->pdf, i);
        REAL(num)[i] = obj ? (double) pdfioObjGetNumber(obj) : NA_REAL;
        INTEGER(gen)[i] = obj ? pdfioObjGetGeneration(obj) : NA_INTEGER;
        SET_STRING_ELT(type, (R_xlen_t) i, obj ? zpd_chr_or_na(pdfioObjGetType(obj)) : NA_STRING);
        SET_STRING_ELT(sub, (R_xlen_t) i, obj ? zpd_chr_or_na(pdfioObjGetSubtype(obj)) : NA_STRING);
        REAL(len)[i] = (obj && zpd_obj_has_stream(obj)) ? (double) pdfioObjGetLength(obj) : NA_REAL;
        if ((i & 4095) == 4095)
            R_CheckUserInterrupt(); /* between pdfio calls, no stream open */
    }
    zpd_errors_to_warnings(&h->rec);
    SEXP out = zpd_result("ok", v, &h->rec);
    UNPROTECT(1);
    return out;
}

static pdfio_obj_t *zpd_find(zpd_file *h, SEXP number)
{
    double d = Rf_asReal(number);
    if (ISNAN(d) || d < 1 || d != floor(d))
        return NULL;
    return pdfioFileFindObj(h->pdf, (size_t) d);
}

/* zupdf_object(ptr, number, max_depth): list(value, stream). */
SEXP zupdf_object(SEXP ptr, SEXP number, SEXP max_depth)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    pdfio_obj_t *obj = zpd_find(h, number);
    if (!obj)
        return zpd_status("unknown_object");
    void *value = zpd_obj_value(obj);
    if (!value) {
        if (h->rec.nerror == 0) {
            h->rec.nerror = 1;
            strcpy(h->rec.error, "Unable to load the object.");
        }
        return zpd_result("pdfio", R_NilValue, &h->rec);
    }
    int deep = 0;
    const char *names[] = {"value", "stream", ""};
    SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(v, 0, zpd_value_to_r(value, Rf_asInteger(max_depth), &deep));
    SET_VECTOR_ELT(v, 1, Rf_ScalarLogical(zpd_obj_has_stream(obj)));
    SEXP out = zpd_result(deep ? "max_depth" : "ok", v, &h->rec);
    UNPROTECT(1);
    return out;
}

/* The object's /Filter as a character vector of filter names. */
static SEXP zpd_filters(pdfio_obj_t *obj)
{
    pdfio_dict_t *dict = pdfioObjGetDict(obj);
    if (!dict)
        return Rf_allocVector(STRSXP, 0);
    pdfio_valtype_t t = pdfioDictGetType(dict, "Filter");
    if (t == PDFIO_VALTYPE_NAME)
        return Rf_mkString(pdfioDictGetName(dict, "Filter"));
    pdfio_array_t *a = t == PDFIO_VALTYPE_ARRAY ? pdfioDictGetArray(dict, "Filter") : NULL;
    size_t n = a ? pdfioArrayGetSize(a) : 0;
    SEXP out = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n));
    for (size_t i = 0; i < n; i++) {
        const char *nm = pdfioArrayGetName(a, i);
        SET_STRING_ELT(out, (R_xlen_t) i, nm ? Rf_mkChar(nm) : NA_STRING);
    }
    UNPROTECT(1);
    return out;
}

/* Reads an open stream into h->scratch, at most max_stream bytes. No R
   call happens while the stream is open; the buffer belongs to the handle,
   so it is freed even if R fails to allocate the copy afterwards. Returns
   the byte count, or -1 for a pdfio error, -2 past max_stream, -3 out of
   memory. */
static double zpd_read_stream(zpd_file *h, pdfio_stream_t *st, double max_stream)
{
    size_t cap = 65536, n = 0;
    free(h->scratch);
    h->scratch = malloc(cap);
    if (!h->scratch)
        return -3;
    for (;;) {
        if (cap - n < 65536) {
            unsigned char *grown = realloc(h->scratch, cap * 2);
            if (!grown)
                return -3;
            h->scratch = grown;
            cap *= 2;
        }
        ssize_t got = pdfioStreamRead(st, h->scratch + n, cap - n);
        if (got < 0)
            return -1;
        if (got == 0)
            return (double) n;
        n += (size_t) got;
        if ((double) n > max_stream) /* GUARD: max_stream */
            return -2;
    }
}

/* zupdf_stream(ptr, number, decode, max_stream): list(bytes, decoded,
   filter). pdfio 1.6.5 decodes only FlateDecode; for any other filter a
   request to decode falls back to the stored bytes, with decoded = FALSE
   (design sections 5 and 9). */
SEXP zupdf_stream(SEXP ptr, SEXP number, SEXP decode_, SEXP max_stream_)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    pdfio_obj_t *obj = zpd_find(h, number);
    if (!obj)
        return zpd_status("unknown_object");
    if (!zpd_obj_value(obj) || !zpd_obj_has_stream(obj))
        return zpd_status("no_stream");

    bool decoded = Rf_asLogical(decode_) == TRUE;
    pdfio_stream_t *st = pdfioObjOpenStream(obj, decoded);
    if (!st && decoded && strncmp(h->rec.error, "Unsupported", 11) == 0) {
        zpd_record_reset(&h->rec);
        decoded = false;
        st = pdfioObjOpenStream(obj, false);
    }
    if (!st) {
        if (h->rec.nerror == 0) {
            h->rec.nerror = 1;
            strcpy(h->rec.error, "Unable to open the stream.");
        }
        return zpd_result("pdfio", R_NilValue, &h->rec);
    }
    double n = zpd_read_stream(h, st, Rf_asReal(max_stream_));
    pdfioStreamClose(st);

    if (n < 0) {
        free(h->scratch);
        h->scratch = NULL;
        if (n == -2)
            return zpd_status("max_stream");
        if (h->rec.nerror == 0) {
            h->rec.nerror = 1;
            strcpy(h->rec.error, n == -3 ? "Unable to allocate memory for the stream."
                                         : "Unable to read the stream.");
        }
        return zpd_result("pdfio", R_NilValue, &h->rec);
    }

    const char *names[] = {"bytes", "decoded", "filter", ""};
    SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP bytes = Rf_allocVector(RAWSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 0, bytes);
    if (n > 0)
        memcpy(RAW(bytes), h->scratch, (size_t) n);
    free(h->scratch);
    h->scratch = NULL;
    SET_VECTOR_ELT(v, 1, Rf_ScalarLogical(decoded));
    SET_VECTOR_ELT(v, 2, zpd_filters(obj));
    SEXP out = zpd_result("ok", v, &h->rec);
    UNPROTECT(1);
    return out;
}

/* zupdf_doc_dict(ptr, which, max_depth): the catalog ("catalog") or the
   information dictionary ("info") as R values, NULL when absent. */
SEXP zupdf_doc_dict(SEXP ptr, SEXP which, SEXP max_depth_)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    int max_depth = Rf_asInteger(max_depth_), deep = 0;
    SEXP v = R_NilValue;
    if (strcmp(CHAR(STRING_ELT(which, 0)), "info") == 0) {
        pdfio_obj_t *obj = zpd_info_obj(h->pdf);
        void *value = obj ? zpd_obj_value(obj) : NULL;
        if (value)
            v = zpd_value_to_r(value, max_depth, &deep);
    } else {
        v = zpd_catalog_to_r(h->pdf, max_depth, &deep);
    }
    PROTECT(v);
    SEXP out = zpd_result(deep ? "max_depth" : "ok", v, &h->rec);
    UNPROTECT(1);
    return out;
}
