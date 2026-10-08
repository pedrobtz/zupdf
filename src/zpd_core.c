/* The R-free core shared by the R entry points and the fuzz target
 * (design section 15): pdfio's error callback, and dictionary access that
 * follows indirect references and inherited page attributes. */

#include <string.h>

#include "zpd.h"

void zpd_record_reset(zpd_record *rec)
{
    rec->error[0] = '\0';
    rec->nerror = 0;
    rec->warning[0] = '\0';
    rec->nwarning = 0;
}

static void zpd_copy_message(char *dst, size_t n, const char *src)
{
    size_t len = strlen(src);
    if (len >= n)
        len = n - 1;
    memcpy(dst, src, len);
    dst[len] = '\0';
}

bool zpd_error_cb(pdfio_file_t *pdf, const char *message, void *data)
{
    zpd_record *rec = data;
    (void) pdf;
    if (strncmp(message, "WARNING:", 8) == 0) {
        if (rec->nwarning++ == 0)
            zpd_copy_message(rec->warning, sizeof(rec->warning), message);
        return true;
    }
    if (rec->nerror++ == 0)
        zpd_copy_message(rec->error, sizeof(rec->error), message);
    return false;
}

/* pdfio's dictionary getters do not follow indirect references; these do,
   one level, which is what the page attributes need. */
pdfio_dict_t *zpd_dict_dict(pdfio_dict_t *dict, const char *key)
{
    pdfio_valtype_t t = pdfioDictGetType(dict, key);
    if (t == PDFIO_VALTYPE_DICT)
        return pdfioDictGetDict(dict, key);
    if (t == PDFIO_VALTYPE_INDIRECT) {
        pdfio_obj_t *obj = pdfioDictGetObj(dict, key);
        return obj ? pdfioObjGetDict(obj) : NULL;
    }
    return NULL;
}

pdfio_array_t *zpd_dict_array(pdfio_dict_t *dict, const char *key)
{
    pdfio_valtype_t t = pdfioDictGetType(dict, key);
    if (t == PDFIO_VALTYPE_ARRAY)
        return pdfioDictGetArray(dict, key);
    if (t == PDFIO_VALTYPE_INDIRECT) {
        pdfio_obj_t *obj = pdfioDictGetObj(dict, key);
        return obj ? pdfioObjGetArray(obj) : NULL;
    }
    return NULL;
}

/* The dictionary that supplies an inheritable page attribute (MediaBox,
   CropBox, Rotate; PDF 2.0, 7.7.3.4): the page's own or the nearest
   ancestor's through /Parent. The walk is bounded by max_depth, which
   also stops a /Parent cycle. Sets *deep when the bound is reached. */
pdfio_dict_t *zpd_inherited(pdfio_dict_t *dict, const char *key,
                                   int max_depth, int *deep)
{
    for (int d = 0; dict; d++) {
        if (d > max_depth) { /* GUARD: max_depth_inherit */
            *deep = 1;
            return NULL;
        }
        if (pdfioDictGetType(dict, key) != PDFIO_VALTYPE_NONE)
            return dict;
        dict = zpd_dict_dict(dict, "Parent");
    }
    return NULL;
}

