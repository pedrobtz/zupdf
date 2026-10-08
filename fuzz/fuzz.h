/* Shared by the fuzz target and its canary: both open the input through
 * exactly the same code (fuzz_common.c). */
#ifndef ZPD_FUZZ_H
#define ZPD_FUZZ_H

#include <stddef.h>
#include <stdint.h>

#include "zpd.h"

/* Writes the input to a temporary file (pdfio reads files) and opens it as
   zupdf does; 0 when pdfio refuses it. */
int zpd_fuzz_open(const uint8_t *data, size_t size, zpd_file *h, char *path, size_t pathlen);

/* Frees the text walk's memory, closes the file, removes the copy. */
void zpd_fuzz_close(zpd_file *h, const char *path);

#endif
