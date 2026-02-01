/*
 * lru.c - Ultra-fast LRU cache with O(1) operations
 * 
 * Optimizations:
 * 1. Custom open-addressing hash table (no Perl HV overhead)
 * 2. Zero-copy returns where possible
 * 3. Custom ops for get/set bypass method dispatch
 * 4. Inline key comparison
 * 5. Power-of-2 bucket sizing for fast modulo
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "lru_compat.h"

/* ============================================
   Hash table entry (combines node + bucket)
   ============================================ */
typedef struct lru_entry {
    struct lru_entry *prev;      /* LRU list prev */
    struct lru_entry *next;      /* LRU list next */
    struct lru_entry *hash_next; /* Hash chain next */
    SV *key;
    SV *value;
    U32 hash;                    /* Cached hash value */
} LRUEntry;

/* ============================================
   LRU cache structure
   ============================================ */
typedef struct {
    LRUEntry **buckets;     /* Hash buckets (power of 2) */
    LRUEntry *head;         /* Most recently used */
    LRUEntry *tail;         /* Least recently used */
    IV capacity;            /* Max entries */
    IV size;                /* Current entries */
    IV bucket_count;        /* Number of buckets (power of 2) */
    IV bucket_mask;         /* bucket_count - 1 for fast modulo */
} LRUCache;

/* ============================================
   Custom ops
   ============================================ */
static XOP lru_get_xop;
static XOP lru_set_xop;
static XOP lru_exists_xop;
static XOP lru_peek_xop;
static XOP lru_delete_xop;

/* Function-style custom ops */
static XOP lru_func_get_xop;
static XOP lru_func_set_xop;
static XOP lru_func_exists_xop;
static XOP lru_func_peek_xop;
static XOP lru_func_delete_xop;

/* ============================================
   Magic vtable
   ============================================ */
static int lru_cache_free(pTHX_ SV *sv, MAGIC *mg);

static MGVTBL lru_cache_vtbl = {
    NULL, NULL, NULL, NULL,
    lru_cache_free,
    NULL, NULL, NULL
};

/* ============================================
   Fast hash function (FNV-1a)
   ============================================ */
static U32 lru_hash(const char *str, STRLEN len) {
    U32 hash = 2166136261U;
    while (len--) {
        hash ^= (U32)*str++;
        hash *= 16777619U;
    }
    return hash;
}

/* ============================================
   Get LRUCache from blessed SV
   ============================================ */
static LRUCache* get_lru_cache(pTHX_ SV *obj) {
    MAGIC *mg;
    if (!SvROK(obj)) croak("Not a reference");
    mg = mg_find(SvRV(obj), PERL_MAGIC_ext);
    while (mg) {
        if (mg->mg_virtual == &lru_cache_vtbl) {
            return (LRUCache*)mg->mg_ptr;
        }
        mg = mg->mg_moremagic;
    }
    croak("Not an lru cache object");
    return NULL;
}

/* ============================================
   Entry management
   ============================================ */

static LRUEntry* entry_new(pTHX_ SV *key, SV *value, U32 hash) {
    LRUEntry *e;
    Newxz(e, 1, LRUEntry);
    e->key = newSVsv(key);
    e->value = newSVsv(value);
    e->hash = hash;
    return e;
}

static void entry_free(pTHX_ LRUEntry *e) {
    if (e->key) SvREFCNT_dec(e->key);
    if (e->value) SvREFCNT_dec(e->value);
    Safefree(e);
}

/* ============================================
   LRU list operations (O(1))
   ============================================ */

static void lru_unlink(LRUCache *c, LRUEntry *e) {
    if (e->prev) e->prev->next = e->next;
    else c->head = e->next;
    if (e->next) e->next->prev = e->prev;
    else c->tail = e->prev;
    e->prev = e->next = NULL;
}

static void lru_push_front(LRUCache *c, LRUEntry *e) {
    e->prev = NULL;
    e->next = c->head;
    if (c->head) c->head->prev = e;
    c->head = e;
    if (!c->tail) c->tail = e;
}

static void lru_promote(LRUCache *c, LRUEntry *e) {
    if (e == c->head) return;
    lru_unlink(c, e);
    lru_push_front(c, e);
}

/* ============================================
   Hash table operations (O(1) average)
   ============================================ */

/* Find entry by key - returns NULL if not found */
static LRUEntry* hash_find(LRUCache *c, const char *kpv, STRLEN klen, U32 hash) {
    LRUEntry *e = c->buckets[hash & c->bucket_mask];
    while (e) {
        if (e->hash == hash) {
            STRLEN elen;
            const char *epv = SvPV(e->key, elen);
            if (elen == klen && memcmp(epv, kpv, klen) == 0) {
                return e;
            }
        }
        e = e->hash_next;
    }
    return NULL;
}

/* Insert entry into hash table */
static void hash_insert(LRUCache *c, LRUEntry *e) {
    IV idx = e->hash & c->bucket_mask;
    e->hash_next = c->buckets[idx];
    c->buckets[idx] = e;
}

/* Remove entry from hash table */
static void hash_remove(LRUCache *c, LRUEntry *e) {
    IV idx = e->hash & c->bucket_mask;
    LRUEntry **pp = &c->buckets[idx];
    while (*pp) {
        if (*pp == e) {
            *pp = e->hash_next;
            e->hash_next = NULL;
            return;
        }
        pp = &(*pp)->hash_next;
    }
}

/* ============================================
   Eviction
   ============================================ */

static void lru_evict(pTHX_ LRUCache *c) {
    LRUEntry *victim = c->tail;
    if (!victim) return;
    
    lru_unlink(c, victim);
    hash_remove(c, victim);
    entry_free(aTHX_ victim);
    c->size--;
}

/* ============================================
   Core get/set (used by both XS and custom ops)
   ============================================ */

/* Returns SV* directly (no copy) - caller must mortalcopy if needed */
static SV* lru_get_internal(pTHX_ LRUCache *c, const char *kpv, STRLEN klen, bool promote) {
    U32 hash = lru_hash(kpv, klen);
    LRUEntry *e = hash_find(c, kpv, klen, hash);
    if (e) {
        if (promote) lru_promote(c, e);
        return e->value;
    }
    return NULL;
}

static void lru_set_internal(pTHX_ LRUCache *c, const char *kpv, STRLEN klen, SV *value) {
    U32 hash = lru_hash(kpv, klen);
    LRUEntry *e = hash_find(c, kpv, klen, hash);
    
    if (e) {
        /* Update existing */
        SvREFCNT_dec(e->value);
        e->value = newSVsv(value);
        lru_promote(c, e);
    } else {
        /* Evict if needed */
        while (c->size >= c->capacity) {
            lru_evict(aTHX_ c);
        }
        
        /* Create new entry */
        SV *keysv = newSVpvn(kpv, klen);
        e = entry_new(aTHX_ keysv, value, hash);
        SvREFCNT_dec(keysv);
        
        hash_insert(c, e);
        lru_push_front(c, e);
        c->size++;
    }
}

static bool lru_exists_internal(LRUCache *c, const char *kpv, STRLEN klen) {
    U32 hash = lru_hash(kpv, klen);
    return hash_find(c, kpv, klen, hash) != NULL;
}

/* ============================================
   Custom op implementations
   ============================================ */

/* pp_lru_get: stack has (cache, key) */
static OP* pp_lru_get(pTHX) {
    dSP;
    SV *key_sv = POPs;
    SV *cache_sv = POPs;
    LRUCache *c = get_lru_cache(aTHX_ cache_sv);
    STRLEN klen;
    const char *kpv = SvPV(key_sv, klen);
    SV *val = lru_get_internal(aTHX_ c, kpv, klen, TRUE);
    
    if (val) {
        PUSHs(val);  /* Zero-copy! Caller sees actual value */
    } else {
        PUSHs(&PL_sv_undef);
    }
    RETURN;
}

/* pp_lru_set: stack has (cache, key, value) */
static OP* pp_lru_set(pTHX) {
    dSP;
    SV *value = POPs;
    SV *key_sv = POPs;
    SV *cache_sv = POPs;
    LRUCache *c = get_lru_cache(aTHX_ cache_sv);
    STRLEN klen;
    const char *kpv = SvPV(key_sv, klen);
    
    lru_set_internal(aTHX_ c, kpv, klen, value);
    RETURN;
}

/* pp_lru_exists: stack has (cache, key) */
static OP* pp_lru_exists(pTHX) {
    dSP;
    SV *key_sv = POPs;
    SV *cache_sv = POPs;
    LRUCache *c = get_lru_cache(aTHX_ cache_sv);
    STRLEN klen;
    const char *kpv = SvPV(key_sv, klen);
    
    if (lru_exists_internal(c, kpv, klen)) {
        PUSHs(&PL_sv_yes);
    } else {
        PUSHs(&PL_sv_no);
    }
    RETURN;
}

/* ============================================
   Function-style custom ops (fastest path)
   lru_get($cache, $key)
   lru_set($cache, $key, $value)
   ============================================ */

/* pp_lru_func_get: stack has (cache, key) - optimized */
static OP* pp_lru_func_get(pTHX) {
    dSP;
    SV *key_sv = TOPs;       /* peek key */
    SV *cache_sv = TOPm1s;   /* peek cache */
    LRUCache *c = get_lru_cache(aTHX_ cache_sv);
    STRLEN klen;
    const char *kpv = SvPV(key_sv, klen);
    SV *val = lru_get_internal(aTHX_ c, kpv, klen, TRUE);
    
    SP--;  /* pop key */
    SETs(val ? val : &PL_sv_undef);  /* replace cache with result */
    RETURN;
}

/* pp_lru_func_set: stack has (cache, key, value) - optimized */
static OP* pp_lru_func_set(pTHX) {
    dSP;
    SV *value = TOPs;
    SV *key_sv = TOPm1s;
    SV *cache_sv = *(SP - 2);
    LRUCache *c = get_lru_cache(aTHX_ cache_sv);
    STRLEN klen;
    const char *kpv = SvPV(key_sv, klen);
    
    lru_set_internal(aTHX_ c, kpv, klen, value);
    
    *(SP - 2) = value;  /* return value */
    SP -= 2;
    RETURN;
}

/* pp_lru_func_exists: stack has (cache, key) - optimized */
static OP* pp_lru_func_exists(pTHX) {
    dSP;
    SV *key_sv = TOPs;
    SV *cache_sv = TOPm1s;
    LRUCache *c = get_lru_cache(aTHX_ cache_sv);
    STRLEN klen;
    const char *kpv = SvPV(key_sv, klen);
    
    SP--;
    SETs(lru_exists_internal(c, kpv, klen) ? &PL_sv_yes : &PL_sv_no);
    RETURN;
}

/* pp_lru_func_peek: stack has (cache, key) - optimized */
static OP* pp_lru_func_peek(pTHX) {
    dSP;
    SV *key_sv = TOPs;
    SV *cache_sv = TOPm1s;
    LRUCache *c = get_lru_cache(aTHX_ cache_sv);
    STRLEN klen;
    const char *kpv = SvPV(key_sv, klen);
    SV *val = lru_get_internal(aTHX_ c, kpv, klen, FALSE);
    
    SP--;
    SETs(val ? val : &PL_sv_undef);
    RETURN;
}

/* pp_lru_func_delete: stack has (cache, key) - optimized */
static OP* pp_lru_func_delete(pTHX) {
    dSP;
    SV *key_sv = TOPs;
    SV *cache_sv = TOPm1s;
    LRUCache *c = get_lru_cache(aTHX_ cache_sv);
    STRLEN klen;
    const char *kpv = SvPV(key_sv, klen);
    U32 hash = lru_hash(kpv, klen);
    LRUEntry *e = hash_find(c, kpv, klen, hash);
    
    SP--;
    if (e) {
        SV *val = sv_mortalcopy(e->value);
        lru_unlink(c, e);
        hash_remove(c, e);
        entry_free(aTHX_ e);
        c->size--;
        SETs(val);
    } else {
        SETs(&PL_sv_undef);
    }
    RETURN;
}

/* ============================================
   Call checker for function-style ops
   Replaces entersub with custom op for maximum speed.
   ============================================ */

typedef OP* (*lru_ppfunc)(pTHX);

/* 
 * Check if an op is accessing $_ (the default variable).
 * This indicates we're likely in map/grep context where custom ops
 * don't work correctly due to how the op tree is evaluated.
 */
static bool lru_op_is_dollar_underscore(pTHX_ OP *op) {
    if (!op) return FALSE;
    
    /* Check for $_ access: rv2sv -> gv for "_" */
    if (op->op_type == OP_RV2SV) {
        OP *gvop = cUNOPx(op)->op_first;
        if (gvop && gvop->op_type == OP_GV) {
            GV *gv = cGVOPx_gv(gvop);
            if (gv && GvNAMELEN(gv) == 1 && GvNAME(gv)[0] == '_') {
                return TRUE;
            }
        }
    }
    
    return FALSE;
}

/* 
 * Call checker for 2-arg functions: lru_exists($cache, $key), etc.
 * Uses newBINOP like object.c does for 2-arg calls.
 */
static OP* lru_func_call_checker_2arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    lru_ppfunc ppfunc = (lru_ppfunc)SvIVX(ckobj);
    OP *pushop, *cvop, *cacheop, *keyop;
    OP *newop;

    PERL_UNUSED_ARG(namegv);

    /* Navigate to first child */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* Get the args: pushmark -> cache -> key -> cv */
    cacheop = OpSIBLING(pushop);
    if (!cacheop) return entersubop;
    
    keyop = OpSIBLING(cacheop);
    if (!keyop) return entersubop;
    
    cvop = OpSIBLING(keyop);
    if (!cvop) return entersubop;
    
    /* Verify exactly 2 args (keyop's sibling is cvop) */
    if (OpSIBLING(keyop) != cvop) return entersubop;

    /* If either arg is $_, fall back to XS (map/grep context) */
    if (lru_op_is_dollar_underscore(aTHX_ cacheop) ||
        lru_op_is_dollar_underscore(aTHX_ keyop)) {
        return entersubop;
    }

    /* Detach cache and key from the entersub tree */
    OpMORESIB_set(pushop, cvop);
    OpLASTSIB_set(keyop, NULL);
    OpLASTSIB_set(cacheop, NULL);

    /* Create binary custom op with cache and key as children */
    newop = newBINOP(OP_CUSTOM, 0, cacheop, keyop);
    newop->op_ppaddr = ppfunc;

    op_free(entersubop);
    return newop;
}

/* 
 * Call checker for 3-arg functions: lru_set($cache, $key, $value)
 * Uses nested BINOPs: BINOP(BINOP(cache, key), value)
 * The inner BINOP executes cache+key pushing to stack,
 * then outer BINOP executes value, then runs pp_lru_func_set.
 */
static OP* lru_func_call_checker_3arg(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    lru_ppfunc ppfunc = (lru_ppfunc)SvIVX(ckobj);
    OP *pushop, *cvop, *cacheop, *keyop, *valop;
    OP *innerop, *newop;

    PERL_UNUSED_ARG(namegv);

    /* Navigate to first child */
    pushop = cUNOPx(entersubop)->op_first;
    if (!OpHAS_SIBLING(pushop)) {
        pushop = cUNOPx(pushop)->op_first;
    }

    /* Get the args: pushmark -> cache -> key -> value -> cv */
    cacheop = OpSIBLING(pushop);
    if (!cacheop) return entersubop;
    
    keyop = OpSIBLING(cacheop);
    if (!keyop) return entersubop;
    
    valop = OpSIBLING(keyop);
    if (!valop) return entersubop;
    
    cvop = OpSIBLING(valop);
    if (!cvop) return entersubop;
    
    /* Verify exactly 3 args (valop's sibling is cvop) */
    if (OpSIBLING(valop) != cvop) return entersubop;

    /* If any arg is $_, fall back to XS (map/grep context) */
    if (lru_op_is_dollar_underscore(aTHX_ cacheop) ||
        lru_op_is_dollar_underscore(aTHX_ keyop) ||
        lru_op_is_dollar_underscore(aTHX_ valop)) {
        return entersubop;
    }

    /* Detach args from the entersub tree */
    OpMORESIB_set(pushop, cvop);
    
    /* Prepare individual ops */
    OpLASTSIB_set(cacheop, NULL);
    OpLASTSIB_set(keyop, NULL);
    OpLASTSIB_set(valop, NULL);

    /* Create inner BINOP for cache+key (just passthrough to stack) */
    innerop = newBINOP(OP_NULL, 0, cacheop, keyop);
    
    /* Create outer BINOP with inner as first, value as second */
    newop = newBINOP(OP_CUSTOM, 0, innerop, valop);
    newop->op_ppaddr = ppfunc;

    op_free(entersubop);
    return newop;
}

/* No-op call checker fallback - uses XS path */
static OP* lru_func_call_checker(pTHX_ OP *entersubop, GV *namegv, SV *ckobj) {
    PERL_UNUSED_ARG(namegv);
    PERL_UNUSED_ARG(ckobj);
    return entersubop;  /* Use XS fallback */
}

/* ============================================
   Install function-style accessor with call checker
   ============================================ */

static void install_lru_func(pTHX_ const char *pkg, const char *name, 
                              XSUBADDR_t xsub, lru_ppfunc ppfunc) {
    char full_name[256];
    CV *cv;
    SV *ckobj;

    PERL_UNUSED_ARG(ppfunc);
    
    snprintf(full_name, sizeof(full_name), "%s::%s", pkg, name);
    cv = newXS(full_name, xsub, __FILE__);
    
    /* XS fallback only - no custom op */
    ckobj = newSViv(PTR2IV(ppfunc));
    cv_set_call_checker(cv, lru_func_call_checker, ckobj);
}

/* Install with 2-arg custom op optimization */
static void install_lru_func_2arg(pTHX_ const char *pkg, const char *name, 
                                   XSUBADDR_t xsub, lru_ppfunc ppfunc) {
    char full_name[256];
    CV *cv;
    SV *ckobj;
    
    snprintf(full_name, sizeof(full_name), "%s::%s", pkg, name);
    cv = newXS(full_name, xsub, __FILE__);
    
    /* Use 2-arg call checker for custom op optimization */
    ckobj = newSViv(PTR2IV(ppfunc));
    cv_set_call_checker(cv, lru_func_call_checker_2arg, ckobj);
}

static void install_lru_func_3arg(pTHX_ const char *pkg, const char *name, 
                                   XSUBADDR_t xsub, lru_ppfunc ppfunc) {
    char full_name[256];
    CV *cv;
    SV *ckobj;
    
    snprintf(full_name, sizeof(full_name), "%s::%s", pkg, name);
    cv = newXS(full_name, xsub, __FILE__);
    
    /* Use 3-arg call checker for custom op optimization */
    ckobj = newSViv(PTR2IV(ppfunc));
    cv_set_call_checker(cv, lru_func_call_checker_3arg, ckobj);
}

XS_EXTERNAL(XS_lru_func_get) {
    dXSARGS;
    if (items != 2) croak("Usage: lru_get($cache, $key)");
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    SV *val = lru_get_internal(aTHX_ c, kpv, klen, TRUE);
    if (val) { ST(0) = val; XSRETURN(1); }
    XSRETURN_UNDEF;
}

XS_EXTERNAL(XS_lru_func_set) {
    dXSARGS;
    if (items != 3) croak("Usage: lru_set($cache, $key, $value)");
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    lru_set_internal(aTHX_ c, kpv, klen, ST(2));
    ST(0) = ST(2);
    XSRETURN(1);
}

XS_EXTERNAL(XS_lru_func_exists) {
    dXSARGS;
    if (items != 2) croak("Usage: lru_exists($cache, $key)");
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    if (lru_exists_internal(c, kpv, klen)) XSRETURN_YES;
    XSRETURN_NO;
}

XS_EXTERNAL(XS_lru_func_peek) {
    dXSARGS;
    if (items != 2) croak("Usage: lru_peek($cache, $key)");
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    SV *val = lru_get_internal(aTHX_ c, kpv, klen, FALSE);
    if (val) { ST(0) = val; XSRETURN(1); }
    XSRETURN_UNDEF;
}

XS_EXTERNAL(XS_lru_func_delete) {
    dXSARGS;
    if (items != 2) croak("Usage: lru_delete($cache, $key)");
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    U32 hash = lru_hash(kpv, klen);
    LRUEntry *e = hash_find(c, kpv, klen, hash);
    if (e) {
        SV *val = sv_mortalcopy(e->value);
        lru_unlink(c, e);
        hash_remove(c, e);
        entry_free(aTHX_ e);
        c->size--;
        ST(0) = val;
        XSRETURN(1);
    }
    XSRETURN_UNDEF;
}

/* lru::import - import function-style accessors */
XS_EXTERNAL(XS_lru_import) {
    dXSARGS;
    const char *pkg;
    int i;
    bool want_import = FALSE;

    /* Get caller's package */
    pkg = CopSTASHPV(PL_curcop);

    /* Check for 'import' in args */
    for (i = 1; i < items; i++) {
        STRLEN len;
        const char *arg = SvPV(ST(i), len);
        if (len == 6 && strEQ(arg, "import")) {
            want_import = TRUE;
        }
    }

    if (want_import) {
        /* All 2-arg functions use custom op optimization */
        install_lru_func_2arg(aTHX_ pkg, "lru_get", XS_lru_func_get, pp_lru_func_get);
        install_lru_func_2arg(aTHX_ pkg, "lru_exists", XS_lru_func_exists, pp_lru_func_exists);
        install_lru_func_2arg(aTHX_ pkg, "lru_peek", XS_lru_func_peek, pp_lru_func_peek);
        install_lru_func_2arg(aTHX_ pkg, "lru_delete", XS_lru_func_delete, pp_lru_func_delete);
        /* 3-arg function uses nested BINOP optimization */
        install_lru_func_3arg(aTHX_ pkg, "lru_set", XS_lru_func_set, pp_lru_func_set);
    }

    XSRETURN_EMPTY;
}

/* ============================================
   Destructor
   ============================================ */

static int lru_cache_free(pTHX_ SV *sv, MAGIC *mg) {
    LRUCache *c = (LRUCache*)mg->mg_ptr;
    LRUEntry *e = c->head;
    
    while (e) {
        LRUEntry *next = e->next;
        entry_free(aTHX_ e);
        e = next;
    }
    
    Safefree(c->buckets);
    Safefree(c);
    return 0;
}

/* ============================================
   Next power of 2
   ============================================ */
static IV next_pow2(IV n) {
    n--;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    n++;
    return n < 16 ? 16 : n;
}

/* ============================================
   XS Functions
   ============================================ */

/* lru::new($capacity) */
XS_EXTERNAL(XS_lru_new) {
    dXSARGS;
    LRUCache *c;
    SV *obj_sv, *rv;
    IV capacity;
    HV *stash;
    
    if (items < 1 || items > 2)
        croak("Usage: lru::new(capacity)");
    
    capacity = SvIV(items == 2 ? ST(1) : ST(0));
    if (capacity < 1) croak("Capacity must be positive");
    
    Newxz(c, 1, LRUCache);
    c->capacity = capacity;
    c->size = 0;
    c->bucket_count = next_pow2(capacity * 2);  /* Load factor ~0.5 */
    c->bucket_mask = c->bucket_count - 1;
    Newxz(c->buckets, c->bucket_count, LRUEntry*);
    c->head = c->tail = NULL;
    
    obj_sv = newSV(0);
    sv_magicext(obj_sv, NULL, PERL_MAGIC_ext, &lru_cache_vtbl, (char*)c, 0);
    
    rv = newRV_noinc(obj_sv);
    stash = gv_stashpvn("lru", 3, GV_ADD);
    sv_bless(rv, stash);
    
    ST(0) = rv;
    XSRETURN(1);
}

/* $cache->set($key, $value) */
XS_EXTERNAL(XS_lru_set) {
    dXSARGS;
    if (items != 3) croak("Usage: $cache->set($key, $value)");
    
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    lru_set_internal(aTHX_ c, kpv, klen, ST(2));
    XSRETURN_EMPTY;
}

/* $cache->get($key) */
XS_EXTERNAL(XS_lru_get) {
    dXSARGS;
    if (items != 2) croak("Usage: $cache->get($key)");
    
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    SV *val = lru_get_internal(aTHX_ c, kpv, klen, TRUE);
    
    if (val) {
        ST(0) = val;  /* Zero-copy return */
        XSRETURN(1);
    }
    XSRETURN_UNDEF;
}

/* $cache->peek($key) - get without promoting */
XS_EXTERNAL(XS_lru_peek) {
    dXSARGS;
    if (items != 2) croak("Usage: $cache->peek($key)");
    
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    SV *val = lru_get_internal(aTHX_ c, kpv, klen, FALSE);
    
    if (val) {
        ST(0) = val;
        XSRETURN(1);
    }
    XSRETURN_UNDEF;
}

/* $cache->exists($key) */
XS_EXTERNAL(XS_lru_exists) {
    dXSARGS;
    if (items != 2) croak("Usage: $cache->exists($key)");
    
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    
    if (lru_exists_internal(c, kpv, klen)) {
        XSRETURN_YES;
    }
    XSRETURN_NO;
}

/* $cache->delete($key) */
XS_EXTERNAL(XS_lru_delete) {
    dXSARGS;
    if (items != 2) croak("Usage: $cache->delete($key)");
    
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    STRLEN klen;
    const char *kpv = SvPV(ST(1), klen);
    U32 hash = lru_hash(kpv, klen);
    LRUEntry *e = hash_find(c, kpv, klen, hash);
    
    if (e) {
        SV *val = sv_mortalcopy(e->value);
        lru_unlink(c, e);
        hash_remove(c, e);
        entry_free(aTHX_ e);
        c->size--;
        ST(0) = val;
        XSRETURN(1);
    }
    XSRETURN_UNDEF;
}

/* $cache->size */
XS_EXTERNAL(XS_lru_size) {
    dXSARGS;
    if (items != 1) croak("Usage: $cache->size");
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    XSRETURN_IV(c->size);
}

/* $cache->capacity */
XS_EXTERNAL(XS_lru_capacity) {
    dXSARGS;
    if (items != 1) croak("Usage: $cache->capacity");
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    XSRETURN_IV(c->capacity);
}

/* $cache->clear */
XS_EXTERNAL(XS_lru_clear) {
    dXSARGS;
    if (items != 1) croak("Usage: $cache->clear");
    
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    LRUEntry *e = c->head;
    
    while (e) {
        LRUEntry *next = e->next;
        entry_free(aTHX_ e);
        e = next;
    }
    
    Zero(c->buckets, c->bucket_count, LRUEntry*);
    c->head = c->tail = NULL;
    c->size = 0;
    
    XSRETURN_EMPTY;
}

/* $cache->keys */
XS_EXTERNAL(XS_lru_keys) {
    dXSARGS;
    if (items != 1) croak("Usage: $cache->keys");
    SP -= items;
    
    LRUCache *c = get_lru_cache(aTHX_ ST(0));
    EXTEND(SP, c->size);
    
    LRUEntry *e = c->head;
    while (e) {
        PUSHs(e->key);  /* Zero-copy */
        e = e->next;
    }
    
    XSRETURN(c->size);
}

/* ============================================
   Boot function
   ============================================ */

XS_EXTERNAL(boot_lru) {
    dXSBOOTARGSXSAPIVERCHK;
    
    /* Register method-style custom ops */
    XopENTRY_set(&lru_get_xop, xop_name, "lru_get");
    XopENTRY_set(&lru_get_xop, xop_desc, "lru cache get");
    Perl_custom_op_register(aTHX_ pp_lru_get, &lru_get_xop);
    
    XopENTRY_set(&lru_set_xop, xop_name, "lru_set");
    XopENTRY_set(&lru_set_xop, xop_desc, "lru cache set");
    Perl_custom_op_register(aTHX_ pp_lru_set, &lru_set_xop);
    
    XopENTRY_set(&lru_exists_xop, xop_name, "lru_exists");
    XopENTRY_set(&lru_exists_xop, xop_desc, "lru cache exists");
    Perl_custom_op_register(aTHX_ pp_lru_exists, &lru_exists_xop);
    
    /* Register function-style custom ops */
    XopENTRY_set(&lru_func_get_xop, xop_name, "lru_func_get");
    XopENTRY_set(&lru_func_get_xop, xop_desc, "lru function get");
    Perl_custom_op_register(aTHX_ pp_lru_func_get, &lru_func_get_xop);
    
    XopENTRY_set(&lru_func_set_xop, xop_name, "lru_func_set");
    XopENTRY_set(&lru_func_set_xop, xop_desc, "lru function set");
    Perl_custom_op_register(aTHX_ pp_lru_func_set, &lru_func_set_xop);
    
    XopENTRY_set(&lru_func_exists_xop, xop_name, "lru_func_exists");
    XopENTRY_set(&lru_func_exists_xop, xop_desc, "lru function exists");
    Perl_custom_op_register(aTHX_ pp_lru_func_exists, &lru_func_exists_xop);
    
    XopENTRY_set(&lru_func_peek_xop, xop_name, "lru_func_peek");
    XopENTRY_set(&lru_func_peek_xop, xop_desc, "lru function peek");
    Perl_custom_op_register(aTHX_ pp_lru_func_peek, &lru_func_peek_xop);
    
    XopENTRY_set(&lru_func_delete_xop, xop_name, "lru_func_delete");
    XopENTRY_set(&lru_func_delete_xop, xop_desc, "lru function delete");
    Perl_custom_op_register(aTHX_ pp_lru_func_delete, &lru_func_delete_xop);
    
    /* Register XS subs */
    newXS("lru::new", XS_lru_new, __FILE__);
    newXS("lru::set", XS_lru_set, __FILE__);
    newXS("lru::get", XS_lru_get, __FILE__);
    newXS("lru::peek", XS_lru_peek, __FILE__);
    newXS("lru::exists", XS_lru_exists, __FILE__);
    newXS("lru::delete", XS_lru_delete, __FILE__);
    newXS("lru::size", XS_lru_size, __FILE__);
    newXS("lru::capacity", XS_lru_capacity, __FILE__);
    newXS("lru::clear", XS_lru_clear, __FILE__);
    newXS("lru::keys", XS_lru_keys, __FILE__);
    newXS("lru::import", XS_lru_import, __FILE__);
    
#if PERL_VERSION_GE(5,22,0)
    Perl_xs_boot_epilog(aTHX_ ax);
#else
    XSRETURN_YES;
#endif
}
