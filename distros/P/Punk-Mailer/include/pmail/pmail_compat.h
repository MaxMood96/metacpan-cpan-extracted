#ifndef PMAIL_COMPAT_H
#define PMAIL_COMPAT_H

/* pmail_compat.h - the system headers every other pmail header needs, and
 * the few portability guards. Nothing here is Perl-specific except the
 * 64-bit size type. */

#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>

/* Message and attachment sizes. Never IV: on the 32-bit smokers an IV is
 * 32 bits and a file can be larger than that. unsigned long long is C99
 * and every compiler on the matrix, including the FreeBSD 9 gcc 4.2, has
 * it. Printed through %llu with an explicit cast. */
typedef unsigned long long pmail_u64;

#define PMAIL_CRLF "\r\n"

/* 7bit text may not carry a line over 998 bytes (RFC 5322 2.1.1) */
#define PMAIL_MAX_LINE 998

/* a header line folds at this width when it can (RFC 5322 2.1.1) */
#define PMAIL_FOLD_AT 78

#endif /* PMAIL_COMPAT_H */
