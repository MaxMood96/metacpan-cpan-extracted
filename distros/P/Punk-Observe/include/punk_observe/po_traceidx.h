/* po_traceidx.h - trace id to spans, in one probe.
 *
 * Trace ids are random 128-bit values. There is no locality to exploit, no
 * range to scan, and a sorted index would cost a binary search over a large
 * file with a cache miss at every level. The question is a POINT LOOKUP, so
 * the structure is a hash table.
 *
 * Open-addressed, power-of-two, linear probing, mmap'd straight out of the
 * segment. A lookup is one hash, one probe that is almost always the first
 * slot, and one read of the spans at that offset. The whole point is that
 * looking up a trace does not depend on how much data the tenant has.
 *
 * THE SLOT STORES THE FULL SIXTEEN BYTES.
 *
 * A 64-bit hash alone would collide, and the failure that produces is two
 * unrelated traces MERGED into one - a waterfall showing spans from somebody
 * else's request. That is the most confusing thing this system could do, and
 * nobody would ever guess at the cause. Sixteen bytes per slot is cheap
 * insurance against it.
 *
 * SIZED FROM THE DISTINCT TRACE COUNT, NOT THE SPAN COUNT. A segment with a
 * million spans across ten thousand traces needs ten thousand slots. Sizing
 * from the span count would waste 99% of the table; sizing from a guess would
 * make every probe a scan.
 */
#ifndef PO_TRACEIDX_H
#define PO_TRACEIDX_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_span.h"

/* 32 bytes: the id, where its spans start, and how many. */
typedef struct {
    po_u64   trace_hi, trace_lo;
    uint32_t first;      /* ordinal of the first span of this trace */
    uint32_t count;
    uint32_t flags;
    uint32_t pad;
} po_tslot;

#define PO_TSLOT_SIZE 32
#define PO_TIDX_LOAD  2      /* slots = distinct * 2, so load factor 0.5 */

typedef struct {
    po_tslot *slot;
    uint32_t  slots, mask;
    uint32_t  n;
    po_u64    probes;      /* total probes performed, for the measurement */
    po_u64    lookups;
} po_traceidx;

/* The hash. The id is already random, so this only needs to mix the two
 * halves; murmur's finaliser is right there and costs nothing. */
static uint32_t po_trace_hash(po_u64 hi, po_u64 lo) {
    return (uint32_t)(po_fmix64(hi ^ (lo * (po_u64)0x9E3779B97F4A7C15ULL)));
}

static int po_traceidx_init(po_traceidx *t, uint32_t distinct) {
    uint32_t slots = 16;
    memset(t, 0, sizeof(*t));
    while (slots < distinct * PO_TIDX_LOAD) slots <<= 1;
    t->slot = (po_tslot *)calloc(slots, sizeof(po_tslot));
    if (!t->slot) return 0;
    t->slots = slots;
    t->mask  = slots - 1;
    return 1;
}

static void po_traceidx_free(po_traceidx *t) {
    free(t->slot); t->slot = NULL; t->slots = t->n = 0;
}

static int po_tslot_empty(const po_tslot *s) {
    /* An all-zero trace id is invalid and is refused at ingest, so zero is a
     * safe empty marker rather than a value that could collide with a real
     * id. Phase 1 enforces that; this depends on it. */
    return s->trace_hi == 0 && s->trace_lo == 0;
}

static int po_traceidx_put(po_traceidx *t, po_u64 hi, po_u64 lo,
                           uint32_t first, uint32_t count) {
    uint32_t h = po_trace_hash(hi, lo) & t->mask;
    if (!po_trace_id_valid(hi, lo)) return 0;
    for (;;) {
        po_tslot *s = &t->slot[h];
        if (po_tslot_empty(s)) {
            s->trace_hi = hi; s->trace_lo = lo;
            s->first = first; s->count = count;
            t->n++;
            return 1;
        }
        if (s->trace_hi == hi && s->trace_lo == lo) {
            /* Same trace seen again in this segment: extend the run. Spans
             * are sorted by trace, so the run is contiguous. */
            s->count += count;
            return 1;
        }
        h = (h + 1) & t->mask;
    }
}

/* Returns 1 and fills first/count, or 0. Counts probes so a test can assert
 * the table is doing its job rather than degenerating into a scan. */
static int po_traceidx_get(po_traceidx *t, po_u64 hi, po_u64 lo,
                           uint32_t *first, uint32_t *count) {
    uint32_t h = po_trace_hash(hi, lo) & t->mask;
    uint32_t probed = 0;
    t->lookups++;
    for (;;) {
        po_tslot *s = &t->slot[h];
        probed++;
        if (po_tslot_empty(s)) { t->probes += probed; return 0; }
        /* The FULL comparison. A hash match is a probe hint, never proof. */
        if (s->trace_hi == hi && s->trace_lo == lo) {
            if (first) *first = s->first;
            if (count) *count = s->count;
            t->probes += probed;
            return 1;
        }
        h = (h + 1) & t->mask;
        if (probed > t->slots) { t->probes += probed; return 0; }
    }
}

/* Build the index from spans already sorted by (trace, start). Because they
 * are sorted, each trace is one contiguous run and the index is built in a
 * single pass with no counting phase. */
static int po_traceidx_build(po_traceidx *t, const po_span *s, uint32_t n) {
    uint32_t i = 0, distinct = 0;

    /* Count distinct traces first: the table is sized from THIS, not n. */
    while (i < n) {
        uint32_t j = i + 1;
        while (j < n && s[j].trace_hi == s[i].trace_hi
                     && s[j].trace_lo == s[i].trace_lo) j++;
        distinct++;
        i = j;
    }
    if (!po_traceidx_init(t, distinct ? distinct : 1)) return 0;

    i = 0;
    while (i < n) {
        uint32_t j = i + 1;
        while (j < n && s[j].trace_hi == s[i].trace_hi
                     && s[j].trace_lo == s[i].trace_lo) j++;
        po_traceidx_put(t, s[i].trace_hi, s[i].trace_lo, i, j - i);
        i = j;
    }
    return 1;
}

#endif /* PO_TRACEIDX_H */
