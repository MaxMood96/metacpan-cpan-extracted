typedef struct {
#ifdef USE_ITHREADS
    pTHX;
#endif
    CV *callback; // can be NULL
} sort_ctx_t;

static int
shvxs_sort_cmp(const void *a, const void *b, void *ctx)
{
    sort_ctx_t *c = (sort_ctx_t *)ctx;
#ifdef USE_ITHREADS
    dTHXa(c->aTHX);
#endif

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
    XPUSHs(sv_a);
    XPUSHs(sv_b);
    PUTBACK;

    I32 count = call_sv((SV *)c->callback, G_SCALAR);
    SPAGAIN;

    if ( count > 0 ) {
        result = (int)SvIV(POPs);
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
    return shvxs_sort_cmp(c, a, b);
}

#define SHVXS_QSORT(base, n, size, ctx) qsort_s((base), (n), (size), shvxs_sort_cmp_win32, (ctx))

#elif defined(__APPLE__) || defined(__FreeBSD__)

static int
shvxs_sort_cmp_bsd(void *ctx, const void *a, const void *b) {
    sort_ctx_t *c = (sort_ctx_t *)ctx;
    return xs_sort_cmp(c, a, b);
}

#define SHVXS_QSORT(base, n, size, ctx) qsort_r((base), (n), (size), (ctx), shvxs_sort_cmp_bsd)

#else

#define SHVXS_QSORT(base, n, size, ctx) qsort_r((base), (n), (size), shvxs_sort_cmp, (ctx))

#endif
