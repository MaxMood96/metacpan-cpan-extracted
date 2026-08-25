/* stencil_expfix.h - two-digit exponents everywhere.
 *
 * C99 prints at least two exponent digits (1.5e+03); the Windows CRT prints
 * three (1.5e+003), and the fmt filter's float path goes through that CRT
 * on purpose (see stencil_filters.c). Dropping the leading zero of a
 * three-digit exponent gives the same bytes on every platform; a real
 * three-digit exponent (1e+100) has no leading zero and is kept. Perl-free
 * so it can be unit-tested on its own.
 */
#ifndef STENCIL_EXPFIX_H
#define STENCIL_EXPFIX_H

#include <string.h>

/* s is NUL-terminated with len bytes before the NUL; returns the new len. */
static int stencil_expfix(char *s, int len)
{
    int i;
    for (i = 0; i + 4 < len; i++) {
        if ((s[i] == 'e' || s[i] == 'E')
            && (s[i + 1] == '+' || s[i + 1] == '-')
            && s[i + 2] == '0'
            && s[i + 3] >= '0' && s[i + 3] <= '9'
            && s[i + 4] >= '0' && s[i + 4] <= '9') {
            memmove(s + i + 2, s + i + 3, (size_t)(len - (i + 3)) + 1);
            len--;
        }
    }
    return len;
}

#endif /* STENCIL_EXPFIX_H */
