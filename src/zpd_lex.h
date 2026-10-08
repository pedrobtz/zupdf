/* A lexer for PDF content streams and CMaps (design section 8). It reads a
 * decoded stream from memory, so no pdfio stream is open while the text
 * walk runs, and it can skip an inline image's binary data, which pdfio's
 * tokenizer cannot. Project code: no pdfio, no R. */
#ifndef ZPD_LEX_H
#define ZPD_LEX_H

#include <stddef.h>

typedef enum {
    ZPD_TOK_EOF,
    ZPD_TOK_NUMBER,
    ZPD_TOK_NAME,         /* without the slash, #xx escapes decoded */
    ZPD_TOK_STRING,       /* a literal string's bytes, escapes decoded */
    ZPD_TOK_HEXSTRING,    /* a hex string's bytes */
    ZPD_TOK_OPERATOR,     /* any other keyword: Tj, BT, true, null, ... */
    ZPD_TOK_ARRAY_OPEN,
    ZPD_TOK_ARRAY_CLOSE,
    ZPD_TOK_DICT_OPEN,
    ZPD_TOK_DICT_CLOSE,
    ZPD_TOK_INLINE_IMAGE, /* the data between ID and EI; see zpd_lex_inline_image() */
    ZPD_TOK_ERROR         /* out of memory */
} zpd_tok_type;

typedef struct {
    const unsigned char *p, *end;
    /* The current token: its bytes (not NUL-terminated for strings, which
       may hold NULs) and, for a number, its value. */
    zpd_tok_type type;
    unsigned char *buf;
    size_t len, cap;
    double num;
} zpd_lex;

void zpd_lex_init(zpd_lex *lx, const unsigned char *data, size_t n);
void zpd_lex_free(zpd_lex *lx);

/* Reads the next token into lx; returns its type. */
zpd_tok_type zpd_lex_next(zpd_lex *lx);

/* Called after the ID operator: skips the image data up to and including
   EI, and makes the token an INLINE_IMAGE whose len is the data's length. */
zpd_tok_type zpd_lex_inline_image(zpd_lex *lx);

/* True when the current token is the operator `op`. */
int zpd_lex_is(const zpd_lex *lx, const char *op);

#endif
