#include "zpd_r.h"

#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

/* Every .Call entry point is listed here; R_useDynamicSymbols(dll, FALSE)
   makes anything missing from the table unreachable by name. */
static const R_CallMethodDef CallEntries[] = {
    {"zupdf_build_info", (DL_FUNC) &zupdf_build_info, 0},
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
