/* Text extraction (design section 8, D10): project code in the spirit of
 * pdfio's examples/pdf2text.c, extended with what real files need.
 *
 * Each page's content streams are read whole (bounded by max_stream) and
 * closed before the walk, so no pdfio stream is open while it runs; the
 * walk tokenizes them with zpd_lex. It tracks the graphics and text state
 * (CTM, text and line matrices, font, size, spacing, scaling, leading,
 * rise, q/Q), maps each code through the font (zpd_font.c), positions each
 * glyph, and descends into Form XObjects under max_depth with cycle
 * refusal. The "raw" layout is the text in stream order with line breaks
 * at line-moving operators; "reading" groups the glyphs into lines by
 * baseline, top to bottom, left to right.
 *
 * Everything the walk allocates hangs off one context the handle owns
 * (h->text), freed at the end of the call, at the start of the next, or by
 * the finalizer. Interrupts are polled between pages, when nothing but
 * that context is in flight. */

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zpd_text.h"
#include "zpd_lex.h"

#define ZPD_MAX_OPS 64      /* operands kept per operator */
#define ZPD_MAX_GSTACK 64   /* q nesting */
#define ZPD_MAX_XOBJ 256    /* Form XObject nesting, whatever max_depth says */

/* ---- growable buffers -------------------------------------------------------- */

typedef struct {
    unsigned char *p;
    size_t n, cap;
} zpd_buf;

static int zpd_buf_reserve(zpd_buf *b, size_t extra)
{
    if (b->n + extra <= b->cap)
        return 1;
    size_t cap = b->cap ? b->cap : 1024;
    while (cap < b->n + extra)
        cap *= 2;
    unsigned char *grown = realloc(b->p, cap);
    if (!grown)
        return 0;
    b->p = grown;
    b->cap = cap;
    return 1;
}

static int zpd_buf_add(zpd_buf *b, const void *data, size_t n)
{
    if (!zpd_buf_reserve(b, n))
        return 0;
    if (n)
        memcpy(b->p + b->n, data, n);
    b->n += n;
    return 1;
}

static int zpd_buf_utf8(zpd_buf *b, uint32_t cp)
{
    unsigned char s[4];
    size_t n;
    if (cp < 0x80) {
        s[0] = (unsigned char) cp;
        n = 1;
    } else if (cp < 0x800) {
        s[0] = (unsigned char) (0xC0 | (cp >> 6));
        s[1] = (unsigned char) (0x80 | (cp & 0x3F));
        n = 2;
    } else if (cp < 0x10000) {
        if (cp >= 0xD800 && cp <= 0xDFFF)
            cp = 0xFFFD;
        s[0] = (unsigned char) (0xE0 | (cp >> 12));
        s[1] = (unsigned char) (0x80 | ((cp >> 6) & 0x3F));
        s[2] = (unsigned char) (0x80 | (cp & 0x3F));
        n = 3;
    } else if (cp < 0x110000) {
        s[0] = (unsigned char) (0xF0 | (cp >> 18));
        s[1] = (unsigned char) (0x80 | ((cp >> 12) & 0x3F));
        s[2] = (unsigned char) (0x80 | ((cp >> 6) & 0x3F));
        s[3] = (unsigned char) (0x80 | (cp & 0x3F));
        n = 4;
    } else {
        return zpd_buf_utf8(b, 0xFFFD);
    }
    return zpd_buf_add(b, s, n);
}

unsigned char *zpd_slurp(pdfio_stream_t *st, double max_stream, size_t *len, int *over)
{
    zpd_buf b = {0};
    *over = 0;
    *len = 0;
    for (;;) {
        if (!zpd_buf_reserve(&b, 65536)) {
            free(b.p);
            return NULL;
        }
        ssize_t got = pdfioStreamRead(st, b.p + b.n, b.cap - b.n);
        if (got < 0) {
            free(b.p);
            return NULL;
        }
        if (got == 0)
            break;
        b.n += (size_t) got;
        if ((double) b.n > max_stream) { /* GUARD: max_stream_content */
            free(b.p);
            *over = 1;
            return NULL;
        }
    }
    *len = b.n;
    if (!b.p)
        b.p = malloc(1);
    return b.p;
}

/* ---- matrices -------------------------------------------------------------- */

typedef struct {
    double a, b, c, d, e, f;
} zpd_mat;

static const zpd_mat zpd_identity = {1, 0, 0, 1, 0, 0};

/* m x n, in PDF's row-vector convention: a point goes through m, then n. */
static zpd_mat zpd_mul(zpd_mat m, zpd_mat n)
{
    zpd_mat r;
    r.a = m.a * n.a + m.b * n.c;
    r.b = m.a * n.b + m.b * n.d;
    r.c = m.c * n.a + m.d * n.c;
    r.d = m.c * n.b + m.d * n.d;
    r.e = m.e * n.a + m.f * n.c + n.e;
    r.f = m.e * n.b + m.f * n.d + n.f;
    return r;
}

/* ---- the walk's state ---------------------------------------------------------- */

typedef struct {
    double x0, y0, x1, y1, size;
    size_t off, len; /* the glyph's text in the context's pool */
} zpd_glyph;

typedef struct {
    zpd_mat ctm;
    zpd_font *font;
    double tfs, tc, tw, th, tl, ts;
} zpd_gstate;

typedef struct {
    zpd_tok_type t;
    double num;
    size_t off, len;     /* a string or name, in the operand pool */
    size_t astart, alen; /* an array, in the array list */
} zpd_operand;

typedef struct zpd_text_ctx {
    pdfio_file_t *pdf;
    zpd_font_cache *fonts; /* the handle's cache */
    zpd_font_cache local;  /* fonts from direct dictionaries */
    zpd_font *fallback;
    int max_depth;
    double max_stream;
    const char *status; /* NULL, or "max_depth", "max_stream", "memory" */
    int unmapped;

    zpd_buf content;  /* the page's content streams */
    zpd_glyph *g;
    size_t ng, capg;
    zpd_buf pool;     /* glyph text, UTF-8 */
    zpd_buf raw;      /* the raw layout */
    int raw_text;     /* text since the last raw line break */
    zpd_buf out;      /* the reading layout */

    zpd_operand ops[ZPD_MAX_OPS];
    int nops;
    zpd_buf opstr;    /* operand strings and names */
    zpd_operand *arr; /* array elements */
    size_t narr, caparr;

    size_t xobj[ZPD_MAX_XOBJ];
    int nxobj;

    /* tokens, for pdf_page_tokens() */
    int *tok_type;
    size_t *tok_off, *tok_len;
    size_t ntok, captok;
    zpd_buf tok_pool;
} zpd_text_ctx;

static void zpd_text_ctx_free(zpd_text_ctx *c)
{
    if (!c)
        return;
    zpd_font_cache_free(&c->local);
    free(c->content.p);
    free(c->g);
    free(c->pool.p);
    free(c->raw.p);
    free(c->out.p);
    free(c->opstr.p);
    free(c->arr);
    free(c->tok_type);
    free(c->tok_off);
    free(c->tok_len);
    free(c->tok_pool.p);
    free(c);
}

void zpd_text_release(zpd_file *h)
{
    zpd_text_ctx_free(h->text);
    h->text = NULL;
}

void zpd_fonts_release(zpd_file *h)
{
    if (h->fonts) {
        zpd_font_cache_free(h->fonts);
        free(h->fonts);
        h->fonts = NULL;
    }
}

zpd_text_ctx *zpd_text_ctx_new(zpd_file *h, int max_depth, double max_stream)
{
    zpd_text_release(h);
    if (!h->fonts && !(h->fonts = calloc(1, sizeof(zpd_font_cache))))
        return NULL;
    zpd_text_ctx *c = calloc(1, sizeof(*c));
    if (!c)
        return NULL;
    c->pdf = h->pdf;
    c->fonts = h->fonts;
    c->max_depth = max_depth;
    c->max_stream = max_stream;
    h->text = c;
    return c;
}

static void zpd_fail(zpd_text_ctx *c, const char *status)
{
    if (!c->status)
        c->status = status;
}

/* ---- reading the content streams ------------------------------------------------ */

/* Appends a decoded stream to `into`, with a space between streams, which
   PDF treats as one sequence of tokens (PDF 2.0, 7.8.2). */
static int zpd_read_obj_stream(zpd_text_ctx *c, pdfio_stream_t *st, zpd_buf *into)
{
    if (!st)
        return 0;
    size_t len = 0;
    int over = 0;
    unsigned char *data = zpd_slurp(st, c->max_stream, &len, &over);
    pdfioStreamClose(st);
    if (!data) {
        if (over)
            zpd_fail(c, "max_stream");
        return 0;
    }
    int ok = zpd_buf_add(into, data, len) && zpd_buf_add(into, " ", 1);
    free(data);
    if (!ok)
        zpd_fail(c, "memory");
    return ok;
}

static void zpd_read_page(zpd_text_ctx *c, pdfio_obj_t *page)
{
    c->content.n = 0;
    size_t n = pdfioPageGetNumStreams(page);
    for (size_t i = 0; i < n && !c->status; i++)
        zpd_read_obj_stream(c, pdfioPageOpenStream(page, i, true), &c->content);
}

/* ---- output -------------------------------------------------------------------------- */

static void zpd_raw_break(zpd_text_ctx *c, int newline)
{
    if (!c->raw_text)
        return;
    if (newline) {
        zpd_buf_add(&c->raw, "\n", 1);
        c->raw_text = 0;
    } else if (c->raw.n && c->raw.p[c->raw.n - 1] != ' ') {
        zpd_buf_add(&c->raw, " ", 1);
    }
}

static void zpd_emit(zpd_text_ctx *c, const uint32_t *cps, size_t n,
                     double x0, double y0, double x1, double y1, double size)
{
    if (c->ng == c->capg) {
        size_t cap = c->capg ? c->capg * 2 : 1024;
        zpd_glyph *grown = realloc(c->g, cap * sizeof(zpd_glyph));
        if (!grown) {
            zpd_fail(c, "memory");
            return;
        }
        c->g = grown;
        c->capg = cap;
    }
    size_t off = c->pool.n;
    for (size_t i = 0; i < n; i++) {
        uint32_t cp = cps[i];
        if (cp < 0x20 || cp == 0x7F)
            cp = ' '; /* control codes, as some fonts map spaces */
        zpd_buf_utf8(&c->pool, cp);
        zpd_buf_utf8(&c->raw, cp);
    }
    c->raw_text = 1;
    c->g[c->ng++] = (zpd_glyph){x0, y0, x1, y1, size, off, c->pool.n - off};
}

/* ---- the walk -------------------------------------------------------------------------- */

typedef struct {
    zpd_gstate gs;
    zpd_gstate stack[ZPD_MAX_GSTACK];
    int nstack;
    zpd_mat tm, tlm;
    pdfio_dict_t *resources;
} zpd_run;

static void zpd_walk(zpd_text_ctx *c, const unsigned char *data, size_t n, zpd_run *r, int depth);

static double zpd_num(zpd_text_ctx *c, int i)
{
    /* The i-th operand counting from the operator (0 = last). */
    int k = c->nops - 1 - i;
    return (k >= 0 && c->ops[k].t == ZPD_TOK_NUMBER) ? c->ops[k].num : 0.0;
}

static const zpd_operand *zpd_op(zpd_text_ctx *c, int i)
{
    int k = c->nops - 1 - i;
    return k >= 0 ? &c->ops[k] : NULL;
}

static void zpd_show(zpd_text_ctx *c, zpd_run *r, const unsigned char *s, size_t n)
{
    zpd_gstate *gs = &r->gs;
    zpd_font *f = gs->font;
    if (!f) {
        if (!c->fallback)
            c->fallback = zpd_font_get(c->fonts, &c->local, NULL, NULL, c->max_stream);
        f = c->fallback;
        if (!f) {
            zpd_fail(c, "memory");
            return;
        }
    }
    for (size_t i = 0; i < n && !c->status;) {
        uint32_t code;
        if (f->code_bytes == 2 && i + 1 < n) {
            code = ((uint32_t) s[i] << 8) | s[i + 1];
            i += 2;
        } else {
            code = s[i];
            i += 1;
        }
        uint32_t cps[8];
        size_t ncp = zpd_font_unicode(f, code, cps, 8);
        if (f->identity && code >= 0xD800 && code <= 0xDBFF && i + 1 < n) {
            /* UTF-16 codes: a surrogate pair is one character, one glyph. */
            uint32_t lo = ((uint32_t) s[i] << 8) | s[i + 1];
            if (lo >= 0xDC00 && lo <= 0xDFFF) {
                cps[0] = 0x10000 + ((code - 0xD800) << 10) + (lo - 0xDC00);
                ncp = 1;
                i += 2;
            }
        }
        if (ncp == 0) {
            cps[0] = 0xFFFD;
            ncp = 1;
            c->unmapped++;
        }
        double w0 = zpd_font_width(f, code) * f->scale;
        double tx = (w0 * gs->tfs + gs->tc + ((f->code_bytes == 1 && code == 32) ? gs->tw : 0.0)) * gs->th;
        zpd_mat trm = zpd_mul(r->tm, gs->ctm);
        double x0 = trm.c * gs->ts + trm.e, y0 = trm.d * gs->ts + trm.f;
        double x1 = trm.a * tx + trm.c * gs->ts + trm.e, y1 = trm.b * tx + trm.d * gs->ts + trm.f;
        double size = fabs(gs->tfs) * hypot(trm.c, trm.d);
        zpd_emit(c, cps, ncp, x0, y0, x1, y1, size);
        r->tm.e += tx * r->tm.a;
        r->tm.f += tx * r->tm.b;
    }
}

static void zpd_next_line(zpd_run *r, double tx, double ty)
{
    zpd_mat t = {1, 0, 0, 1, tx, ty};
    r->tlm = zpd_mul(t, r->tlm);
    r->tm = r->tlm;
}

static void zpd_set_font(zpd_text_ctx *c, zpd_run *r)
{
    const zpd_operand *name = zpd_op(c, 1);
    r->gs.tfs = zpd_num(c, 0);
    r->gs.font = NULL;
    if (!name || name->t != ZPD_TOK_NAME || !r->resources)
        return;
    pdfio_dict_t *fonts = zpd_dict_dict(r->resources, "Font");
    const char *key = (const char *) c->opstr.p + name->off;
    if (!fonts)
        return;
    pdfio_valtype_t t = pdfioDictGetType(fonts, key);
    if (t == PDFIO_VALTYPE_INDIRECT)
        r->gs.font = zpd_font_get(c->fonts, &c->local, pdfioDictGetObj(fonts, key), NULL, c->max_stream);
    else if (t == PDFIO_VALTYPE_DICT)
        r->gs.font = zpd_font_get(c->fonts, &c->local, NULL, pdfioDictGetDict(fonts, key), c->max_stream);
}

static void zpd_do(zpd_text_ctx *c, zpd_run *r, int depth)
{
    const zpd_operand *name = zpd_op(c, 0);
    if (!name || name->t != ZPD_TOK_NAME || !r->resources)
        return;
    pdfio_dict_t *xobjects = zpd_dict_dict(r->resources, "XObject");
    const char *key = (const char *) c->opstr.p + name->off;
    pdfio_obj_t *obj = xobjects && pdfioDictGetType(xobjects, key) == PDFIO_VALTYPE_INDIRECT
                           ? pdfioDictGetObj(xobjects, key) : NULL;
    pdfio_dict_t *dict = obj ? pdfioObjGetDict(obj) : NULL;
    const char *subtype = dict ? pdfioDictGetName(dict, "Subtype") : NULL;
    if (!subtype || strcmp(subtype, "Form") != 0)
        return;

    /* A form drawn inside itself, directly or not, is a cycle: refused
       as the depth limit, like nesting past max_depth. */
    size_t num = pdfioObjGetNumber(obj);
    for (int i = 0; i < c->nxobj; i++)
        if (c->xobj[i] == num) { /* GUARD: form_cycle */
            zpd_fail(c, "form_cycle");
            return;
        }
    if (depth + 1 > c->max_depth || c->nxobj >= ZPD_MAX_XOBJ) { /* GUARD: max_depth_form */
        zpd_fail(c, "max_depth");
        return;
    }

    zpd_buf form = {0};
    if (!zpd_read_obj_stream(c, pdfioObjOpenStream(obj, true), &form)) {
        free(form.p);
        return;
    }
    zpd_run sub = {0};
    sub.gs = r->gs;
    pdfio_array_t *m = zpd_dict_array(dict, "Matrix");
    if (m && pdfioArrayGetSize(m) == 6) {
        zpd_mat fm = {pdfioArrayGetNumber(m, 0), pdfioArrayGetNumber(m, 1),
                      pdfioArrayGetNumber(m, 2), pdfioArrayGetNumber(m, 3),
                      pdfioArrayGetNumber(m, 4), pdfioArrayGetNumber(m, 5)};
        sub.gs.ctm = zpd_mul(fm, r->gs.ctm);
    }
    sub.tm = sub.tlm = zpd_identity;
    pdfio_dict_t *res = zpd_dict_dict(dict, "Resources");
    sub.resources = res ? res : r->resources;

    c->xobj[c->nxobj++] = num;
    /* The walk below reuses the operand stack; this operator is done. */
    c->nops = 0;
    c->opstr.n = 0;
    c->narr = 0;
    zpd_walk(c, form.p, form.n, &sub, depth + 1);
    c->nxobj--;
    free(form.p);
}

static void zpd_tj_array(zpd_text_ctx *c, zpd_run *r, const zpd_operand *a)
{
    for (size_t i = 0; i < a->alen && !c->status; i++) {
        const zpd_operand *e = &c->arr[a->astart + i];
        if (e->t == ZPD_TOK_STRING || e->t == ZPD_TOK_HEXSTRING) {
            zpd_show(c, r, c->opstr.p + e->off, e->len);
        } else if (e->t == ZPD_TOK_NUMBER) {
            double tx = -e->num / 1000.0 * r->gs.tfs * r->gs.th;
            r->tm.e += tx * r->tm.a;
            r->tm.f += tx * r->tm.b;
            if (e->num < -200.0) /* a gap of a fifth of an em or more */
                zpd_raw_break(c, 0);
        }
    }
}

static const zpd_operand *zpd_string_op(zpd_text_ctx *c, int i)
{
    const zpd_operand *o = zpd_op(c, i);
    return (o && (o->t == ZPD_TOK_STRING || o->t == ZPD_TOK_HEXSTRING)) ? o : NULL;
}

static void zpd_operator(zpd_text_ctx *c, zpd_run *r, const char *op, int depth)
{
    zpd_gstate *gs = &r->gs;
    const zpd_operand *s;
    switch (op[0]) {
    case 'q':
        if (op[1] == '\0' && r->nstack < ZPD_MAX_GSTACK)
            r->stack[r->nstack++] = *gs;
        return;
    case 'Q':
        if (op[1] == '\0' && r->nstack > 0)
            *gs = r->stack[--r->nstack];
        return;
    case 'c':
        if (strcmp(op, "cm") == 0) {
            zpd_mat m = {zpd_num(c, 5), zpd_num(c, 4), zpd_num(c, 3),
                         zpd_num(c, 2), zpd_num(c, 1), zpd_num(c, 0)};
            gs->ctm = zpd_mul(m, gs->ctm);
        }
        return;
    case 'B':
        if (strcmp(op, "BT") == 0)
            r->tm = r->tlm = zpd_identity;
        return;
    case 'E':
        if (strcmp(op, "ET") == 0)
            zpd_raw_break(c, 1);
        return;
    case 'D':
        if (strcmp(op, "Do") == 0)
            zpd_do(c, r, depth);
        return;
    case '\'':
        zpd_next_line(r, 0, -gs->tl);
        zpd_raw_break(c, 1);
        if ((s = zpd_string_op(c, 0)))
            zpd_show(c, r, c->opstr.p + s->off, s->len);
        return;
    case '"':
        gs->tw = zpd_num(c, 2);
        gs->tc = zpd_num(c, 1);
        zpd_next_line(r, 0, -gs->tl);
        zpd_raw_break(c, 1);
        if ((s = zpd_string_op(c, 0)))
            zpd_show(c, r, c->opstr.p + s->off, s->len);
        return;
    case 'T':
        break;
    default:
        return;
    }
    switch (op[1]) {
    case 'f':
        zpd_set_font(c, r);
        break;
    case 'c':
        gs->tc = zpd_num(c, 0);
        break;
    case 'w':
        gs->tw = zpd_num(c, 0);
        break;
    case 'z':
        gs->th = zpd_num(c, 0) / 100.0;
        break;
    case 'L':
        gs->tl = zpd_num(c, 0);
        break;
    case 's':
        gs->ts = zpd_num(c, 0);
        break;
    case 'd':
        zpd_raw_break(c, zpd_num(c, 0) != 0.0);
        zpd_next_line(r, zpd_num(c, 1), zpd_num(c, 0));
        break;
    case 'D':
        gs->tl = -zpd_num(c, 0);
        zpd_raw_break(c, zpd_num(c, 0) != 0.0);
        zpd_next_line(r, zpd_num(c, 1), zpd_num(c, 0));
        break;
    case 'm': {
        zpd_mat m = {zpd_num(c, 5), zpd_num(c, 4), zpd_num(c, 3),
                     zpd_num(c, 2), zpd_num(c, 1), zpd_num(c, 0)};
        zpd_raw_break(c, fabs(m.f - r->tlm.f) > 0.01);
        r->tm = r->tlm = m;
        break;
    }
    case '*':
        zpd_raw_break(c, 1);
        zpd_next_line(r, 0, -gs->tl);
        break;
    case 'j':
        if ((s = zpd_string_op(c, 0)))
            zpd_show(c, r, c->opstr.p + s->off, s->len);
        break;
    case 'J': {
        const zpd_operand *a = zpd_op(c, 0);
        if (a && a->t == ZPD_TOK_ARRAY_CLOSE)
            zpd_tj_array(c, r, a);
        break;
    }
    default:
        break;
    }
}

static int zpd_push_bytes(zpd_text_ctx *c, zpd_operand *o, const zpd_lex *lx)
{
    o->off = c->opstr.n;
    o->len = lx->len;
    if (!zpd_buf_add(&c->opstr, lx->buf, lx->len) || !zpd_buf_add(&c->opstr, "", 1)) {
        zpd_fail(c, "memory");
        return 0;
    }
    return 1;
}

static void zpd_walk(zpd_text_ctx *c, const unsigned char *data, size_t n, zpd_run *r, int depth)
{
    zpd_lex lx;
    zpd_lex_init(&lx, data, n);
    int in_array = 0, dict_depth = 0;
    size_t astart = 0;

    for (zpd_tok_type t = zpd_lex_next(&lx); t != ZPD_TOK_EOF && !c->status; t = zpd_lex_next(&lx)) {
        if (t == ZPD_TOK_ERROR) {
            zpd_fail(c, "memory");
            break;
        }
        if (dict_depth > 0) {
            /* Inline dictionaries (BDC properties) carry no text. */
            if (t == ZPD_TOK_DICT_OPEN)
                dict_depth++;
            else if (t == ZPD_TOK_DICT_CLOSE)
                dict_depth--;
            continue;
        }
        if (t == ZPD_TOK_DICT_OPEN) {
            dict_depth = 1;
            continue;
        }
        if (t == ZPD_TOK_ARRAY_OPEN) {
            in_array++;
            if (in_array == 1)
                astart = c->narr;
            continue;
        }
        if (t == ZPD_TOK_ARRAY_CLOSE) {
            if (in_array > 0 && --in_array == 0 && c->nops < ZPD_MAX_OPS) {
                zpd_operand *o = &c->ops[c->nops++];
                *o = (zpd_operand){ZPD_TOK_ARRAY_CLOSE, 0, 0, 0, astart, c->narr - astart};
            }
            continue;
        }
        if (t == ZPD_TOK_OPERATOR) {
            if (in_array) /* an operator inside an array: malformed, dropped */
                continue;
            if (zpd_lex_is(&lx, "BI")) {
                /* Inline image: skip the dictionary's tokens to ID, then its data. */
                while ((t = zpd_lex_next(&lx)) != ZPD_TOK_EOF && t != ZPD_TOK_ERROR &&
                       !zpd_lex_is(&lx, "ID"))
                    ;
                if (t == ZPD_TOK_OPERATOR)
                    zpd_lex_inline_image(&lx);
            } else {
                zpd_operator(c, r, (const char *) lx.buf, depth);
            }
            c->nops = 0;
            c->opstr.n = 0;
            c->narr = 0;
            continue;
        }
        /* An operand: a number, name or string, on the stack or in an array. */
        zpd_operand o = {t, lx.num, 0, 0, 0, 0};
        if ((t == ZPD_TOK_NAME || t == ZPD_TOK_STRING || t == ZPD_TOK_HEXSTRING) &&
            !zpd_push_bytes(c, &o, &lx))
            break;
        if (in_array) {
            if (in_array == 1) {
                if (c->narr == c->caparr) {
                    size_t cap = c->caparr ? c->caparr * 2 : 64;
                    zpd_operand *grown = realloc(c->arr, cap * sizeof(zpd_operand));
                    if (!grown) {
                        zpd_fail(c, "memory");
                        break;
                    }
                    c->arr = grown;
                    c->caparr = cap;
                }
                c->arr[c->narr++] = o;
            }
        } else if (c->nops < ZPD_MAX_OPS) {
            c->ops[c->nops++] = o;
        } else {
            /* Too many operands: keep the most recent ones. */
            memmove(c->ops, c->ops + 1, (ZPD_MAX_OPS - 1) * sizeof(zpd_operand));
            c->ops[ZPD_MAX_OPS - 1] = o;
        }
    }
    zpd_lex_free(&lx);
}

/* ---- the reading layout --------------------------------------------------------- */

typedef struct {
    double ox, oy;   /* the first glyph's origin */
    double ux, uy;   /* the writing direction, a unit vector */
    double ex, ey;   /* where the last glyph ends */
    double size;
    size_t off, len; /* in the span pool */
} zpd_span;

static int zpd_span_cmp_y(const void *a, const void *b)
{
    const zpd_span *s = a, *t = b;
    if (s->oy != t->oy)
        return s->oy > t->oy ? -1 : 1; /* top first: larger y */
    return s->ox < t->ox ? -1 : s->ox > t->ox;
}

static int zpd_span_cmp_x(const void *a, const void *b)
{
    const zpd_span *s = a, *t = b;
    return s->ox < t->ox ? -1 : s->ox > t->ox;
}

static int zpd_ends_space(const zpd_buf *b)
{
    return b->n == 0 || b->p[b->n - 1] == ' ' || b->p[b->n - 1] == '\n';
}

/* Glyphs (in stream order) to spans: runs along one baseline, in the
   glyphs' own writing direction (so rotated text, such as a plot's y-axis
   labels, stays whole), with no large gap, and a space where the gap is a
   word space. Then spans to lines, by the baseline of their start, top to
   bottom, each left to right. */
static int zpd_reading_layout(zpd_text_ctx *c)
{
    c->out.n = 0;
    if (c->ng == 0)
        return 1;
    zpd_span *sp = calloc(c->ng, sizeof(zpd_span));
    zpd_buf spool = {0};
    size_t ns = 0;
    if (!sp)
        return 0;
    for (size_t i = 0; i < c->ng; i++) {
        const zpd_glyph *g = &c->g[i];
        double size = g->size > 0 ? g->size : 1.0;
        const unsigned char *text = c->pool.p + g->off;
        zpd_span *cur = ns ? &sp[ns - 1] : NULL;
        double dx = g->x1 - g->x0, dy = g->y1 - g->y0, len = hypot(dx, dy);
        double ux = cur ? cur->ux : 1.0, uy = cur ? cur->uy : 0.0;
        if (len > 1e-6) {
            ux = dx / len;
            uy = dy / len;
        }
        int join = 0;
        if (cur) {
            double tol = 0.3 * fmax(size, cur->size);
            double vx = g->x0 - cur->ox, vy = g->y0 - cur->oy;
            double perp = fabs(cur->ux * vy - cur->uy * vx);
            double gap = cur->ux * (g->x0 - cur->ex) + cur->uy * (g->y0 - cur->ey);
            join = ux * cur->ux + uy * cur->uy > 0.95 && perp <= tol &&
                   gap > -0.6 * size && gap < 3.0 * size;
            if (join && gap > 0.15 * size && !(g->len && text[0] == ' ') &&
                cur->len && spool.p[cur->off + cur->len - 1] != ' ') {
                zpd_buf_add(&spool, " ", 1);
                cur->len++;
            }
        }
        if (!join) {
            cur = &sp[ns++];
            *cur = (zpd_span){g->x0, g->y0, ux, uy, g->x0, g->y0, size, spool.n, 0};
        }
        zpd_buf_add(&spool, text, g->len);
        cur->len += g->len;
        /* The span ends where its furthest glyph ends along its direction. */
        if (cur->ux * (g->x1 - cur->ex) + cur->uy * (g->y1 - cur->ey) > 0 || cur->len == g->len) {
            cur->ex = g->x1;
            cur->ey = g->y1;
        }
        if (size > cur->size)
            cur->size = size;
    }

    qsort(sp, ns, sizeof(zpd_span), zpd_span_cmp_y);
    for (size_t i = 0; i < ns;) {
        /* A line: the spans whose start is within half a size of the first's. */
        size_t j = i + 1;
        while (j < ns && sp[i].oy - sp[j].oy <= 0.5 * fmax(sp[i].size, sp[j].size))
            j++;
        qsort(sp + i, j - i, sizeof(zpd_span), zpd_span_cmp_x);
        if (c->out.n)
            zpd_buf_add(&c->out, "\n", 1);
        for (size_t k = i; k < j; k++) {
            if (k > i && !zpd_ends_space(&c->out) && sp[k].len && spool.p[sp[k].off] != ' ')
                zpd_buf_add(&c->out, " ", 1);
            zpd_buf_add(&c->out, spool.p + sp[k].off, sp[k].len);
        }
        i = j;
    }
    free(sp);
    free(spool.p);
    return 1;
}

/* ---- entry points ------------------------------------------------------------------ */


static pdfio_dict_t *zpd_page_resources(pdfio_obj_t *page, int max_depth, int *deep)
{
    pdfio_dict_t *dict = pdfioObjGetDict(page);
    pdfio_dict_t *src = dict ? zpd_inherited(dict, "Resources", max_depth, deep) : NULL;
    return src ? zpd_dict_dict(src, "Resources") : NULL;
}

const char *zpd_text_extract(zpd_text_ctx *c, pdfio_obj_t *page, int raw,
                             const unsigned char **text, size_t *len, int *unmapped)
{
    c->ng = 0;
    c->pool.n = c->raw.n = c->out.n = 0;
    c->raw_text = 0;
    c->unmapped = 0;
    if (page) {
        int deep = 0;
        zpd_run r = {0};
        r.gs.ctm = zpd_identity;
        r.gs.th = 1.0;
        r.tm = r.tlm = zpd_identity;
        r.resources = zpd_page_resources(page, c->max_depth, &deep);
        if (deep)
            zpd_fail(c, "max_depth");
        if (!c->status)
            zpd_read_page(c, page);
        if (!c->status)
            zpd_walk(c, c->content.p, c->content.n, &r, 0);
    }
    if (c->status)
        return c->status;
    const zpd_buf *b = &c->raw;
    if (!raw) {
        if (!zpd_reading_layout(c))
            return "memory";
        b = &c->out;
    }
    /* Trailing white space is not text. */
    size_t n = b->n;
    while (n && (b->p[n - 1] == ' ' || b->p[n - 1] == '\n'))
        n--;
    *text = n ? b->p : (const unsigned char *) "";
    *len = n;
    *unmapped = c->unmapped;
    return NULL;
}

#ifndef ZPD_STANDALONE

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

/* zupdf_page_text(ptr, pages, raw, max_depth, max_stream): list(text,
   unmapped), one element per page in `pages` (1-based, checked in R). */
SEXP zupdf_page_text(SEXP ptr, SEXP pages, SEXP raw_, SEXP max_depth, SEXP max_stream)
{
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    int raw = Rf_asLogical(raw_) == TRUE;
    R_xlen_t np = XLENGTH(pages);

    const char *names[] = {"text", "unmapped", ""};
    SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
    SEXP text = Rf_allocVector(STRSXP, np);
    SET_VECTOR_ELT(v, 0, text);
    SEXP unmapped = Rf_allocVector(INTSXP, np);
    SET_VECTOR_ELT(v, 1, unmapped);

    zpd_text_ctx *c = zpd_text_ctx_new(h, Rf_asInteger(max_depth), Rf_asReal(max_stream));
    if (!c) {
        UNPROTECT(1);
        return zpd_status("memory");
    }
    const char *status = NULL;
    for (R_xlen_t k = 0; k < np && !status; k++) {
        R_CheckUserInterrupt(); /* between pages: only h->text is in flight */
        const unsigned char *t;
        size_t len;
        int um = 0;
        pdfio_obj_t *page = pdfioFileGetPage(h->pdf, (size_t) INTEGER(pages)[k] - 1);
        status = zpd_text_extract(c, page, raw, &t, &len, &um);
        if (status)
            break;
        SET_STRING_ELT(text, k, Rf_mkCharLenCE((const char *) t, (int) len, CE_UTF8));
        INTEGER(unmapped)[k] = um;
    }
    zpd_text_release(h);
    zpd_errors_to_warnings(&h->rec);
    SEXP out = zpd_result(status ? status : "ok", v, &h->rec);
    UNPROTECT(1);
    return out;
}

/* ---- tokens ------------------------------------------------------------------------- */

static int zpd_add_token(zpd_text_ctx *c, int type, const void *s, size_t n)
{
    if (c->ntok == c->captok) {
        size_t cap = c->captok ? c->captok * 2 : 1024;
        int *t = realloc(c->tok_type, cap * sizeof(int));
        if (t)
            c->tok_type = t;
        size_t *o = realloc(c->tok_off, cap * sizeof(size_t));
        if (o)
            c->tok_off = o;
        size_t *l = realloc(c->tok_len, cap * sizeof(size_t));
        if (l)
            c->tok_len = l;
        if (!t || !o || !l)
            return 0;
        c->captok = cap;
    }
    c->tok_type[c->ntok] = type;
    c->tok_off[c->ntok] = c->tok_pool.n;
    c->tok_len[c->ntok] = n;
    c->ntok++;
    return zpd_buf_add(&c->tok_pool, s, n);
}

/* zupdf_page_tokens(ptr, page, max_stream): list(type, value), the
   tokens of the page's content streams in order. */
SEXP zupdf_page_tokens(SEXP ptr, SEXP page_, SEXP max_stream)
{
    static const char *types[] = {"eof", "number", "name", "string", "string",
                                  "operator", "array_open", "array_close",
                                  "dict_open", "dict_close", "inline_image", "error"};
    zpd_file *h = zpd_file_get(ptr);
    if (!h)
        return zpd_status("closed");
    zpd_record_reset(&h->rec);
    zpd_text_ctx *c = zpd_text_ctx_new(h, 0, Rf_asReal(max_stream));
    if (!c)
        return zpd_status("memory");
    pdfio_obj_t *page = pdfioFileGetPage(h->pdf, (size_t) Rf_asInteger(page_) - 1);
    if (page)
        zpd_read_page(c, page);

    zpd_lex lx;
    zpd_lex_init(&lx, c->content.p, c->content.n);
    for (zpd_tok_type t = zpd_lex_next(&lx); t != ZPD_TOK_EOF && !c->status; t = zpd_lex_next(&lx)) {
        int ok;
        if (t == ZPD_TOK_ERROR) {
            zpd_fail(c, "memory");
            break;
        }
        if (t == ZPD_TOK_OPERATOR && zpd_lex_is(&lx, "ID")) {
            ok = zpd_add_token(c, t, lx.buf, lx.len);
            zpd_lex_inline_image(&lx);
            char desc[64];
            snprintf(desc, sizeof(desc), "%lu bytes", (unsigned long) lx.len);
            ok = ok && zpd_add_token(c, ZPD_TOK_INLINE_IMAGE, desc, strlen(desc));
        } else {
            ok = zpd_add_token(c, t, lx.buf, lx.len);
        }
        if (!ok)
            zpd_fail(c, "memory");
    }
    zpd_lex_free(&lx);
    const char *status = c->status;

    SEXP out;
    if (status) {
        zpd_text_release(h);
        out = zpd_status(status);
    } else {
        const char *names[] = {"type", "value", ""};
        SEXP v = PROTECT(Rf_mkNamed(VECSXP, names));
        SEXP type = Rf_allocVector(STRSXP, (R_xlen_t) c->ntok);
        SET_VECTOR_ELT(v, 0, type);
        SEXP value = Rf_allocVector(STRSXP, (R_xlen_t) c->ntok);
        SET_VECTOR_ELT(v, 1, value);
        for (size_t i = 0; i < c->ntok; i++) {
            SET_STRING_ELT(type, (R_xlen_t) i, Rf_mkChar(types[c->tok_type[i]]));
            const char *s = (const char *) c->tok_pool.p + c->tok_off[i];
            size_t n = c->tok_len[i];
            SET_STRING_ELT(value, (R_xlen_t) i, n ? zpd_mkchar_pdf(s, n) : Rf_mkChar(""));
        }
        zpd_text_release(h);
        zpd_errors_to_warnings(&h->rec);
        out = zpd_result("ok", v, &h->rec);
        UNPROTECT(1);
    }
    return out;
}

#endif /* !ZPD_STANDALONE */
