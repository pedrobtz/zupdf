/* The content-stream lexer of zpd_lex.h (PDF 2.0, 7.2 and 7.3). */

#include <stdlib.h>
#include <string.h>

#include "zpd_lex.h"

static int zpd_is_space(int c)
{
    return c == 0 || c == '\t' || c == '\n' || c == '\f' || c == '\r' || c == ' ';
}

static int zpd_is_delim(int c)
{
    return c == '(' || c == ')' || c == '<' || c == '>' || c == '[' || c == ']' ||
           c == '{' || c == '}' || c == '/' || c == '%';
}

static int zpd_hexval(int c)
{
    if (c >= '0' && c <= '9')
        return c - '0';
    if (c >= 'a' && c <= 'f')
        return c - 'a' + 10;
    if (c >= 'A' && c <= 'F')
        return c - 'A' + 10;
    return -1;
}

void zpd_lex_init(zpd_lex *lx, const unsigned char *data, size_t n)
{
    lx->p = data;
    lx->end = data + n;
    lx->type = ZPD_TOK_EOF;
    lx->buf = NULL;
    lx->len = lx->cap = 0;
    lx->num = 0.0;
}

void zpd_lex_free(zpd_lex *lx)
{
    free(lx->buf);
    lx->buf = NULL;
    lx->len = lx->cap = 0;
}

static int zpd_lex_put(zpd_lex *lx, unsigned char c)
{
    if (lx->len + 1 >= lx->cap) {
        size_t cap = lx->cap ? lx->cap * 2 : 256;
        unsigned char *grown = realloc(lx->buf, cap);
        if (!grown)
            return 0;
        lx->buf = grown;
        lx->cap = cap;
    }
    lx->buf[lx->len++] = c;
    lx->buf[lx->len] = '\0';
    return 1;
}

static zpd_tok_type zpd_lex_fail(zpd_lex *lx)
{
    lx->p = lx->end;
    return lx->type = ZPD_TOK_ERROR;
}

static zpd_tok_type zpd_lex_literal(zpd_lex *lx)
{
    int depth = 0;
    while (lx->p < lx->end) {
        int c = *lx->p++;
        if (c == '\\') {
            if (lx->p >= lx->end)
                break;
            c = *lx->p++;
            switch (c) {
            case 'n': c = '\n'; break;
            case 'r': c = '\r'; break;
            case 't': c = '\t'; break;
            case 'b': c = '\b'; break;
            case 'f': c = '\f'; break;
            case '\r': /* a line continuation */
                if (lx->p < lx->end && *lx->p == '\n')
                    lx->p++;
                continue;
            case '\n':
                continue;
            default:
                if (c >= '0' && c <= '7') {
                    int v = c - '0';
                    for (int i = 0; i < 2 && lx->p < lx->end && *lx->p >= '0' && *lx->p <= '7'; i++)
                        v = (v << 3) | (*lx->p++ - '0');
                    c = v & 0xFF;
                }
                /* \\, \(, \) and an unknown escape: the character itself */
                break;
            }
        } else if (c == '(') {
            depth++;
        } else if (c == ')') {
            if (depth-- == 0)
                break;
        }
        if (!zpd_lex_put(lx, (unsigned char) c))
            return zpd_lex_fail(lx);
    }
    return lx->type = ZPD_TOK_STRING;
}

static zpd_tok_type zpd_lex_hex(zpd_lex *lx)
{
    int hi = -1;
    while (lx->p < lx->end) {
        int c = *lx->p++;
        if (c == '>')
            break;
        int v = zpd_hexval(c);
        if (v < 0)
            continue; /* white space, or junk, ignored */
        if (hi < 0) {
            hi = v;
        } else {
            if (!zpd_lex_put(lx, (unsigned char) ((hi << 4) | v)))
                return zpd_lex_fail(lx);
            hi = -1;
        }
    }
    if (hi >= 0 && !zpd_lex_put(lx, (unsigned char) (hi << 4)))
        return zpd_lex_fail(lx);
    return lx->type = ZPD_TOK_HEXSTRING;
}

static zpd_tok_type zpd_lex_name(zpd_lex *lx)
{
    while (lx->p < lx->end && !zpd_is_space(*lx->p) && !zpd_is_delim(*lx->p)) {
        int c = *lx->p++;
        if (c == '#' && lx->end - lx->p >= 2 && zpd_hexval(lx->p[0]) >= 0 &&
            zpd_hexval(lx->p[1]) >= 0) {
            c = (zpd_hexval(lx->p[0]) << 4) | zpd_hexval(lx->p[1]);
            lx->p += 2;
        }
        if (!zpd_lex_put(lx, (unsigned char) c))
            return zpd_lex_fail(lx);
    }
    return lx->type = ZPD_TOK_NAME;
}

/* A number, if the bytes are one: [+-]? digits [. digits] | [+-]? . digits */
static int zpd_parse_number(const unsigned char *s, size_t n, double *out)
{
    size_t i = 0;
    int neg = 0, digits = 0;
    double v = 0.0, scale = 1.0;
    if (i < n && (s[i] == '+' || s[i] == '-'))
        neg = s[i++] == '-';
    for (; i < n && s[i] >= '0' && s[i] <= '9'; i++, digits++)
        v = v * 10.0 + (s[i] - '0');
    if (i < n && s[i] == '.') {
        for (i++; i < n && s[i] >= '0' && s[i] <= '9'; i++, digits++) {
            scale /= 10.0;
            v += (s[i] - '0') * scale;
        }
    }
    if (i != n || digits == 0)
        return 0;
    *out = neg ? -v : v;
    return 1;
}

zpd_tok_type zpd_lex_next(zpd_lex *lx)
{
    lx->len = 0;
    if (lx->buf)
        lx->buf[0] = '\0';
    for (;;) {
        while (lx->p < lx->end && zpd_is_space(*lx->p))
            lx->p++;
        if (lx->p < lx->end && *lx->p == '%') {
            while (lx->p < lx->end && *lx->p != '\n' && *lx->p != '\r')
                lx->p++;
            continue;
        }
        break;
    }
    if (lx->p >= lx->end)
        return lx->type = ZPD_TOK_EOF;

    int c = *lx->p++;
    switch (c) {
    case '(':
        return zpd_lex_literal(lx);
    case '<':
        if (lx->p < lx->end && *lx->p == '<') {
            lx->p++;
            return lx->type = ZPD_TOK_DICT_OPEN;
        }
        return zpd_lex_hex(lx);
    case '>':
        if (lx->p < lx->end && *lx->p == '>')
            lx->p++;
        return lx->type = ZPD_TOK_DICT_CLOSE;
    case '[':
        return lx->type = ZPD_TOK_ARRAY_OPEN;
    case ']':
        return lx->type = ZPD_TOK_ARRAY_CLOSE;
    case '/':
        return zpd_lex_name(lx);
    case ')':
    case '{':
    case '}':
        /* A stray delimiter: an operator of one byte, which the walk ignores. */
        if (!zpd_lex_put(lx, (unsigned char) c))
            return zpd_lex_fail(lx);
        return lx->type = ZPD_TOK_OPERATOR;
    default:
        break;
    }
    if (!zpd_lex_put(lx, (unsigned char) c))
        return zpd_lex_fail(lx);
    while (lx->p < lx->end && !zpd_is_space(*lx->p) && !zpd_is_delim(*lx->p))
        if (!zpd_lex_put(lx, *lx->p++))
            return zpd_lex_fail(lx);
    if (zpd_parse_number(lx->buf, lx->len, &lx->num))
        return lx->type = ZPD_TOK_NUMBER;
    return lx->type = ZPD_TOK_OPERATOR;
}

zpd_tok_type zpd_lex_inline_image(zpd_lex *lx)
{
    /* One white-space byte follows ID; the data runs to an EI that has
       white space before it and white space or the end after it. */
    if (lx->p < lx->end && zpd_is_space(*lx->p))
        lx->p++;
    const unsigned char *start = lx->p;
    while (lx->p + 1 < lx->end) {
        if (lx->p[0] == 'E' && lx->p[1] == 'I' && lx->p > start &&
            zpd_is_space(lx->p[-1]) &&
            (lx->p + 2 == lx->end || zpd_is_space(lx->p[2]) || zpd_is_delim(lx->p[2]))) {
            /* The white space before EI separates; it is not data. */
            lx->len = (size_t) (lx->p - 1 - start);
            lx->p += 2;
            return lx->type = ZPD_TOK_INLINE_IMAGE;
        }
        lx->p++;
    }
    lx->len = (size_t) (lx->end - start);
    lx->p = lx->end;
    return lx->type = ZPD_TOK_INLINE_IMAGE;
}

int zpd_lex_is(const zpd_lex *lx, const char *op)
{
    return lx->type == ZPD_TOK_OPERATOR && strcmp((const char *) lx->buf, op) == 0;
}
