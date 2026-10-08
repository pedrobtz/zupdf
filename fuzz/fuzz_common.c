/* The open and close the fuzz target and its canary share (fuzz.h). */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "fuzz.h"

int zpd_fuzz_open(const uint8_t *data, size_t size, zpd_file *h, char *path, size_t pathlen)
{
    const char *dir = getenv("TMPDIR");
    snprintf(path, pathlen, "%s/zupdf-fuzz-XXXXXX", dir && *dir ? dir : "/tmp");
    int fd = mkstemp(path);
    if (fd < 0)
        return 0;
    int ok = write(fd, data, size) == (ssize_t) size;
    close(fd);
    memset(h, 0, sizeof(*h));
    zpd_record_reset(&h->rec);
    if (ok)
        h->pdf = pdfioFileOpen(path, NULL, NULL, zpd_error_cb, &h->rec);
    return h->pdf != NULL;
}

void zpd_fuzz_close(zpd_file *h, const char *path)
{
    zpd_text_release(h);
    zpd_fonts_release(h);
    if (h->pdf)
        pdfioFileClose(h->pdf);
    unlink(path);
}

