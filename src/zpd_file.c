/* The pdf_file handle (design sections 4, 10, 12 and 13): opening, closing,
 * the error and password callbacks, metadata and the page table.
 *
 * C never raises (D5). Every entry point returns zpd_result(); R maps the
 * status and pdfio's message to a condition class after the call. R
 * allocates only between pdfio calls, and everything pdfio allocates is
 * reachable from the external pointer, so an R error (an allocation
 * failure) cannot leak it: the finalizer closes the file. */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zpd.h"

/* ---- records and results -------------------------------------------------- */

SEXP zpd_result(const char *status, SEXP value, const zpd_record *rec)
{
    const char *names[] = {"status", "value", "detail", "nwarning", "warning", ""};
    PROTECT(value);
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString(status));
    SET_VECTOR_ELT(out, 1, value);
    SET_VECTOR_ELT(out, 2, rec->nerror ? zpd_string_or_na(rec->error)
                                       : Rf_ScalarString(NA_STRING));
    SET_VECTOR_ELT(out, 3, Rf_ScalarInteger(rec->nwarning));
    SET_VECTOR_ELT(out, 4, rec->nwarning ? zpd_string_or_na(rec->warning)
                                         : Rf_ScalarString(NA_STRING));
    UNPROTECT(2);
    return out;
}

/* A status with no pdfio record, such as "closed". */
SEXP zpd_status(const char *status)
{
    zpd_record rec;
    zpd_record_reset(&rec);
    return zpd_result(status, R_NilValue, &rec);
}

/* pdfio stopped without calling the error callback, which it does for a
   few failures (a NULL page, say). Records `message` so R still has a
   detail to report. */
static void zpd_record_fallback(zpd_record *rec, const char *message)
{
    if (rec->nerror == 0) {
        rec->nerror = 1;
        snprintf(rec->error, sizeof(rec->error), "%s", message);
    }
}

/* ---- the handle ------------------------------------------------------------ */

static char *zpd_strdup(const char *s)
{
    size_t n = strlen(s) + 1;
    char *out = malloc(n);
    if (out)
        memcpy(out, s, n);
    return out;
}

/* Closes the file and removes a temporary copy; the struct itself stays
   until the finalizer frees it. Safe to call twice. */
static void zpd_file_release(zpd_file *h)
{
    if (h->pdf) {
        pdfioFileClose(h->pdf);
        h->pdf = NULL;
    }
    if (h->tmpfile) {
        remove(h->tmpfile);
        free(h->tmpfile);
        h->tmpfile = NULL;
    }
    free(h->password);
    h->password = NULL;
    free(h->scratch);
    h->scratch = NULL;
    zpd_text_release(h);
    zpd_fonts_release(h);
}

static void zpd_file_finalize(SEXP ptr)
{
    zpd_file *h = R_ExternalPtrAddr(ptr);
    if (!h)
        return;
    zpd_file_release(h);
    free(h);
    R_ClearExternalPtr(ptr);
}

zpd_file *zpd_file_get(SEXP ptr)
{
    if (TYPEOF(ptr) != EXTPTRSXP)
        return NULL;
    zpd_file *h = R_ExternalPtrAddr(ptr);
    return (h && h->pdf) ? h : NULL;
}

/* pdfio asks again after a wrong password; answering with the same one
   again would only repeat the failure, so the second ask gets NULL and
   pdfio reports "Unable to unlock PDF file." */
static const char *zpd_password_cb(void *data, const char *filename)
{
    zpd_file *h = data;
    (void) filename;
    return h->password_asked++ == 0 ? h->password : NULL;
}

/* zupdf_open(path, password, owned): `path` is a file R has already
   checked against max_size; `owned` says it is a temporary copy the handle
   removes when it closes. */
SEXP zupdf_open(SEXP path, SEXP password, SEXP owned)
{
    zpd_file *h = calloc(1, sizeof(*h));
    if (!h) {
        zpd_record rec;
        zpd_record_reset(&rec);
        zpd_record_fallback(&rec, "Unable to allocate memory for the file handle.");
        return zpd_result("pdfio", R_NilValue, &rec);
    }
    zpd_record_reset(&h->rec);
    SEXP ptr = PROTECT(R_MakeExternalPtr(h, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(ptr, zpd_file_finalize, TRUE);

    const char *filename = R_ExpandFileName(Rf_translateChar(STRING_ELT(path, 0)));
    if (Rf_asLogical(owned) == TRUE)
        h->tmpfile = zpd_strdup(filename);
    if (password != R_NilValue)
        h->password = zpd_strdup(Rf_translateCharUTF8(STRING_ELT(password, 0)));

    h->pdf = pdfioFileOpen(filename, zpd_password_cb, h, zpd_error_cb, &h->rec);
    SEXP out;
    if (!h->pdf) {
        /* The temporary copy stays: R may retry with a password from a
           function, and removes the copy itself when it gives up. */
        zpd_record_fallback(&h->rec, "Unable to open the PDF file.");
        free(h->tmpfile);
        h->tmpfile = NULL;
        zpd_file_release(h);
        out = zpd_result("pdfio", R_NilValue, &h->rec);
    } else {
        out = zpd_result("ok", ptr, &h->rec);
    }
    UNPROTECT(1);
    return out;
}

SEXP zupdf_close(SEXP ptr)
{
    if (TYPEOF(ptr) == EXTPTRSXP) {
        zpd_file *h = R_ExternalPtrAddr(ptr);
        if (h)
            zpd_file_release(h);
    }
    return R_NilValue;
}

SEXP zupdf_is_open(SEXP ptr)
{
    return Rf_ScalarLogical(zpd_file_get(ptr) != NULL);
}

/* The object and page counts, for the max_objects and max_pages limits,
   which R checks right after opening (design section 12). */
SEXP zupdf_counts(SEXP ptr)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    SEXP v = PROTECT(Rf_allocVector(REALSXP, 2));
    REAL(v)[0] = (double) pdfioFileGetNumObjs(h->pdf);
    REAL(v)[1] = (double) pdfioFileGetNumPages(h->pdf);
    zpd_record_reset(&h->rec);
    SEXP out = zpd_result("ok", v, &h->rec);
    UNPROTECT(1);
    return out;
}

/* ---- metadata -------------------------------------------------------------- */

static SEXP zpd_time(time_t t)
{
    return Rf_ScalarReal(t == 0 ? NA_REAL : (double) t);
}

/* The file identifier: the trailer's /ID array of two byte strings, as
   lower-case hexadecimal. */
static SEXP zpd_file_id(pdfio_file_t *pdf)
{
    static const char hex[] = "0123456789abcdef";
    pdfio_array_t *id = pdfioFileGetID(pdf);
    size_t n = id ? pdfioArrayGetSize(id) : 0;
    SEXP out = PROTECT(Rf_allocVector(STRSXP, (R_xlen_t) n));
    for (size_t i = 0; i < n; i++) {
        size_t len = 0;
        unsigned char *b = pdfioArrayGetBinary(id, i, &len);
        if (!b) {
            SET_STRING_ELT(out, (R_xlen_t) i, NA_STRING);
            continue;
        }
        char *buf = R_alloc(2 * len + 1, 1);
        for (size_t k = 0; k < len; k++) {
            buf[2 * k] = hex[b[k] >> 4];
            buf[2 * k + 1] = hex[b[k] & 15];
        }
        buf[2 * len] = '\0';
        SET_STRING_ELT(out, (R_xlen_t) i, Rf_mkChar(buf));
    }
    UNPROTECT(1);
    return out;
}

SEXP zupdf_meta(SEXP ptr)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    pdfio_file_t *pdf = h->pdf;

    const char *names[] = {"version",  "pages",    "title",       "author",
                           "subject",  "keywords", "creator",     "producer",
                           "language", "created",  "modified",    "id",
                           "encryption", "permissions", ""};
    SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(v, 0, zpd_string_or_na(pdfioFileGetVersion(pdf)));
    SET_VECTOR_ELT(v, 1, Rf_ScalarReal((double) pdfioFileGetNumPages(pdf)));
    SET_VECTOR_ELT(v, 2, zpd_string_or_na(pdfioFileGetTitle(pdf)));
    SET_VECTOR_ELT(v, 3, zpd_string_or_na(pdfioFileGetAuthor(pdf)));
    SET_VECTOR_ELT(v, 4, zpd_string_or_na(pdfioFileGetSubject(pdf)));
    SET_VECTOR_ELT(v, 5, zpd_string_or_na(pdfioFileGetKeywords(pdf)));
    SET_VECTOR_ELT(v, 6, zpd_string_or_na(pdfioFileGetCreator(pdf)));
    SET_VECTOR_ELT(v, 7, zpd_string_or_na(pdfioFileGetProducer(pdf)));
    SET_VECTOR_ELT(v, 8, zpd_string_or_na(pdfioFileGetLanguage(pdf)));
    SET_VECTOR_ELT(v, 9, zpd_time(pdfioFileGetCreationDate(pdf)));
    SET_VECTOR_ELT(v, 10, zpd_time(pdfioFileGetModificationDate(pdf)));
    SET_VECTOR_ELT(v, 11, zpd_file_id(pdf));
    pdfio_encryption_t enc = PDFIO_ENCRYPTION_NONE;
    pdfio_permission_t perm = pdfioFileGetPermissions(pdf, &enc);
    SET_VECTOR_ELT(v, 12, Rf_ScalarInteger((int) enc));
    SET_VECTOR_ELT(v, 13, Rf_ScalarInteger((int) perm));

    SEXP out = zpd_result(h->rec.nerror ? "pdfio" : "ok", v, &h->rec);
    UNPROTECT(1);
    return out;
}

/* ---- the page table -------------------------------------------------------- */

/* A rectangle as four numbers, normalised so x1 <= x2 and y1 <= y2.
   False when the array is not four numbers. */
static bool zpd_rect(pdfio_array_t *a, double r[4])
{
    if (!a || pdfioArrayGetSize(a) != 4)
        return false;
    for (size_t i = 0; i < 4; i++) {
        if (pdfioArrayGetType(a, i) != PDFIO_VALTYPE_NUMBER)
            return false;
        r[i] = pdfioArrayGetNumber(a, i);
    }
    if (r[0] > r[2]) {
        double t = r[0];
        r[0] = r[2];
        r[2] = t;
    }
    if (r[1] > r[3]) {
        double t = r[1];
        r[1] = r[3];
        r[3] = t;
    }
    return true;
}

/* zupdf_pages(ptr, max_depth): list(media, crop, rotate, streams), media
   and crop as 4 x n matrices (NA where absent or malformed). The crop box
   defaults to the media box and is clipped to it (PDF 2.0, 14.11.2). */
SEXP zupdf_pages(SEXP ptr, SEXP max_depth_)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    int max_depth = Rf_asInteger(max_depth_);
    size_t n = pdfioFileGetNumPages(h->pdf);

    /* Everything R allocates is allocated before the walk. */
    const char *names[] = {"media", "crop", "rotate", "streams", ""};
    SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP media = Rf_allocMatrix(REALSXP, 4, (int) n);
    SET_VECTOR_ELT(v, 0, media);
    SEXP crop = Rf_allocMatrix(REALSXP, 4, (int) n);
    SET_VECTOR_ELT(v, 1, crop);
    SEXP rotate = Rf_allocVector(INTSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 2, rotate);
    SEXP streams = Rf_allocVector(INTSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 3, streams);

    const char *status = "ok";
    for (size_t i = 0; i < n; i++) {
        double *m = REAL(media) + 4 * i, *c = REAL(crop) + 4 * i;
        pdfio_obj_t *page = pdfioFileGetPage(h->pdf, i);
        pdfio_dict_t *dict = page ? pdfioObjGetDict(page) : NULL;
        if (!dict) {
            zpd_record_fallback(&h->rec, "Unable to read a page dictionary.");
            status = "pdfio";
            break;
        }
        int deep = 0;
        pdfio_dict_t *src;

        src = zpd_inherited(dict, "MediaBox", max_depth, &deep);
        if (!(src && zpd_rect(zpd_dict_array(src, "MediaBox"), m)))
            m[0] = m[1] = m[2] = m[3] = NA_REAL;

        src = zpd_inherited(dict, "CropBox", max_depth, &deep);
        if (src && zpd_rect(zpd_dict_array(src, "CropBox"), c)) {
            if (!ISNA(m[0])) {
                c[0] = fmax(c[0], m[0]);
                c[1] = fmax(c[1], m[1]);
                c[2] = fmin(c[2], m[2]);
                c[3] = fmin(c[3], m[3]);
            }
        } else {
            memcpy(c, m, 4 * sizeof(double));
        }

        src = zpd_inherited(dict, "Rotate", max_depth, &deep);
        double r = src ? pdfioDictGetNumber(src, "Rotate") : 0.0;
        int q = zpd_clamp_int(floor(r / 90.0 + 0.5), -1000000, 1000000) % 4;
        INTEGER(rotate)[i] = ((q + 4) % 4) * 90;

        INTEGER(streams)[i] = (int) pdfioPageGetNumStreams(page);

        if (deep) {
            status = "max_depth";
            break;
        }
    }

    SEXP out = zpd_result(status, v, &h->rec);
    UNPROTECT(1);
    return out;
}

/* zupdf_page_xobjects(ptr, page, max_depth): list(name, number), the
   page's /XObject resources that are objects, for pdf_page_images(). */
SEXP zupdf_page_xobjects(SEXP ptr, SEXP page_, SEXP max_depth)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    pdfio_obj_t *page = pdfioFileGetPage(h->pdf, (size_t) Rf_asInteger(page_) - 1);
    pdfio_dict_t *dict = page ? pdfioObjGetDict(page) : NULL;
    int deep = 0;
    pdfio_dict_t *src = dict ? zpd_inherited(dict, "Resources", Rf_asInteger(max_depth), &deep) : NULL;
    pdfio_dict_t *res = src ? zpd_dict_dict(src, "Resources") : NULL;
    pdfio_dict_t *xo = res ? zpd_dict_dict(res, "XObject") : NULL;
    size_t n = xo ? pdfioDictGetNumPairs(xo) : 0, k = 0;

    const char *names[] = {"name", "number", ""};
    SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP nm = Rf_allocVector(STRSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 0, nm);
    SEXP num = Rf_allocVector(REALSXP, (R_xlen_t) n);
    SET_VECTOR_ELT(v, 1, num);
    for (size_t i = 0; i < n; i++) {
        const char *key = pdfioDictGetKey(xo, i);
        if (!key || pdfioDictGetType(xo, key) != PDFIO_VALTYPE_INDIRECT)
            continue;
        pdfio_obj_t *obj = pdfioDictGetObj(xo, key);
        if (!obj)
            continue;
        SET_STRING_ELT(nm, (R_xlen_t) k, zpd_mkchar_pdf(key, strlen(key)));
        REAL(num)[k] = (double) pdfioObjGetNumber(obj);
        k++;
    }
    SET_VECTOR_ELT(v, 0, Rf_xlengthgets(nm, (R_xlen_t) k));
    SET_VECTOR_ELT(v, 1, Rf_xlengthgets(num, (R_xlen_t) k));
    SEXP out = zpd_result(deep ? "max_depth" : "ok", v, &h->rec);
    UNPROTECT(1);
    return out;
}

/* zupdf_native_raster(bytes, width, height, channels): 8-bit gray (1) or
   RGB (3) samples as a nativeRaster, which packs each pixel as
   0xAABBGGRR in an int (grDevices). */
SEXP zupdf_native_raster(SEXP bytes, SEXP width_, SEXP height_, SEXP channels_)
{
    int w = Rf_asInteger(width_), hgt = Rf_asInteger(height_), ch = Rf_asInteger(channels_);
    R_xlen_t n = (R_xlen_t) w * hgt;
    if (w <= 0 || hgt <= 0 || (ch != 1 && ch != 3) || XLENGTH(bytes) < n * ch)
        return R_NilValue;
    SEXP out = PROTECT(Rf_allocVector(INTSXP, n));
    const unsigned char *p = RAW(bytes);
    int *o = INTEGER(out);
    for (R_xlen_t i = 0; i < n; i++) {
        unsigned r, g, b;
        if (ch == 1) {
            r = g = b = p[i];
        } else {
            r = p[3 * i];
            g = p[3 * i + 1];
            b = p[3 * i + 2];
        }
        o[i] = (int) (0xFF000000u | (b << 16) | (g << 8) | r);
    }
    SEXP dim = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(dim)[0] = hgt;
    INTEGER(dim)[1] = w;
    Rf_setAttrib(out, R_DimSymbol, dim);
    SEXP cls = PROTECT(Rf_mkString("nativeRaster"));
    Rf_setAttrib(out, R_ClassSymbol, cls);
    SEXP nch = PROTECT(Rf_ScalarInteger(4));
    Rf_setAttrib(out, Rf_install("channels"), nch);
    UNPROTECT(4);
    return out;
}
