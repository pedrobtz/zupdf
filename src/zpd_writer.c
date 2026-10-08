/* The writer (design sections 5 and 7): a pdf_writer owns a pdfio file
 * being written into a memory buffer, and the font and image objects made
 * for it.
 *
 * pdfio writes a page's dictionary when the page is created and allows no
 * other object to be created while a content stream is open, so a pdf_page
 * records its drawing operations in R and pdf_page_end() writes the page in
 * one call: it creates the page with the resources the operations use,
 * opens the content stream, replays the operations through pdfio's content
 * API (which encodes text for each font) and closes the stream. No stream
 * is open between calls, and none while R allocates: every string is
 * converted before the stream opens.
 *
 * deterministic = TRUE fixes the two things pdfio takes from the clock and
 * the random source: the creation date (from `created`) and the file
 * identifier, which becomes a hash of the bytes written before the trailer.
 * Encryption keys stay random, so encrypted output is never byte-stable. */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zpd.h"
#include "pdfio-content.h"
#include "pdfio-private.h"

enum { ZPD_IMAGE = 0, ZPD_FONT = 1, ZPD_FONT_UNICODE = 2 };

typedef struct {
    pdfio_file_t *pdf; /* NULL once saved */
    unsigned char *buf;
    size_t n, cap;
    int oom;
    pdfio_obj_t **objs; /* fonts and images, index + 1 is the handle */
    unsigned char *kind; /* per object: ZPD_IMAGE, ZPD_FONT or ZPD_FONT_UNICODE */
    size_t nobjs, capobjs;
    zpd_record rec;
} zpd_writer;

static ssize_t zpd_writer_out(void *ctx, const void *data, size_t len)
{
    zpd_writer *w = ctx;
    if (w->n + len > w->cap) {
        size_t cap = w->cap ? w->cap : 65536;
        while (cap < w->n + len)
            cap *= 2;
        unsigned char *grown = realloc(w->buf, cap);
        if (!grown) {
            w->oom = 1;
            return -1;
        }
        w->buf = grown;
        w->cap = cap;
    }
    memcpy(w->buf + w->n, data, len);
    w->n += len;
    return (ssize_t) len;
}

static void zpd_writer_finalize(SEXP ptr)
{
    zpd_writer *w = R_ExternalPtrAddr(ptr);
    if (!w)
        return;
    if (w->pdf)
        pdfioFileClose(w->pdf);
    free(w->buf);
    free(w->objs);
    free(w->kind);
    free(w);
    R_ClearExternalPtr(ptr);
}

static zpd_writer *zpd_writer_get(SEXP ptr)
{
    if (TYPEOF(ptr) != EXTPTRSXP)
        return NULL;
    zpd_writer *w = R_ExternalPtrAddr(ptr);
    return (w && w->pdf) ? w : NULL;
}

static void zpd_fallback(zpd_record *rec, const char *message)
{
    if (rec->nerror == 0) {
        rec->nerror = 1;
        snprintf(rec->error, sizeof(rec->error), "%s", message);
    }
}

static int zpd_rect_arg(SEXP x, pdfio_rect_t *r)
{
    if (TYPEOF(x) != REALSXP || XLENGTH(x) != 4)
        return 0;
    r->x1 = REAL(x)[0];
    r->y1 = REAL(x)[1];
    r->x2 = REAL(x)[2];
    r->y2 = REAL(x)[3];
    return 1;
}

/* zupdf_writer_new(version, media_box) */
SEXP zupdf_writer_new(SEXP version, SEXP media_box)
{
    zpd_writer *w = calloc(1, sizeof(*w));
    if (!w)
        return zpd_status("memory");
    zpd_record_reset(&w->rec);
    SEXP ptr = PROTECT(R_MakeExternalPtr(w, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(ptr, zpd_writer_finalize, TRUE);
    pdfio_rect_t box;
    zpd_rect_arg(media_box, &box);
    w->pdf = pdfioFileCreateOutput(zpd_writer_out, w, CHAR(STRING_ELT(version, 0)),
                                   &box, &box, zpd_error_cb, &w->rec);
    SEXP out;
    if (!w->pdf) {
        zpd_fallback(&w->rec, "Unable to create the PDF file.");
        out = zpd_result("pdfio", R_NilValue, &w->rec);
    } else {
        out = zpd_result("ok", ptr, &w->rec);
    }
    UNPROTECT(1);
    return out;
}

SEXP zupdf_writer_is_open(SEXP ptr)
{
    return Rf_ScalarLogical(zpd_writer_get(ptr) != NULL);
}

static int zpd_writer_add(zpd_writer *w, pdfio_obj_t *obj, int kind)
{
    if (w->nobjs == w->capobjs) {
        size_t cap = w->capobjs ? w->capobjs * 2 : 16;
        pdfio_obj_t **o = realloc(w->objs, cap * sizeof(*o));
        if (o)
            w->objs = o;
        unsigned char *u = realloc(w->kind, cap);
        if (u)
            w->kind = u;
        if (!o || !u)
            return 0;
        w->capobjs = cap;
    }
    w->objs[w->nobjs] = obj;
    w->kind[w->nobjs] = (unsigned char) kind;
    return (int) ++w->nobjs;
}

/* zupdf_writer_font(ptr, kind, name): kind "base" (a base-14 name) or
   "file" (a TrueType or OpenType path, embedded as a Unicode font). Returns
   the font's handle number. */
SEXP zupdf_writer_font(SEXP ptr, SEXP kind, SEXP name)
{
    zpd_writer *w = zpd_writer_get(ptr);
    if (!w)
        return zpd_status("closed");
    zpd_record_reset(&w->rec);
    int file = strcmp(CHAR(STRING_ELT(kind, 0)), "file") == 0;
    const char *s = file ? R_ExpandFileName(Rf_translateChar(STRING_ELT(name, 0)))
                         : CHAR(STRING_ELT(name, 0));
    pdfio_obj_t *obj = file ? pdfioFileCreateFontObjFromFile(w->pdf, s, true)
                            : pdfioFileCreateFontObjFromBase(w->pdf, s);
    if (!obj) {
        zpd_fallback(&w->rec, "Unable to create the font.");
        return zpd_result("font", R_NilValue, &w->rec);
    }
    int k = zpd_writer_add(w, obj, file ? ZPD_FONT_UNICODE : ZPD_FONT);
    if (!k)
        return zpd_status("memory");
    return zpd_result("ok", Rf_ScalarInteger(k), &w->rec);
}

/* zupdf_writer_image_file(ptr, path, interpolate): a PNG or JPEG file. */
SEXP zupdf_writer_image_file(SEXP ptr, SEXP path, SEXP interpolate)
{
    zpd_writer *w = zpd_writer_get(ptr);
    if (!w)
        return zpd_status("closed");
    zpd_record_reset(&w->rec);
    const char *s = R_ExpandFileName(Rf_translateChar(STRING_ELT(path, 0)));
    pdfio_obj_t *obj = pdfioFileCreateImageObjFromFile(w->pdf, s, Rf_asLogical(interpolate) == TRUE);
    if (!obj) {
        zpd_fallback(&w->rec, "Unable to read the image file.");
        return zpd_result("image", R_NilValue, &w->rec);
    }
    int k = zpd_writer_add(w, obj, ZPD_IMAGE);
    if (!k)
        return zpd_status("memory");
    return zpd_result("ok", Rf_ScalarInteger(k), &w->rec);
}

/* zupdf_writer_image_data(ptr, bytes, width, height, colors, alpha,
   interpolate): 8-bit samples, row by row from the top, `colors` (1 or 3)
   channels plus alpha when `alpha` is TRUE. */
SEXP zupdf_writer_image_data(SEXP ptr, SEXP bytes, SEXP width, SEXP height,
                             SEXP colors, SEXP alpha, SEXP interpolate)
{
    zpd_writer *w = zpd_writer_get(ptr);
    if (!w)
        return zpd_status("closed");
    zpd_record_reset(&w->rec);
    pdfio_obj_t *obj = pdfioFileCreateImageObjFromData(
        w->pdf, RAW(bytes), (size_t) Rf_asInteger(width), (size_t) Rf_asInteger(height),
        (size_t) Rf_asInteger(colors), NULL, Rf_asLogical(alpha) == TRUE,
        Rf_asLogical(interpolate) == TRUE);
    if (!obj) {
        zpd_fallback(&w->rec, "Unable to create the image.");
        return zpd_result("image", R_NilValue, &w->rec);
    }
    int k = zpd_writer_add(w, obj, ZPD_IMAGE);
    if (!k)
        return zpd_status("memory");
    return zpd_result("ok", Rf_ScalarInteger(k), &w->rec);
}

/* ---- pages ----------------------------------------------------------------- */

/* The operations a pdf_page records (R/draw.R), with the numbers each
   takes from `nums` and whether it takes a string from `strs`. */
enum {
    ZPD_OP_SAVE = 1,     /* q */
    ZPD_OP_RESTORE,      /* Q */
    ZPD_OP_FILL_RGB,     /* r g b */
    ZPD_OP_STROKE_RGB,   /* r g b */
    ZPD_OP_LINE_WIDTH,   /* w */
    ZPD_OP_MOVE,         /* x y */
    ZPD_OP_LINE,         /* x y */
    ZPD_OP_CURVE,        /* x1 y1 x2 y2 x3 y3 */
    ZPD_OP_CLOSE,        /* */
    ZPD_OP_RECT,         /* x y w h */
    ZPD_OP_PAINT,        /* mode (0 none, 1 fill, 2 stroke, 3 both) even_odd */
    ZPD_OP_TEXT,         /* font size x y align; a string */
    ZPD_OP_IMAGE,        /* image x y w h */
    ZPD_OP_MAX
};

static const int zpd_op_nums[ZPD_OP_MAX] = {0, 0, 0, 3, 3, 1, 2, 2, 6, 0, 4, 2, 5, 5};

/* Checks the recorded operations against the writer before anything is
   written: every operation known, enough numbers and strings, every font
   and image a handle of this writer (of the right kind). */
static int zpd_ops_valid(zpd_writer *w, SEXP ops, SEXP nums, SEXP strs, unsigned char *used)
{
    R_xlen_t ni = 0, si = 0;
    for (R_xlen_t i = 0; i < XLENGTH(ops); i++) {
        int op = INTEGER(ops)[i];
        if (op < 1 || op >= ZPD_OP_MAX || ni + zpd_op_nums[op] > XLENGTH(nums))
            return 0;
        if (op == ZPD_OP_TEXT || op == ZPD_OP_IMAGE) {
            double k = REAL(nums)[ni];
            if (k < 1 || k > (double) w->nobjs || k != floor(k))
                return 0;
            if ((op == ZPD_OP_TEXT) != (w->kind[(size_t) k - 1] != ZPD_IMAGE))
                return 0;
            used[(size_t) k - 1] = 1;
        }
        if (op == ZPD_OP_TEXT && si++ >= XLENGTH(strs))
            return 0;
        ni += zpd_op_nums[op];
    }
    return 1;
}

static void zpd_res_name(char *buf, size_t n, zpd_writer *w, size_t k)
{
    snprintf(buf, n, "%s%lu", w->kind[k] == ZPD_IMAGE ? "Im" : "F", (unsigned long) (k + 1));
}

static int zpd_replay(zpd_writer *w, pdfio_stream_t *st, SEXP ops, SEXP nums, const char **text)
{
    const double *a = REAL(nums);
    R_xlen_t ni = 0, si = 0;
    char name[32];
    int ok = 1;
    for (R_xlen_t i = 0; i < XLENGTH(ops) && ok; i++) {
        int op = INTEGER(ops)[i];
        const double *v = a + ni;
        ni += zpd_op_nums[op];
        switch (op) {
        case ZPD_OP_SAVE:
            ok = pdfioContentSave(st);
            break;
        case ZPD_OP_RESTORE:
            ok = pdfioContentRestore(st);
            break;
        case ZPD_OP_FILL_RGB:
            ok = pdfioContentSetFillColorDeviceRGB(st, v[0], v[1], v[2]);
            break;
        case ZPD_OP_STROKE_RGB:
            ok = pdfioContentSetStrokeColorDeviceRGB(st, v[0], v[1], v[2]);
            break;
        case ZPD_OP_LINE_WIDTH:
            ok = pdfioContentSetLineWidth(st, v[0]);
            break;
        case ZPD_OP_MOVE:
            ok = pdfioContentPathMoveTo(st, v[0], v[1]);
            break;
        case ZPD_OP_LINE:
            ok = pdfioContentPathLineTo(st, v[0], v[1]);
            break;
        case ZPD_OP_CURVE:
            ok = pdfioContentPathCurve(st, v[0], v[1], v[2], v[3], v[4], v[5]);
            break;
        case ZPD_OP_CLOSE:
            ok = pdfioContentPathClose(st);
            break;
        case ZPD_OP_RECT:
            ok = pdfioContentPathRect(st, v[0], v[1], v[2], v[3]);
            break;
        case ZPD_OP_PAINT: {
            int mode = (int) v[0];
            bool eo = v[1] != 0.0;
            ok = mode == 1 ? pdfioContentFill(st, eo)
               : mode == 2 ? pdfioContentStroke(st)
               : mode == 3 ? pdfioContentFillAndStroke(st, eo)
               : pdfioContentPathEnd(st);
            break;
        }
        case ZPD_OP_TEXT: {
            size_t k = (size_t) v[0] - 1;
            const char *s = text[si++];
            double size = v[1], x = v[2], y = v[3], align = v[4];
            if (align != 0.0)
                x -= align * pdfioContentTextMeasure(w->objs[k], s, size) / 2.0;
            zpd_res_name(name, sizeof(name), w, k);
            ok = pdfioContentTextBegin(st) && pdfioContentSetTextFont(st, name, size) &&
                 pdfioContentTextMoveTo(st, x, y) && pdfioContentTextShow(st, w->kind[k] == ZPD_FONT_UNICODE, s) &&
                 pdfioContentTextEnd(st);
            break;
        }
        case ZPD_OP_IMAGE:
            zpd_res_name(name, sizeof(name), w, (size_t) v[0] - 1);
            ok = pdfioContentDrawImage(st, name, v[1], v[2], v[3], v[4]);
            break;
        default:
            ok = 0;
        }
    }
    return ok;
}

/* zupdf_writer_page(ptr, media_box, crop_box, dict, ops, nums, strs,
   max_depth): writes one page. Boxes are NULL for the writer's default;
   dict is NULL or a named list of further page entries (design section 6). */
SEXP zupdf_writer_page(SEXP ptr, SEXP media_box, SEXP crop_box, SEXP dict_,
                       SEXP ops, SEXP nums, SEXP strs, SEXP max_depth)
{
    zpd_writer *w = zpd_writer_get(ptr);
    if (!w)
        return zpd_status("closed");
    zpd_record_reset(&w->rec);

    /* Everything R must do happens before the stream opens. */
    unsigned char *used = (unsigned char *) R_alloc(w->nobjs + 1, 1);
    memset(used, 0, w->nobjs + 1);
    if (!zpd_ops_valid(w, ops, nums, strs, used))
        return zpd_status("bad_ops");
    const char **text = (const char **) R_alloc((size_t) XLENGTH(strs) + 1, sizeof(char *));
    for (R_xlen_t i = 0; i < XLENGTH(strs); i++)
        text[i] = Rf_translateCharUTF8(STRING_ELT(strs, i));

    pdfio_dict_t *dict = NULL;
    if (dict_ != R_NilValue) {
        pdfio_array_t *unused;
        const char *st = zpd_value_from_r(w->pdf, dict_, Rf_asInteger(max_depth), &dict, &unused);
        if (st)
            return zpd_result(st, R_NilValue, &w->rec);
    }
    if (!dict && !(dict = pdfioDictCreate(w->pdf)))
        return zpd_status("memory");
    pdfio_rect_t r;
    if (zpd_rect_arg(media_box, &r))
        pdfioDictSetRect(dict, "MediaBox", &r);
    if (zpd_rect_arg(crop_box, &r))
        pdfioDictSetRect(dict, "CropBox", &r);
    char name[32];
    for (size_t k = 0; k < w->nobjs; k++) {
        if (!used[k])
            continue;
        zpd_res_name(name, sizeof(name), w, k);
        const char *nm = pdfioStringCreate(w->pdf, name);
        int ok = w->kind[k] == ZPD_IMAGE ? pdfioPageDictAddImage(dict, nm, w->objs[k])
                                         : pdfioPageDictAddFont(dict, nm, w->objs[k]);
        if (!ok)
            return zpd_result("pdfio", R_NilValue, &w->rec);
    }

    pdfio_stream_t *st = pdfioFileCreatePage(w->pdf, dict);
    if (!st) {
        zpd_fallback(&w->rec, "Unable to create the page.");
        return zpd_result("pdfio", R_NilValue, &w->rec);
    }
    int ok = zpd_replay(w, st, ops, nums, text);
    ok = pdfioStreamClose(st) && ok && !w->oom;
    if (!ok) {
        zpd_fallback(&w->rec, w->oom ? "Unable to allocate memory for the output."
                                     : "Unable to write the page.");
        return zpd_result("pdfio", R_NilValue, &w->rec);
    }
    return zpd_result("ok", R_NilValue, &w->rec);
}

/* ---- saving ------------------------------------------------------------------- */

/* zupdf_writer_save(ptr, created, deterministic): closes the file and
   returns its bytes. */
SEXP zupdf_writer_save(SEXP ptr, SEXP created, SEXP deterministic)
{
    zpd_writer *w = zpd_writer_get(ptr);
    if (!w)
        return zpd_status("closed");
    zpd_record_reset(&w->rec);
    pdfioFileSetCreationDate(w->pdf, (time_t) floor(Rf_asReal(created)));
    if (Rf_asLogical(deterministic) == TRUE) {
        /* The identifier: the first 16 bytes of the SHA-256 of everything
           written so far, which every page, font and image is. */
        _pdfio_sha256_t ctx;
        uint8_t digest[32];
        _pdfioCryptoSHA256Init(&ctx);
        _pdfioCryptoSHA256Append(&ctx, w->buf, w->n);
        _pdfioCryptoSHA256Finish(&ctx, digest);
        pdfio_array_t *id = pdfioArrayCreate(w->pdf);
        if (!id || !pdfioArrayAppendBinary(id, digest, 16) || !pdfioArrayAppendBinary(id, digest, 16))
            return zpd_status("memory");
        w->pdf->id_array = id;
    }
    int ok = pdfioFileClose(w->pdf) && !w->oom;
    w->pdf = NULL;
    if (!ok) {
        zpd_fallback(&w->rec, w->oom ? "Unable to allocate memory for the output."
                                     : "Unable to finish the file.");
        return zpd_result("pdfio", R_NilValue, &w->rec);
    }
    SEXP bytes = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) w->n));
    if (w->n)
        memcpy(RAW(bytes), w->buf, w->n);
    free(w->buf);
    w->buf = NULL;
    w->n = w->cap = 0;
    SEXP out = zpd_result("ok", bytes, &w->rec);
    UNPROTECT(1);
    return out;
}
