/* libFuzzer target (design section 15, roadmap Stage 6): the R-free core
 * that hostile input reaches. Each input is written to a file (pdfio reads
 * files), opened with zupdf's error callback, every object loaded and every
 * stream read under a bound, and every page's text extracted in both
 * layouts. Invariants: no crash, no leak, no hang past libFuzzer's timeout,
 * nothing written to stderr (the build has PDFIO_NO_STDIO). */

#include <stdint.h>
#include <stdlib.h>

#include "zpd.h"
#include "zpd_text.h"

#define ZPD_FUZZ_MAX_OBJECTS 20000
#define ZPD_FUZZ_MAX_PAGES 200
#define ZPD_FUZZ_MAX_STREAM (1 << 20)
#define ZPD_FUZZ_MAX_DEPTH 16

#include "fuzz.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    zpd_file h;
    char path[1024];
    if (zpd_fuzz_open(data, size, &h, path, sizeof(path))) {
        /* Every object, and its stream, decoded, under a bound. */
        size_t n = pdfioFileGetNumObjs(h.pdf);
        for (size_t i = 0; i < n && i < ZPD_FUZZ_MAX_OBJECTS; i++) {
            pdfio_obj_t *obj = pdfioFileGetObj(h.pdf, i);
            if (!obj || !pdfioObjGetType(obj))
                continue;
            pdfio_stream_t *st = pdfioObjOpenStream(obj, true);
            if (st) {
                size_t len;
                int over;
                free(zpd_slurp(st, ZPD_FUZZ_MAX_STREAM, &len, &over));
                pdfioStreamClose(st);
            }
        }
        /* Every page's text, both layouts. */
        struct zpd_text_ctx *c = zpd_text_ctx_new(&h, ZPD_FUZZ_MAX_DEPTH, ZPD_FUZZ_MAX_STREAM);
        size_t np = pdfioFileGetNumPages(h.pdf);
        for (size_t p = 0; c && p < np && p < ZPD_FUZZ_MAX_PAGES; p++) {
            pdfio_obj_t *page = pdfioFileGetPage(h.pdf, p);
            for (int raw = 0; raw < 2; raw++) {
                const unsigned char *text;
                size_t len;
                int unmapped;
                zpd_text_extract(c, page, raw, &text, &len, &unmapped);
            }
        }
    }
    zpd_fuzz_close(&h, path);
    return 0;
}
