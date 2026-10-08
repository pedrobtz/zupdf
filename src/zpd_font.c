/* Fonts for the text extractor (design section 8): how a font's codes map
 * to Unicode and how wide its glyphs are.
 *
 * Unicode comes from the font's ToUnicode CMap when it has one, else, for a
 * simple font, from its encoding (a base encoding plus /Differences, whose
 * glyph names go through the glyph list). Widths come from /Widths or /W,
 * else from pdfio's base-14 metrics, else an estimate. Nothing here raises:
 * a font that cannot be read maps nothing and has estimated widths. */

#include <stdlib.h>
#include <string.h>

#include "zpd_text.h"
#include "zpd_lex.h"
#include "zpd_glyphs.h"
#include "pdfio-base-font-widths.h"

/* ---- glyph names ------------------------------------------------------------- */

static int zpd_glyph_cmp(const void *key, const void *elt)
{
    return strcmp((const char *) key, ((const zpd_glyph_t *) elt)->name);
}

static uint32_t zpd_hex_cp(const char *s, size_t n)
{
    uint32_t v = 0;
    for (size_t i = 0; i < n; i++) {
        char c = s[i];
        int d = (c >= '0' && c <= '9') ? c - '0'
              : (c >= 'A' && c <= 'F') ? c - 'A' + 10
              : (c >= 'a' && c <= 'f') ? c - 'a' + 10 : -1;
        if (d < 0)
            return 0;
        v = (v << 4) | (uint32_t) d;
    }
    return v;
}

uint32_t zpd_glyph_unicode(const char *name)
{
    char base[128];
    size_t n = strcspn(name, "._");
    if (n == 0 || n >= sizeof(base))
        return 0;
    memcpy(base, name, n);
    base[n] = '\0';
    const zpd_glyph_t *g = bsearch(base, zpd_glyphs, ZPD_NUM_GLYPHS,
                                   sizeof(zpd_glyph_t), zpd_glyph_cmp);
    if (g)
        return g->unicode;
    if (n >= 7 && strncmp(base, "uni", 3) == 0)
        return zpd_hex_cp(base + 3, 4);
    if (n >= 5 && n <= 7 && base[0] == 'u')
        return zpd_hex_cp(base + 1, n - 1);
    return 0;
}

/* ---- ToUnicode CMaps ---------------------------------------------------------- */

typedef struct {
    zpd_umap *um;
    size_t num, cap;
    uint32_t *cps;
    size_t ncps, capcps;
    int oom;
} zpd_umap_builder;

/* A CMap's entries are bounded so that a hostile map cannot exhaust memory:
   a million ranges and a million destination code points. */
#define ZPD_MAX_UMAP 1000000

static uint32_t zpd_bytes_code(const unsigned char *b, size_t n)
{
    uint32_t v = 0;
    for (size_t i = 0; i < n && i < 4; i++)
        v = (v << 8) | b[i];
    return v;
}

/* UTF-16BE bytes to code points, appended to the builder's pool. */
static int zpd_utf16_cps(zpd_umap_builder *b, const unsigned char *s, size_t n,
                         uint32_t *off, uint16_t *count)
{
    *off = (uint32_t) b->ncps;
    *count = 0;
    for (size_t i = 0; i + 1 < n; i += 2) {
        uint32_t u = ((uint32_t) s[i] << 8) | s[i + 1];
        if (u >= 0xD800 && u <= 0xDBFF && i + 3 < n) {
            uint32_t lo = ((uint32_t) s[i + 2] << 8) | s[i + 3];
            if (lo >= 0xDC00 && lo <= 0xDFFF) {
                u = 0x10000 + ((u - 0xD800) << 10) + (lo - 0xDC00);
                i += 2;
            }
        }
        if (b->ncps >= ZPD_MAX_UMAP) /* GUARD: cmap_size */
            return 0;
        if (b->ncps == b->capcps) {
            size_t cap = b->capcps ? b->capcps * 2 : 256;
            uint32_t *grown = realloc(b->cps, cap * sizeof(uint32_t));
            if (!grown) {
                b->oom = 1;
                return 0;
            }
            b->cps = grown;
            b->capcps = cap;
        }
        b->cps[b->ncps++] = u;
        (*count)++;
    }
    return 1;
}

static int zpd_umap_add(zpd_umap_builder *b, uint32_t lo, uint32_t hi,
                        const unsigned char *dst, size_t dstlen)
{
    if (hi < lo || b->num >= ZPD_MAX_UMAP) /* GUARD: cmap_size */
        return 0;
    if (b->num == b->cap) {
        size_t cap = b->cap ? b->cap * 2 : 64;
        zpd_umap *grown = realloc(b->um, cap * sizeof(zpd_umap));
        if (!grown) {
            b->oom = 1;
            return 0;
        }
        b->um = grown;
        b->cap = cap;
    }
    zpd_umap *e = &b->um[b->num];
    e->lo = lo;
    e->hi = hi;
    if (!zpd_utf16_cps(b, dst, dstlen, &e->off, &e->n) || e->n == 0)
        return 0;
    b->num++;
    return 1;
}

static int zpd_umap_cmp(const void *a, const void *b)
{
    uint32_t x = ((const zpd_umap *) a)->lo, y = ((const zpd_umap *) b)->lo;
    return x < y ? -1 : x > y;
}

/* Parses a ToUnicode CMap's bfchar and bfrange sections (PDF 2.0, 9.10.3)
   and its first code space range, which gives the code length. */
static void zpd_parse_cmap(zpd_font *f, const unsigned char *data, size_t n)
{
    zpd_lex lx;
    zpd_umap_builder b = {0};
    zpd_lex_init(&lx, data, n);
    unsigned char a[4], c[4];
    size_t alen = 0, clen = 0;
    int codelen = 0;

    int identity = 0;
    for (zpd_tok_type t = zpd_lex_next(&lx); t != ZPD_TOK_EOF && t != ZPD_TOK_ERROR && !b.oom;
         t = zpd_lex_next(&lx)) {
        if (t == ZPD_TOK_NAME && strstr((const char *) lx.buf, "Identity-UCS2")) {
            /* pdfio's own fonts map each code to itself this way, with no
               entries; poppler reads the name the same way. */
            identity = 1;
        } else if (zpd_lex_is(&lx, "begincodespacerange")) {
            if (zpd_lex_next(&lx) == ZPD_TOK_HEXSTRING && codelen == 0)
                codelen = (int) lx.len;
        } else if (zpd_lex_is(&lx, "beginbfchar")) {
            for (;;) {
                if (zpd_lex_next(&lx) != ZPD_TOK_HEXSTRING)
                    break;
                alen = lx.len < 4 ? lx.len : 4;
                memcpy(a, lx.buf, alen);
                if (zpd_lex_next(&lx) != ZPD_TOK_HEXSTRING)
                    break;
                uint32_t code = zpd_bytes_code(a, alen);
                zpd_umap_add(&b, code, code, lx.buf, lx.len);
            }
        } else if (zpd_lex_is(&lx, "beginbfrange")) {
            for (;;) {
                if (zpd_lex_next(&lx) != ZPD_TOK_HEXSTRING)
                    break;
                alen = lx.len < 4 ? lx.len : 4;
                memcpy(a, lx.buf, alen);
                if (zpd_lex_next(&lx) != ZPD_TOK_HEXSTRING)
                    break;
                clen = lx.len < 4 ? lx.len : 4;
                memcpy(c, lx.buf, clen);
                uint32_t lo = zpd_bytes_code(a, alen), hi = zpd_bytes_code(c, clen);
                t = zpd_lex_next(&lx);
                if (t == ZPD_TOK_HEXSTRING) {
                    zpd_umap_add(&b, lo, hi, lx.buf, lx.len);
                } else if (t == ZPD_TOK_ARRAY_OPEN) {
                    /* One destination per code: [<dst> <dst> ...] */
                    for (uint32_t code = lo; zpd_lex_next(&lx) == ZPD_TOK_HEXSTRING; code++)
                        if (code <= hi)
                            zpd_umap_add(&b, code, code, lx.buf, lx.len);
                } else {
                    break;
                }
            }
        }
    }
    zpd_lex_free(&lx);
    if (b.num)
        qsort(b.um, b.num, sizeof(zpd_umap), zpd_umap_cmp);
    f->um = b.um;
    f->num = b.num;
    f->cps = b.cps;
    f->ncps = b.ncps;
    f->identity = identity && b.num == 0;
    if (codelen == 1 || codelen == 2)
        f->code_bytes = codelen;
}

static const zpd_umap *zpd_umap_find(const zpd_font *f, uint32_t code)
{
    size_t lo = 0, hi = f->num;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        if (f->um[mid].lo <= code)
            lo = mid + 1;
        else
            hi = mid;
    }
    /* lo is the first entry with lo > code; scan back for one covering it. */
    for (size_t i = lo; i-- > 0;) {
        if (f->um[i].hi >= code)
            return &f->um[i];
        if (lo - i > 8)
            break;
    }
    return NULL;
}

size_t zpd_font_unicode(const zpd_font *f, uint32_t code, uint32_t *out, size_t max)
{
    const zpd_umap *e = f->num ? zpd_umap_find(f, code) : NULL;
    if (e) {
        size_t n = e->n < max ? e->n : max;
        memcpy(out, f->cps + e->off, n * sizeof(uint32_t));
        out[n - 1] += code - e->lo;
        return n;
    }
    if (f->identity && code < 0x10000) {
        out[0] = code;
        return 1;
    }
    if (f->code_bytes == 1 && code < 256 && f->enc[code]) {
        out[0] = f->enc[code];
        return 1;
    }
    return 0;
}

/* ---- widths ---------------------------------------------------------------------- */

static int zpd_wr_cmp(const void *a, const void *b)
{
    uint32_t x = ((const zpd_wrange *) a)->lo, y = ((const zpd_wrange *) b)->lo;
    return x < y ? -1 : x > y;
}

double zpd_font_width(const zpd_font *f, uint32_t code)
{
    if (f->code_bytes == 1)
        return code < 256 ? f->widths[code] : f->default_width;
    size_t lo = 0, hi = f->nwr;
    while (lo < hi) {
        size_t mid = (lo + hi) / 2;
        if (f->wr[mid].lo <= code)
            lo = mid + 1;
        else
            hi = mid;
    }
    if (lo > 0) {
        const zpd_wrange *r = &f->wr[lo - 1];
        if (code <= r->hi)
            return r->k >= 0 ? f->cid_ws[(size_t) r->k + (code - r->lo)] : r->w;
    }
    return f->default_width;
}

/* A CID font's /W: [c [w1 w2 ...]  cfirst clast w  ...] */
static void zpd_cid_widths(zpd_font *f, pdfio_array_t *w)
{
    size_t n = w ? pdfioArrayGetSize(w) : 0;
    zpd_wrange *wr = calloc(n ? n : 1, sizeof(zpd_wrange));
    double *ws = NULL;
    size_t nws = 0, capws = 0, k = 0;
    if (!wr)
        return;
    for (size_t i = 0; i + 1 < n;) {
        if (pdfioArrayGetType(w, i) != PDFIO_VALTYPE_NUMBER)
            break;
        uint32_t c = (uint32_t) pdfioArrayGetNumber(w, i);
        pdfio_array_t *list = pdfioArrayGetType(w, i + 1) == PDFIO_VALTYPE_ARRAY
                                  ? pdfioArrayGetArray(w, i + 1) : NULL;
        if (list) {
            size_t m = pdfioArrayGetSize(list);
            if (m == 0 || m > ZPD_MAX_UMAP || nws + m > ZPD_MAX_UMAP) /* GUARD: cmap_size */
                break;
            if (nws + m > capws) {
                size_t cap = capws ? capws : 256;
                while (cap < nws + m)
                    cap *= 2;
                double *grown = realloc(ws, cap * sizeof(double));
                if (!grown)
                    break;
                ws = grown;
                capws = cap;
            }
            wr[k] = (zpd_wrange){c, c + (uint32_t) m - 1, 0.0, (int32_t) nws};
            for (size_t j = 0; j < m; j++)
                ws[nws++] = pdfioArrayGetNumber(list, j);
            k++;
            i += 2;
        } else if (i + 2 < n) {
            uint32_t last = (uint32_t) pdfioArrayGetNumber(w, i + 1);
            if (last >= c)
                wr[k++] = (zpd_wrange){c, last, pdfioArrayGetNumber(w, i + 2), -1};
            i += 3;
        } else {
            break;
        }
    }
    qsort(wr, k, sizeof(zpd_wrange), zpd_wr_cmp);
    f->wr = wr;
    f->nwr = k;
    f->cid_ws = ws;
    f->ncid_ws = nws;
}

/* pdfio's base-14 metrics, by name without a subset prefix. */
static const short *zpd_base14_widths(const char *name)
{
    static const struct {
        const char *name;
        const short *w;
    } fonts[] = {
        {"Courier", courier_widths},
        {"Courier-Bold", courier_bold_widths},
        {"Courier-BoldOblique", courier_boldoblique_widths},
        {"Courier-Oblique", courier_oblique_widths},
        {"Helvetica", helvetica_widths},
        {"Helvetica-Bold", helvetica_bold_widths},
        {"Helvetica-BoldOblique", helvetica_boldoblique_widths},
        {"Helvetica-Oblique", helvetica_oblique_widths},
        {"Symbol", symbol_widths},
        {"Times-Bold", times_bold_widths},
        {"Times-BoldItalic", times_bolditalic_widths},
        {"Times-Italic", times_italic_widths},
        {"Times-Roman", times_roman_widths},
        {"ZapfDingbats", zapfdingbats_widths},
    };
    if (!name)
        return NULL;
    const char *plus = strchr(name, '+');
    if (plus && plus - name == 6)
        name = plus + 1;
    for (size_t i = 0; i < sizeof(fonts) / sizeof(fonts[0]); i++)
        if (strcmp(name, fonts[i].name) == 0)
            return fonts[i].w;
    return NULL;
}

/* ---- simple-font encodings ------------------------------------------------------- */

static void zpd_set_base_encoding(zpd_font *f, const char *name)
{
    const unsigned short *t = zpd_standard_encoding;
    if (name && strcmp(name, "WinAnsiEncoding") == 0)
        t = zpd_winansi_encoding;
    else if (name && strcmp(name, "MacRomanEncoding") == 0)
        t = zpd_macroman_encoding;
    for (int i = 0; i < 256; i++)
        f->enc[i] = t[i];
}

static void zpd_apply_differences(zpd_font *f, pdfio_array_t *d)
{
    size_t n = d ? pdfioArrayGetSize(d) : 0;
    long code = 0;
    for (size_t i = 0; i < n; i++) {
        pdfio_valtype_t t = pdfioArrayGetType(d, i);
        if (t == PDFIO_VALTYPE_NUMBER) {
            code = (long) pdfioArrayGetNumber(d, i);
        } else if (t == PDFIO_VALTYPE_NAME) {
            if (code >= 0 && code < 256)
                f->enc[code] = zpd_glyph_unicode(pdfioArrayGetName(d, i));
            code++;
        }
    }
}

/* ---- loading ------------------------------------------------------------------------ */

static void zpd_font_free(zpd_font *f)
{
    free(f->wr);
    free(f->cid_ws);
    free(f->um);
    free(f->cps);
    free(f);
}

void zpd_font_cache_free(zpd_font_cache *cache)
{
    zpd_font *f = cache->head;
    while (f) {
        zpd_font *next = f->next;
        zpd_font_free(f);
        f = next;
    }
    cache->head = NULL;
}

static pdfio_obj_t *zpd_dict_obj(pdfio_dict_t *dict, const char *key)
{
    return pdfioDictGetType(dict, key) == PDFIO_VALTYPE_INDIRECT ? pdfioDictGetObj(dict, key) : NULL;
}

static void zpd_load_tounicode(zpd_font *f, pdfio_dict_t *dict, double max_stream)
{
    pdfio_obj_t *obj = zpd_dict_obj(dict, "ToUnicode");
    pdfio_stream_t *st = obj ? pdfioObjOpenStream(obj, true) : NULL;
    if (!st)
        return;
    size_t len = 0;
    int over = 0;
    unsigned char *data = zpd_slurp(st, max_stream, &len, &over);
    pdfioStreamClose(st);
    if (data) {
        zpd_parse_cmap(f, data, len);
        free(data);
    }
}

static void zpd_load_simple(zpd_font *f, pdfio_dict_t *dict, const char *subtype)
{
    const char *base = pdfioDictGetName(dict, "BaseFont");

    /* Encoding: a name, or a dictionary of a base encoding and differences.
       Without one, a Type 1 font's built-in encoding is taken to be
       StandardEncoding. */
    pdfio_valtype_t et = pdfioDictGetType(dict, "Encoding");
    if (et == PDFIO_VALTYPE_NAME) {
        zpd_set_base_encoding(f, pdfioDictGetName(dict, "Encoding"));
    } else {
        pdfio_dict_t *ed = zpd_dict_dict(dict, "Encoding");
        zpd_set_base_encoding(f, ed ? pdfioDictGetName(ed, "BaseEncoding") : NULL);
        if (ed)
            zpd_apply_differences(f, zpd_dict_array(ed, "Differences"));
    }
    (void) subtype;

    /* Widths: /FirstChar and /Widths, else the base-14 metrics. */
    pdfio_dict_t *desc = zpd_dict_dict(dict, "FontDescriptor");
    double missing = desc && pdfioDictGetType(desc, "MissingWidth") == PDFIO_VALTYPE_NUMBER
                         ? pdfioDictGetNumber(desc, "MissingWidth") : 0.0;
    pdfio_array_t *w = zpd_dict_array(dict, "Widths");
    const short *b14 = zpd_base14_widths(base);
    f->default_width = missing > 0 ? missing : 500.0;
    for (int i = 0; i < 256; i++)
        f->widths[i] = b14 ? b14[i] : f->default_width;
    if (w) {
        long first = (long) pdfioDictGetNumber(dict, "FirstChar");
        size_t n = pdfioArrayGetSize(w);
        for (int i = 0; i < 256; i++)
            f->widths[i] = missing;
        for (size_t i = 0; i < n; i++)
            if (first + (long) i >= 0 && first + (long) i < 256)
                f->widths[first + (long) i] = pdfioArrayGetNumber(w, i);
    }
}

static void zpd_load_type0(zpd_font *f, pdfio_dict_t *dict)
{
    f->code_bytes = 2;
    f->default_width = 1000.0;
    pdfio_array_t *desc = zpd_dict_array(dict, "DescendantFonts");
    pdfio_dict_t *cid = NULL;
    if (desc && pdfioArrayGetSize(desc) > 0) {
        if (pdfioArrayGetType(desc, 0) == PDFIO_VALTYPE_DICT) {
            cid = pdfioArrayGetDict(desc, 0);
        } else {
            pdfio_obj_t *o = pdfioArrayGetObj(desc, 0);
            cid = o ? pdfioObjGetDict(o) : NULL;
        }
    }
    if (!cid)
        return;
    if (pdfioDictGetType(cid, "DW") == PDFIO_VALTYPE_NUMBER)
        f->default_width = pdfioDictGetNumber(cid, "DW");
    zpd_cid_widths(f, zpd_dict_array(cid, "W"));
}

zpd_font *zpd_font_get(zpd_font_cache *cache, zpd_font_cache *local,
                       pdfio_obj_t *obj, pdfio_dict_t *dict, double max_stream)
{
    size_t objnum = obj ? pdfioObjGetNumber(obj) : 0;
    if (objnum)
        for (zpd_font *f = cache->head; f; f = f->next)
            if (f->objnum == objnum)
                return f;
    if (obj)
        dict = pdfioObjGetDict(obj);

    zpd_font *f = calloc(1, sizeof(*f));
    if (!f)
        return NULL;
    f->objnum = objnum;
    f->code_bytes = 1;
    f->scale = 0.001;
    f->default_width = 500.0;
    for (int i = 0; i < 256; i++)
        f->widths[i] = 500.0;
    zpd_set_base_encoding(f, NULL);

    if (dict) {
        const char *subtype = pdfioDictGetName(dict, "Subtype");
        if (subtype && strcmp(subtype, "Type0") == 0) {
            zpd_load_type0(f, dict);
        } else {
            zpd_load_simple(f, dict, subtype);
            if (subtype && strcmp(subtype, "Type3") == 0) {
                pdfio_array_t *m = zpd_dict_array(dict, "FontMatrix");
                if (m && pdfioArrayGetSize(m) == 6 && pdfioArrayGetNumber(m, 0) != 0.0)
                    f->scale = pdfioArrayGetNumber(m, 0);
            }
        }
        zpd_load_tounicode(f, dict, max_stream);
    }

    zpd_font_cache *into = objnum ? cache : local;
    f->next = into->head;
    into->head = f;
    return f;
}
