/* The fuzz gate's canary (roadmap Stage 6): the same open as fuzz_pdf.c,
 * through the same code and flags, and a trap as soon as an input opens
 * with a page, which the seed corpus guarantees. tools/run-fuzz requires
 * this to crash before trusting the real target: a gate is trusted once it
 * has been seen to fail. */

#include <stdint.h>
#include <stddef.h>

#include "fuzz.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    zpd_file h;
    char path[1024];
    int opened = zpd_fuzz_open(data, size, &h, path, sizeof(path)) &&
                 pdfioFileGetNumPages(h.pdf) > 0;
    zpd_fuzz_close(&h, path);
    if (opened)
        __builtin_trap();
    return 0;
}
