/* PDF values to R and back (design section 6).
 *
 * The walk reads pdfio's value structures through pdfio-private.h: the
 * public API cannot give the numbers of an indirect reference whose target
 * is missing, nor the value of an object that is neither a dictionary nor
 * an array. Recursion is bounded by max_depth; pdfio's own parser already
 * refuses nesting deeper than PDFIO_MAX_DEPTH (32).
 *
 * PDF to R allocates R objects while walking pdfio's memory, never while a
 * pdfio stream is open, so an R error cannot leave pdfio mid-call. R to
 * PDF allocates only R_alloc() scratch space; what pdfio allocates belongs
 * to the file, which the writer's finalizer closes. */

#include <limits.h>
#include <math.h>
#include <string.h>

#include "zpd.h"
#include "pdfio-private.h"

/* ---- PDF to R ---------------------------------------------------------------- */

static void zpd_set_class(SEXP x, const char *cls)
{
    Rf_setAttrib(x, R_ClassSymbol, Rf_mkString(cls));
}

static SEXP zpd_number(double d)
{
    if (d == floor(d) && fabs(d) <= INT_MAX)
        return Rf_ScalarInteger((int) d);
    return Rf_ScalarReal(d);
}

static SEXP zpd_posixct(time_t t)
{
    SEXP x = PROTECT(Rf_ScalarReal((double) t));
    SEXP cls = PROTECT(Rf_allocVector(STRSXP, 2));
    SET_STRING_ELT(cls, 0, Rf_mkChar("POSIXct"));
    SET_STRING_ELT(cls, 1, Rf_mkChar("POSIXt"));
    Rf_setAttrib(x, R_ClassSymbol, cls);
    Rf_setAttrib(x, Rf_install("tzone"), Rf_mkString("UTC"));
    UNPROTECT(2);
    return x;
}

SEXP zpd_ref(size_t number, unsigned short generation)
{
    SEXP x = PROTECT(Rf_ScalarInteger(number > INT_MAX ? NA_INTEGER : (int) number));
    Rf_setAttrib(x, Rf_install("generation"), Rf_ScalarInteger(generation));
    zpd_set_class(x, "pdf_ref");
    UNPROTECT(1);
    return x;
}

static SEXP zpd_value_rec(_pdfio_value_t *v, int depth, int max_depth, int *deep);

static SEXP zpd_array_rec(pdfio_array_t *a, int depth, int max_depth, int *deep)
{
    size_t n = a ? a->num_values : 0;
    SEXP out = PROTECT(Rf_allocVector(VECSXP, (R_xlen_t) n));
    for (size_t i = 0; i < n && !*deep; i++)
        SET_VECTOR_ELT(out, (R_xlen_t) i,
                       zpd_value_rec(&a->values[i], depth + 1, max_depth, deep));
    UNPROTECT(1);
    return out;
}

static SEXP zpd_dict_rec(pdfio_dict_t *d, int depth, int max_depth, int *deep)
{
    size_t n = d ? d->num_pairs : 0;
    SEXP out = PROTECT(Rf_allocVector(VECSXP, (R_xlen_t) n));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n));
    for (size_t i = 0; i < n && !*deep; i++) {
        _pdfio_pair_t *p = &d->pairs[i];
        SET_STRING_ELT(names, (R_xlen_t) i, zpd_mkchar_pdf(p->key, strlen(p->key)));
        SET_VECTOR_ELT(out, (R_xlen_t) i,
                       zpd_value_rec(&p->value, depth + 1, max_depth, deep));
    }
    Rf_setAttrib(out, R_NamesSymbol, names);
    UNPROTECT(2);
    return out;
}

static SEXP zpd_value_rec(_pdfio_value_t *v, int depth, int max_depth, int *deep)
{
    if (depth > max_depth) { /* GUARD: max_depth */
        *deep = 1;
        return R_NilValue;
    }
    SEXP x;
    switch (v->type) {
    case PDFIO_VALTYPE_ARRAY:
        return zpd_array_rec(v->value.array, depth, max_depth, deep);
    case PDFIO_VALTYPE_DICT:
        return zpd_dict_rec(v->value.dict, depth, max_depth, deep);
    case PDFIO_VALTYPE_BINARY:
        if (zpd_is_utf16be(v->value.binary.data, v->value.binary.datalen))
            return Rf_ScalarString(zpd_mkchar_utf16be(v->value.binary.data,
                                                      v->value.binary.datalen));
        x = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) v->value.binary.datalen));
        if (v->value.binary.datalen)
            memcpy(RAW(x), v->value.binary.data, v->value.binary.datalen);
        zpd_set_class(x, "pdf_binary");
        UNPROTECT(1);
        return x;
    case PDFIO_VALTYPE_BOOLEAN:
        return Rf_ScalarLogical(v->value.boolean);
    case PDFIO_VALTYPE_DATE:
        return zpd_posixct(v->value.date);
    case PDFIO_VALTYPE_INDIRECT:
        return zpd_ref(v->value.indirect.number, v->value.indirect.generation);
    case PDFIO_VALTYPE_NAME:
        x = PROTECT(zpd_string_or_na(v->value.name));
        zpd_set_class(x, "pdf_name");
        UNPROTECT(1);
        return x;
    case PDFIO_VALTYPE_NUMBER:
        return zpd_number(v->value.number);
    case PDFIO_VALTYPE_STRING:
        return zpd_string_or_na(v->value.string);
    case PDFIO_VALTYPE_NULL:
    case PDFIO_VALTYPE_NONE:
    default:
        return R_NilValue;
    }
}

SEXP zpd_value_to_r(void *value, int max_depth, int *deep)
{
    *deep = 0;
    return zpd_value_rec((_pdfio_value_t *) value, 0, max_depth, deep);
}

/* The value an object holds, loading it first. NULL if it cannot load. */
void *zpd_obj_value(pdfio_obj_t *obj)
{
    if (obj->value.type == PDFIO_VALTYPE_NONE && !_pdfioObjLoad(obj))
        return NULL;
    return &obj->value;
}

bool zpd_obj_has_stream(pdfio_obj_t *obj)
{
    return obj->stream_offset > 0;
}

/* ---- R to PDF ---------------------------------------------------------------- */

/* A string for a text string: ASCII is written as it is; anything else as
   UTF-16BE with a byte-order mark, which every reader decodes (pdfio would
   otherwise write the UTF-8 bytes into a literal, which readers take as
   PDFDocEncoding). Returns false only if pdfio refuses. */
typedef struct {
    bool (*set_string)(void *ctx, const char *s);
    bool (*set_binary)(void *ctx, const unsigned char *b, size_t n);
    void *ctx;
} zpd_text_sink;

static size_t zpd_utf8_decode(const unsigned char *s, size_t n, size_t *i)
{
    unsigned c = s[*i];
    size_t len = c < 0x80 ? 1 : c < 0xE0 ? 2 : c < 0xF0 ? 3 : 4;
    if (*i + len > n)
        len = n - *i;
    unsigned cp = len == 1 ? c : len == 2 ? (c & 0x1F) : len == 3 ? (c & 0x0F) : (c & 0x07);
    for (size_t k = 1; k < len; k++)
        cp = (cp << 6) | (s[*i + k] & 0x3F);
    *i += len;
    return cp;
}

static bool zpd_put_text(zpd_text_sink *sink, const char *s)
{
    size_t n = strlen(s);
    bool ascii = true;
    for (size_t i = 0; i < n; i++)
        if ((unsigned char) s[i] >= 0x80 || (unsigned char) s[i] < 0x20) {
            ascii = false;
            break;
        }
    if (ascii)
        return sink->set_string(sink->ctx, s);
    /* At most two UTF-16 units of two bytes per input byte, plus the BOM. */
    unsigned char *buf = (unsigned char *) R_alloc(4 * n + 2, 1);
    size_t k = 0;
    buf[k++] = 0xFE;
    buf[k++] = 0xFF;
    for (size_t i = 0; i < n;) {
        size_t cp = zpd_utf8_decode((const unsigned char *) s, n, &i);
        if (cp >= 0x10000) {
            cp -= 0x10000;
            unsigned hi = 0xD800 + (unsigned) (cp >> 10), lo = 0xDC00 + (unsigned) (cp & 0x3FF);
            buf[k++] = (unsigned char) (hi >> 8);
            buf[k++] = (unsigned char) hi;
            buf[k++] = (unsigned char) (lo >> 8);
            buf[k++] = (unsigned char) lo;
        } else {
            buf[k++] = (unsigned char) (cp >> 8);
            buf[k++] = (unsigned char) cp;
        }
    }
    return sink->set_binary(sink->ctx, buf, k);
}

typedef struct {
    pdfio_dict_t *dict;
    const char *key;
} zpd_dict_slot;

static bool zpd_dict_set_string(void *ctx, const char *s)
{
    zpd_dict_slot *slot = ctx;
    return pdfioDictSetString(slot->dict, slot->key, pdfioStringCreate(slot->dict->pdf, s));
}

static bool zpd_dict_set_binary(void *ctx, const unsigned char *b, size_t n)
{
    zpd_dict_slot *slot = ctx;
    return pdfioDictSetBinary(slot->dict, slot->key, b, n);
}

static bool zpd_array_add_string(void *ctx, const char *s)
{
    pdfio_array_t *a = ctx;
    return pdfioArrayAppendString(a, pdfioStringCreate(a->pdf, s));
}

static bool zpd_array_add_binary(void *ctx, const unsigned char *b, size_t n)
{
    return pdfioArrayAppendBinary(ctx, b, n);
}

/* pdfio has no public "append null" and its append_value() is static: the
   array gets a name, which is then retyped as null, the value pdfio
   writes as the keyword `null`. */
static bool zpd_array_append_null(pdfio_array_t *a)
{
    if (!pdfioArrayAppendName(a, "null"))
        return false;
    a->values[a->num_values - 1].type = PDFIO_VALTYPE_NULL;
    return true;
}

static bool zpd_inherits(SEXP x, const char *cls)
{
    return Rf_inherits(x, cls);
}

/* Converts one R value into `dst`, which is either a dictionary slot or an
   array (exactly one of dict and array is non-NULL). The R side has already
   checked the value's shape (R/values.R); this returns a status name on
   failure: "max_depth", "unsupported" (a type with no PDF form), or "pdfio"
   (pdfio refused). */
static const char *zpd_put(pdfio_file_t *pdf, SEXP x, pdfio_dict_t *dict,
                           const char *key, pdfio_array_t *array, int depth,
                           int max_depth);

static const char *zpd_list_to_pdf(pdfio_file_t *pdf, SEXP x, int depth, int max_depth,
                                   pdfio_dict_t **out_dict, pdfio_array_t **out_array)
{
    SEXP names = Rf_getAttrib(x, R_NamesSymbol);
    R_xlen_t n = Rf_xlength(x);
    if (names != R_NilValue) {
        pdfio_dict_t *d = pdfioDictCreate(pdf);
        if (!d)
            return "pdfio";
        for (R_xlen_t i = 0; i < n; i++) {
            const char *k = pdfioStringCreate(pdf, Rf_translateCharUTF8(STRING_ELT(names, i)));
            const char *st = zpd_put(pdf, VECTOR_ELT(x, i), d, k, NULL, depth + 1, max_depth);
            if (st)
                return st;
        }
        *out_dict = d;
        return NULL;
    }
    pdfio_array_t *a = pdfioArrayCreate(pdf);
    if (!a)
        return "pdfio";
    for (R_xlen_t i = 0; i < n; i++) {
        const char *st = zpd_put(pdf, VECTOR_ELT(x, i), NULL, NULL, a, depth + 1, max_depth);
        if (st)
            return st;
    }
    *out_array = a;
    return NULL;
}

static const char *zpd_put(pdfio_file_t *pdf, SEXP x, pdfio_dict_t *dict,
                           const char *key, pdfio_array_t *array, int depth,
                           int max_depth)
{
    if (depth > max_depth) /* GUARD: max_depth */
        return "max_depth";
    bool ok;
    if (x == R_NilValue) {
        ok = dict ? pdfioDictSetNull(dict, key) : zpd_array_append_null(array);
        return ok ? NULL : "pdfio";
    }
    if (TYPEOF(x) == VECSXP) {
        pdfio_dict_t *d = NULL;
        pdfio_array_t *a = NULL;
        const char *st = zpd_list_to_pdf(pdf, x, depth, max_depth, &d, &a);
        if (st)
            return st;
        if (d)
            ok = dict ? pdfioDictSetDict(dict, key, d) : pdfioArrayAppendDict(array, d);
        else
            ok = dict ? pdfioDictSetArray(dict, key, a) : pdfioArrayAppendArray(array, a);
        return ok ? NULL : "pdfio";
    }
    if (zpd_inherits(x, "pdf_ref")) {
        pdfio_obj_t *obj = pdfioFileFindObj(pdf, (size_t) Rf_asInteger(x));
        if (!obj)
            return "unknown_ref";
        ok = dict ? pdfioDictSetObj(dict, key, obj) : pdfioArrayAppendObj(array, obj);
        return ok ? NULL : "pdfio";
    }
    if (zpd_inherits(x, "POSIXct")) {
        time_t t = (time_t) floor(Rf_asReal(x));
        ok = dict ? pdfioDictSetDate(dict, key, t) : pdfioArrayAppendDate(array, t);
        return ok ? NULL : "pdfio";
    }
    if (TYPEOF(x) == RAWSXP) {
        ok = dict ? pdfioDictSetBinary(dict, key, RAW(x), (size_t) XLENGTH(x))
                  : pdfioArrayAppendBinary(array, RAW(x), (size_t) XLENGTH(x));
        return ok ? NULL : "pdfio";
    }
    if (TYPEOF(x) == LGLSXP) {
        bool b = LOGICAL(x)[0] == TRUE;
        ok = dict ? pdfioDictSetBoolean(dict, key, b) : pdfioArrayAppendBoolean(array, b);
        return ok ? NULL : "pdfio";
    }
    if (TYPEOF(x) == INTSXP || TYPEOF(x) == REALSXP) {
        double d = Rf_asReal(x);
        ok = dict ? pdfioDictSetNumber(dict, key, d) : pdfioArrayAppendNumber(array, d);
        return ok ? NULL : "pdfio";
    }
    if (TYPEOF(x) == STRSXP) {
        const char *s = Rf_translateCharUTF8(STRING_ELT(x, 0));
        if (zpd_inherits(x, "pdf_name")) {
            const char *nm = pdfioStringCreate(pdf, s);
            ok = dict ? pdfioDictSetName(dict, key, nm) : pdfioArrayAppendName(array, nm);
            return ok ? NULL : "pdfio";
        }
        zpd_dict_slot slot = {dict, key};
        zpd_text_sink sink = dict
            ? (zpd_text_sink){zpd_dict_set_string, zpd_dict_set_binary, &slot}
            : (zpd_text_sink){zpd_array_add_string, zpd_array_add_binary, array};
        return zpd_put_text(&sink, s) ? NULL : "pdfio";
    }
    return "unsupported";
}

/* An R list as a new pdfio dictionary (named) or array (unnamed). */
const char *zpd_value_from_r(pdfio_file_t *pdf, SEXP x, int max_depth,
                             pdfio_dict_t **dict, pdfio_array_t **array)
{
    *dict = NULL;
    *array = NULL;
    return zpd_list_to_pdf(pdf, x, 0, max_depth, dict, array);
}
