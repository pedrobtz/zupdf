#include "zpd_r.h"

#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

/* Every .Call entry point is listed here; R_useDynamicSymbols(dll, FALSE)
   makes anything missing from the table unreachable by name. */
static const R_CallMethodDef CallEntries[] = {
    {"zupdf_build_info", (DL_FUNC) &zupdf_build_info, 0},
    {"zupdf_close",      (DL_FUNC) &zupdf_close,      1},
    {"zupdf_doc_dict",   (DL_FUNC) &zupdf_doc_dict,   3},
    {"zupdf_counts",     (DL_FUNC) &zupdf_counts,     1},
    {"zupdf_is_open",    (DL_FUNC) &zupdf_is_open,    1},
    {"zupdf_meta",       (DL_FUNC) &zupdf_meta,       1},
    {"zupdf_open",       (DL_FUNC) &zupdf_open,       3},
    {"zupdf_object",     (DL_FUNC) &zupdf_object,     3},
    {"zupdf_objects",    (DL_FUNC) &zupdf_objects,    1},
    {"zupdf_native_raster", (DL_FUNC) &zupdf_native_raster, 4},
    {"zupdf_page_text",  (DL_FUNC) &zupdf_page_text,  5},
    {"zupdf_page_tokens", (DL_FUNC) &zupdf_page_tokens, 3},
    {"zupdf_page_xobjects", (DL_FUNC) &zupdf_page_xobjects, 3},
    {"zupdf_pages",      (DL_FUNC) &zupdf_pages,      2},
    {"zupdf_stream",     (DL_FUNC) &zupdf_stream,     4},
    {"zupdf_value_roundtrip", (DL_FUNC) &zupdf_value_roundtrip, 2},
    {"zupdf_writer_copy_pages", (DL_FUNC) &zupdf_writer_copy_pages, 5},
    {"zupdf_writer_font", (DL_FUNC) &zupdf_writer_font, 3},
    {"zupdf_writer_image_data", (DL_FUNC) &zupdf_writer_image_data, 7},
    {"zupdf_writer_image_file", (DL_FUNC) &zupdf_writer_image_file, 3},
    {"zupdf_writer_is_open", (DL_FUNC) &zupdf_writer_is_open, 1},
    {"zupdf_writer_new", (DL_FUNC) &zupdf_writer_new, 2},
    {"zupdf_writer_page", (DL_FUNC) &zupdf_writer_page, 8},
    {"zupdf_writer_save", (DL_FUNC) &zupdf_writer_save, 3},
    {"zupdf_writer_set_encryption", (DL_FUNC) &zupdf_writer_set_encryption, 5},
    {"zupdf_writer_set_meta", (DL_FUNC) &zupdf_writer_set_meta, 4},
    {NULL, NULL, 0}
};

void R_init_zupdf(DllInfo *dll);

/* The one exported symbol: $(C_VISIBILITY) in Makevars hides the rest. */
void attribute_visible R_init_zupdf(DllInfo *dll)
{
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
