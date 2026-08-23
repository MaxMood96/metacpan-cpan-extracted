#ifndef PTOTP_RAND_H
#define PTOTP_RAND_H

#include <stddef.h>
#include <stdio.h>

#ifdef PTOTP_HAVE_GETENTROPY
#include <unistd.h>
#ifdef PTOTP_HAVE_SYS_RANDOM_H
#include <sys/random.h>   /* where getentropy is declared on macOS and glibc */
#endif
#endif

/* ptotp_rand.h - the entropy behind secret generation, which is the
 * one place in this dist where randomness quality is the whole point.
 * getentropy when the configure probe LINKED it (compile-only probes
 * are a recorded CPAN Testers failure), /dev/urandom otherwise, and
 * failure returns -1 for the caller to croak on: a TOTP secret from a
 * degraded source is worse than no secret. */

static int ptotp_random_bytes(unsigned char *out, size_t n)
{
#ifdef PTOTP_HAVE_GETENTROPY
    size_t off = 0;
    while (off < n) {
        size_t take = n - off > 256 ? 256 : n - off;
        if (getentropy(out + off, take) != 0)
            return -1;
        off += take;
    }
    return 0;
#else
    FILE *f = fopen("/dev/urandom", "rb");
    size_t got;
    if (!f)
        return -1;
    got = fread(out, 1, n, f);
    fclose(f);
    return got == n ? 0 : -1;
#endif
}

#endif /* PTOTP_RAND_H */
