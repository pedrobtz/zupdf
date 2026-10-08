/* PDF text strings to R character (design section 6). pdfio converts a
 * string that starts with the UTF-16BE byte-order mark to UTF-8 as it reads
 * it, so what reaches here is UTF-8 or PDFDocEncoding. A string that is
 * already valid UTF-8 is kept; anything else is read as PDFDocEncoding,
 * whose bytes map one to one onto code points (PDF 2.0, Annex D.2). */

#include <stdlib.h>
#include <string.h>

#include "zpd.h"

#include <zufast/utf8.h>

/* PDFDocEncoding's code points where they differ from Latin-1: 0x18-0x1F
   and 0x80-0xAD. 0xFFFD marks the bytes the encoding leaves undefined
   (0x7F, 0x9F, 0xAD). */
static const unsigned short zpd_pdfdoc_low[8] = {
    0x02D8, 0x02C7, 0x02C6, 0x02D9, 0x02DD, 0x02DB, 0x02DA, 0x02DC
};

static const unsigned short zpd_pdfdoc_high[46] = {
    0x2022, 0x2020, 0x2021, 0x2026, 0x2014, 0x2013, 0x0192, 0x2044, /* 80 */
    0x2039, 0x203A, 0x2212, 0x2030, 0x201E, 0x201C, 0x201D, 0x2018, /* 88 */
    0x2019, 0x201A, 0x2122, 0xFB01, 0xFB02, 0x0141, 0x0152, 0x0160, /* 90 */
    0x0178, 0x017D, 0x0131, 0x0142, 0x0153, 0x0161, 0x017E, 0xFFFD, /* 98 */
    0x20AC, 0x00A1, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7, /* A0 */
    0x00A8, 0x00A9, 0x00AA, 0x00AB, 0x00AC, 0xFFFD                  /* A8 */
};

static unsigned zpd_pdfdoc_code(unsigned char b)
{
    if (b >= 0x18 && b <= 0x1F)
        return zpd_pdfdoc_low[b - 0x18];
    if (b == 0x7F)
        return 0xFFFD;
    if (b >= 0x80 && b <= 0xAD)
        return zpd_pdfdoc_high[b - 0x80];
    return b;
}

static size_t zpd_utf8_put(char *out, unsigned cp)
{
    if (cp < 0x80) {
        out[0] = (char) cp;
        return 1;
    }
    if (cp < 0x800) {
        out[0] = (char) (0xC0 | (cp >> 6));
        out[1] = (char) (0x80 | (cp & 0x3F));
        return 2;
    }
    out[0] = (char) (0xE0 | (cp >> 12));
    out[1] = (char) (0x80 | ((cp >> 6) & 0x3F));
    out[2] = (char) (0x80 | (cp & 0x3F));
    return 3;
}

SEXP zpd_mkchar_pdf(const char *s, size_t n)
{
    if (zuf_utf8_valid(s, n))
        return Rf_mkCharLenCE(s, (int) n, CE_UTF8);
    /* Every PDFDocEncoding byte becomes at most three UTF-8 bytes. The
       buffer is R's, so an allocation failure cannot leak it. */
    char *buf = R_alloc(3 * n + 1, 1);
    size_t k = 0;
    for (size_t i = 0; i < n; i++)
        k += zpd_utf8_put(buf + k, zpd_pdfdoc_code((unsigned char) s[i]));
    return Rf_mkCharLenCE(buf, (int) k, CE_UTF8);
}

SEXP zpd_string_or_na(const char *s)
{
    SEXP out = PROTECT(Rf_allocVector(STRSXP, 1));
    SET_STRING_ELT(out, 0, s ? zpd_mkchar_pdf(s, strlen(s)) : NA_STRING);
    UNPROTECT(1);
    return out;
}
