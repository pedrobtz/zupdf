/* Shared declarations of the text extractor (design section 8):
 * zpd_font.c loads fonts, zpd_text.c walks content streams. */
#ifndef ZPD_TEXT_H
#define ZPD_TEXT_H

#include <stdint.h>

#include "zpd.h"

/* A ToUnicode mapping: codes lo..hi map to the code points at
   cps[off .. off + n - 1], the last of which is advanced by (code - lo). */
typedef struct {
    uint32_t lo, hi;
    uint32_t off;
    uint16_t n;
} zpd_umap;

/* A CID font's widths: codes lo..hi have width w, or, when ws is set,
   widths ws[k], ws[k + 1], ... (from /W). */
typedef struct {
    uint32_t lo, hi;
    double w;
    int32_t k; /* index into the font's cid_ws, or -1 */
} zpd_wrange;

typedef struct zpd_font {
    size_t objnum;      /* 0 for a font given as a direct dictionary */
    int code_bytes;     /* 1 for simple fonts, 2 for Type0 */
    double scale;       /* glyph space to text space: 0.001, or FontMatrix[0] */
    double widths[256]; /* simple fonts, in glyph space */
    double default_width;
    zpd_wrange *wr;     /* CID fonts */
    size_t nwr;
    double *cid_ws;
    size_t ncid_ws;
    uint32_t enc[256];  /* simple fonts: code to code point, 0 = unmapped */
    zpd_umap *um;       /* ToUnicode, sorted by lo */
    size_t num;
    uint32_t *cps;
    size_t ncps;
    int identity;       /* an Identity-UCS2 ToUnicode with no entries: codes are UTF-16 */
    char name[64];      /* /BaseFont, for pdf_data(font_info = TRUE) */
    double ascent, descent; /* in em, from the descriptor, metrics or bbox */
    struct zpd_font *next;
} zpd_font;

typedef struct zpd_font_cache {
    zpd_font *head;
} zpd_font_cache;

/* The font for a font dictionary, loaded once per file when it is an
   object (cached in `cache`) and once per call when it is a direct
   dictionary (kept in `local`). NULL only when memory runs out. Problems
   in the font are not errors: a missing width is estimated and a missing
   mapping makes U+FFFD. */
zpd_font *zpd_font_get(zpd_font_cache *cache, zpd_font_cache *local,
                       pdfio_obj_t *obj, pdfio_dict_t *dict, double max_stream);

void zpd_font_cache_free(zpd_font_cache *cache);

/* Appends the code points for `code` to out (at most `max`), returning
   how many; 0 when the font cannot map it. */
size_t zpd_font_unicode(const zpd_font *f, uint32_t code, uint32_t *out, size_t max);

/* The width of `code` in glyph space. */
double zpd_font_width(const zpd_font *f, uint32_t code);

/* A decoded stream read whole into a malloc() buffer, at most max_stream
   bytes (zpd_text.c). Returns NULL when it cannot be read; *over is set
   when max_stream was the reason. */
unsigned char *zpd_slurp(pdfio_stream_t *st, double max_stream, size_t *len, int *over);

/* The text walk (zpd_text.c), R-free: a context owned by the handle
   (h->text), then one page at a time. zpd_text_extract() returns NULL or
   a status ("max_depth", "form_cycle", "max_stream", "memory"); the text
   it gives stays valid until the next call or zpd_text_release(). */
struct zpd_text_ctx *zpd_text_ctx_new(zpd_file *h, int max_depth, double max_stream);
const char *zpd_text_extract(struct zpd_text_ctx *c, pdfio_obj_t *page, int raw,
                             const unsigned char **text, size_t *len, int *unmapped);

/* The glyph-name to code-point lookup of zpd_glyphs.h, with uniXXXX and
   uXXXX[XX] names, and suffixes (.sc, _alt) stripped; 0 when unknown. */
uint32_t zpd_glyph_unicode(const char *name);

#endif
