/*
 * util_export.h - C API for registering exports with util
 *
 * Include this header in your XS module to register functions that can be
 * imported via `use util qw(your_function)`.
 *
 * SYNOPSIS:
 *
 *   In your XS file:
 *
 *     #include "util_export.h"
 *
 *     static XS(xs_my_function) {
 *         dXSARGS;
 *         // ... implementation ...
 *         XSRETURN(1);
 *     }
 *
 *     BOOT:
 *         util_register_export_xs(aTHX_ "my_function", xs_my_function);
 *
 *   Then users can:
 *
 *     use util qw(my_function is_array);  # Import your function + util's
 *
 * NOTES:
 *
 *   - The util module must be loaded before calling util_register_export_xs
 *   - Function names must be unique; registering a duplicate will croak
 *   - Registered functions are available immediately after registration
 *   - Call checkers are not supported for externally registered functions
 *
 * PERL API:
 *
 *   util::register_export($name, \&coderef)  - Register a Perl coderef
 *   util::has_export($name)                   - Check if name is registered
 *   util::list_exports()                      - List all registered names
 *
 */

#ifndef UTIL_EXPORT_H
#define UTIL_EXPORT_H

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/*
 * Register an XS function as a util export.
 *
 * Parameters:
 *   name    - The export name (e.g., "my_function")
 *   xs_func - The XS function pointer (e.g., xs_my_function)
 *
 * Example:
 *   util_register_export_xs(aTHX_ "my_helper", xs_my_helper);
 *
 * After registration, users can import with:
 *   use util qw(my_helper);
 */
void util_register_export_xs(pTHX_ const char *name, XSUBADDR_t xs_func);

#endif /* UTIL_EXPORT_H */
