#ifndef PMAIL_RAND_H
#define PMAIL_RAND_H

/* pmail_rand.h - entropy for MIME boundaries and Message-IDs.
 *
 * getentropy when the configure probe LINKED it (a compile-only probe is a
 * recorded CPAN Testers failure), /dev/urandom otherwise. Failure is -1
 * for the caller to croak on: a boundary that a body could predict, or a
 * Message-ID two messages share, is worse than no message.
 *
 * getentropy costs the same ~700ns for 16 bytes as for its 256-byte
 * maximum, so one call fills a pool that the next sixteen boundaries draw
 * from. The pool is keyed to the pid: a forked queue worker that inherited
 * its parent's pool would otherwise hand out the parent's next boundary,
 * and two workers would share one. */

#ifdef PMAIL_HAVE_GETENTROPY
#  ifdef PMAIL_GETENTROPY_SYS_RANDOM
#    include <sys/random.h>
#  else
#    include <unistd.h>
#  endif
#endif

static int pmail_rand_fill(unsigned char *out, size_t n)
{
#ifdef PMAIL_HAVE_GETENTROPY
    size_t off = 0;
    while (off < n) {
        size_t take = n - off > 256 ? 256 : n - off;
        if (getentropy(out + off, take) != 0) return -1;
        off += take;
    }
    return 0;
#else
    FILE *f = fopen("/dev/urandom", "rb");
    size_t got;
    if (!f) return -1;
    got = fread(out, 1, n, f);
    fclose(f);
    return got == n ? 0 : -1;
#endif
}

static int pmail_random_bytes(unsigned char *out, size_t n)
{
    static unsigned char pool[256];
    static size_t have = 0;
    static pid_t owner = 0;
    pid_t me = getpid();

    if (owner != me) { have = 0; owner = me; }
    while (n) {
        size_t take;
        if (!have) {
            if (pmail_rand_fill(pool, sizeof pool) != 0) return -1;
            have = sizeof pool;
        }
        take = n < have ? n : have;
        memcpy(out, pool + (sizeof pool - have), take);
        have -= take; out += take; n -= take;
    }
    return 0;
}

/* `chars` characters of the base64url alphabet - the one alphabet that
 * base64 output never contains a member of (`_`, `-`) and quoted-printable
 * never emits, which is what makes a boundary built from it safe. Six bits
 * of entropy per character. -1 when entropy is unavailable. */
static int pmail_random_token(char *out, size_t chars)
{
    static const char alphabet[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    unsigned char raw[64];
    size_t i;
    if (chars > sizeof raw) chars = sizeof raw;
    if (pmail_random_bytes(raw, chars) != 0) return -1;
    for (i = 0; i < chars; i++) out[i] = alphabet[raw[i] & 63];
    out[chars] = 0;
    return 0;
}

#endif /* PMAIL_RAND_H */
