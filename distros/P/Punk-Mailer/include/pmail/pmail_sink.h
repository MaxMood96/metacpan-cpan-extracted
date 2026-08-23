#ifndef PMAIL_SINK_H
#define PMAIL_SINK_H

/* pmail_sink.h - where built bytes go.
 *
 * The builder never holds a message; it writes through a sink, chunk by
 * chunk, and the sink decides what that means: append to an SV (build),
 * write to a file descriptor (the sendmail pipe), call back into Perl
 * (build_to), count (a size the SMTP transport can announce), or stuff
 * leading dots and pass through (the SMTP DATA phase). A sink returns 0 on
 * success and -1 on failure, with errno set when the failure was a
 * syscall's; the builder stops at the first -1. */

typedef struct pmail_sink pmail_sink;
struct pmail_sink {
    int (*write)(pmail_sink *s, const char *p, size_t n);
    void *ud;
    void *ud2;
};

#ifdef PERL_IMPLICIT_CONTEXT
#  define PMAIL_SINK_THX(s)     PerlInterpreter *my_perl = (PerlInterpreter *)(s)->ud2
#  define PMAIL_SINK_SET_THX(s) ((s)->ud2 = (void *)aTHX)
#else
#  define PMAIL_SINK_THX(s)     ((void)0)
#  define PMAIL_SINK_SET_THX(s) ((s)->ud2 = NULL)
#endif

static int pmail_put(pmail_sink *s, const char *p, size_t n)
{
    return n ? s->write(s, p, n) : 0;
}

#define PMAIL_PUTS(s, lit) pmail_put((s), (lit), sizeof(lit) - 1)

/* ---- append to an SV ------------------------------------------------- */

static int pmail_sink_sv_write(pmail_sink *s, const char *p, size_t n)
{
    PMAIL_SINK_THX(s);
    sv_catpvn((SV *)s->ud, p, n);
    return 0;
}

static void pmail_sink_sv(pTHX_ pmail_sink *s, SV *sv)
{
    s->write = pmail_sink_sv_write;
    s->ud = sv;
    PMAIL_SINK_SET_THX(s);
}

/* ---- count ----------------------------------------------------------- */

static int pmail_sink_count_write(pmail_sink *s, const char *p, size_t n)
{
    (void)p;
    *(pmail_u64 *)s->ud += (pmail_u64)n;
    return 0;
}

static void pmail_sink_count(pmail_sink *s, pmail_u64 *total)
{
    s->write = pmail_sink_count_write;
    s->ud = total;
    s->ud2 = NULL;
}

/* ---- a file descriptor ---------------------------------------------- */

static int pmail_sink_fd_write(pmail_sink *s, const char *p, size_t n)
{
    int fd = (int)PTR2IV(s->ud);
    while (n) {
        ssize_t w = write(fd, p, n);
        if (w < 0) { if (errno == EINTR) continue; return -1; }
        if (w == 0) { errno = EIO; return -1; }
        p += w; n -= (size_t)w;
    }
    return 0;
}

static void pmail_sink_fd(pmail_sink *s, int fd)
{
    s->write = pmail_sink_fd_write;
    s->ud = INT2PTR(void *, (IV)fd);
    s->ud2 = NULL;
}

/* ---- a Perl callback ------------------------------------------------- */

static int pmail_sink_cv_write(pmail_sink *s, const char *p, size_t n)
{
    PMAIL_SINK_THX(s);
    dSP;
    ENTER; SAVETMPS;
    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVpvn(p, n)));
    PUTBACK;
    call_sv((SV *)s->ud, G_VOID | G_DISCARD);
    FREETMPS; LEAVE;
    return 0;
}

static void pmail_sink_cv(pTHX_ pmail_sink *s, SV *code)
{
    s->write = pmail_sink_cv_write;
    s->ud = code;
    PMAIL_SINK_SET_THX(s);
}

/* ---- SMTP dot-stuffing, wrapping another sink -------------------------
 * A line that begins with "." gets a second one (RFC 5321 4.5.2), so the
 * server cannot mistake it for the end of DATA. The one-byte state is
 * "at the start of a line", carried across chunks: a chunk ending in
 * "\r\n" followed by one starting with "." must stuff, and the naive
 * per-chunk scan misses exactly that. */

typedef struct { pmail_sink *inner; int at_line_start; } pmail_dotstuff;

static int pmail_sink_dot_write(pmail_sink *s, const char *p, size_t n)
{
    pmail_dotstuff *st = (pmail_dotstuff *)s->ud;
    size_t i, start = 0;
    for (i = 0; i < n; i++) {
        if (st->at_line_start && p[i] == '.') {
            if (pmail_put(st->inner, p + start, i - start) != 0) return -1;
            if (pmail_put(st->inner, ".", 1) != 0) return -1;
            start = i;      /* the original dot goes out with the next run */
        }
        st->at_line_start = (p[i] == '\n');
    }
    return pmail_put(st->inner, p + start, n - start);
}

static void pmail_sink_dotstuff(pmail_sink *s, pmail_dotstuff *st, pmail_sink *inner)
{
    st->inner = inner;
    st->at_line_start = 1;
    s->write = pmail_sink_dot_write;
    s->ud = st;
    s->ud2 = NULL;
}

#endif /* PMAIL_SINK_H */
