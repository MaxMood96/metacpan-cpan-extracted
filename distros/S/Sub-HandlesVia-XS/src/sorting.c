typedef struct {
#ifdef USE_ITHREADS
    PerlInterpreter *my_perl;
#endif
    CV *callback; // can be NULL
    SV *err;
} sort_ctx_t;

static int
shvxs_sort_cmp(const void *a, const void *b, void *ctx)
{
    sort_ctx_t *c = (sort_ctx_t *)ctx;
#ifdef USE_ITHREADS
    dTHXa(c->my_perl);
#endif

    if (c->err) return 0;

    SV *sv_a = *(SV * const *)a;
    SV *sv_b = *(SV * const *)b;

    if (!c->callback) {
        /* default string comparison */
        return sv_cmp(sv_a, sv_b);
    }

    int result = 0;
    
    dSP;
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 2);
    XPUSHs(sv_a);
    XPUSHs(sv_b);
    PUTBACK;

    I32 count = call_sv((SV *)c->callback, G_SCALAR | G_EVAL);
    SPAGAIN;

    if (SvTRUE(ERRSV)) {
        c->err = newSVsv(ERRSV);
        sv_setsv(ERRSV, &PL_sv_undef);
        PUTBACK;
        FREETMPS;
        LEAVE;
        return 0;
    }

    SV *ret = (count > 0) ? POPs : &PL_sv_undef;
    if (!SvOK(ret)) {
        result = 0;
    }
    else {
        result = (int)SvIV(ret);
    }

    PUTBACK;
    FREETMPS;
    LEAVE;

    return result;
}

#if defined(_WIN32)

static int __cdecl
shvxs_sort_cmp_win32(void *ctx, const void *a, const void *b) {
    sort_ctx_t *c = (sort_ctx_t *)ctx;
    return shvxs_sort_cmp(a, b, ctx);
}

#define SHVXS_QSORT(base, n, size, ctx) qsort_s((base), (n), (size), shvxs_sort_cmp_win32, (ctx))

#elif defined(__APPLE__) || defined(__FreeBSD__)

static int
shvxs_sort_cmp_bsd(void *ctx, const void *a, const void *b) {
    sort_ctx_t *c = (sort_ctx_t *)ctx;
    return shvxs_sort_cmp(a, b, ctx);
}

#define SHVXS_QSORT(base, n, size, ctx) qsort_r((base), (n), (size), (ctx), shvxs_sort_cmp_bsd)

#else

#define SHVXS_QSORT(base, n, size, ctx) qsort_r((base), (n), (size), shvxs_sort_cmp, (ctx))

#endif
