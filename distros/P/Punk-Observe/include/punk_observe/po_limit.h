/* po_limit.h - three limits, enforced in three places, failing three ways.
 *
 * TREATING THESE AS ONE LIMIT IS THE MISTAKE. Each has a wrong answer that is
 * worse than the limit itself, and the wrong answers are different, so one
 * mechanism cannot serve all three.
 *
 * All three matter on a single-tenant box. They are what stops one
 * misconfigured service taking down the machine whose job is to tell you why
 * things fell over.
 *
 *   INGEST RATE -> a partial success naming the rejected count.
 *
 *   Not a 429. A 429 makes the exporter re-send the whole batch, forever, at
 *   the moment the server is already under pressure - the limit becomes an
 *   amplifier. OTLP has `partial_success` precisely for this: accept what
 *   fits, say how much did not, and the exporter drops the rest rather than
 *   queueing it.
 *
 *   CARDINALITY -> the NEW series is dropped.
 *
 *   Never an eviction. Evicting an existing series to admit a new one turns a
 *   cardinality problem into data loss on the exact series somebody has open
 *   in a dashboard, which is the one they are watching because it matters.
 *
 *   STORAGE BYTES -> retention is SHORTENED.
 *
 *   Not a refusal to write. A store over its byte budget should lose old
 *   data; it must not lose the incident happening now, which is when it is
 *   most needed and least replaceable.
 *
 * THE ARENA IS MAPPED BEFORE THE FORK.
 *
 * A counter mapped afterwards is private to each worker, and the symptom is a
 * limit that is silently N times what was configured - which looks like the
 * limit not working rather than like a fork bug. po_shared.h does the
 * mapping; this file adds the rate window to it.
 */
#ifndef PO_LIMIT_H
#define PO_LIMIT_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_time.h"
#include "punk_observe/po_shared.h"

/* ---- ingest rate ----------------------------------------------------------
 *
 * A one-second window, held in the shared arena so the limit is per POOL. Two
 * counters, because a thousand tiny records and one enormous one are
 * different problems and a byte limit alone lets the first through. */
typedef struct {
    po_u64 window_ns;
    po_u64 max_records;   /* 0 = unlimited */
    po_u64 max_bytes;     /* 0 = unlimited */
} po_rate_cfg;

/* A view onto the window, wherever it lives. In production these point into
 * the shared page (po_shared_rate); a test that only cares about the
 * arithmetic can point them at locals. The indirection is what lets the same
 * code be both fork-shared and unit-testable. */
typedef struct {
    po_u64 *window_start;
    po_u64 *records;
    po_u64 *bytes;
    po_u64 *rejected;
} po_rate_win;

/* The window inside the fork-shared arena. */
static void po_shared_rate(po_shared *s, po_rate_win *w) {
    w->window_start = &s->m->rate_window_start;
    w->records      = &s->m->rate_records;
    w->bytes        = &s->m->rate_bytes;
    w->rejected     = &s->m->rate_rejected;
}

static void po_rate_cfg_init(po_rate_cfg *c, po_u64 rec, po_u64 bytes) {
    c->window_ns   = PO_NS_PER_SEC;
    c->max_records = rec;
    c->max_bytes   = bytes;
}

/* A private window, for a caller with no pool. Still goes through the same
 * admit function, so the single-worker path is not a second implementation. */
typedef struct { po_u64 start, records, bytes, rejected; } po_rate_local;

static void po_rate_local_bind(po_rate_local *l, po_rate_win *w) {
    memset(l, 0, sizeof(*l));
    w->window_start = &l->start;
    w->records      = &l->records;
    w->bytes        = &l->bytes;
    w->rejected     = &l->rejected;
}

/* Admit as much of a batch as fits, and REPORT the remainder.
 *
 * Returns how many records were accepted. The caller turns the difference
 * into `rejected_data_points` on the OTLP partial success - which is why this
 * is a count and not a boolean. A yes/no answer would force the caller to
 * refuse the whole batch, and refusing whole batches is what makes a limiter
 * an amplifier. */
static po_u64 po_rate_admit(po_rate_cfg *c, po_rate_win *w,
                            po_u64 records, po_u64 bytes) {
    po_u64 now = po_now_ns();
    po_u64 room_r = records, room_b = records, per;

    if (!c->max_records && !c->max_bytes) return records;   /* unconfigured */
    if (!records) return 0;

    /* A fixed window, reset when it has elapsed. Chosen over a sliding one
     * because a sliding window needs per-key history and this counter lives
     * in a flat shared page; the cost is that a burst can straddle a boundary,
     * which for a backpressure limit is acceptable and for a billing meter
     * would not be. */
    if (!*w->window_start || now - *w->window_start >= c->window_ns) {
        *w->window_start = now;
        *w->records = 0;
        *w->bytes   = 0;
    }

    if (c->max_records)
        room_r = *w->records >= c->max_records
                 ? 0 : c->max_records - *w->records;

    if (c->max_bytes) {
        po_u64 room = *w->bytes >= c->max_bytes ? 0 : c->max_bytes - *w->bytes;
        /* Bytes are converted to a record allowance at the batch's own
         * average size. Estimating rather than measuring per record is the
         * honest limitation: the alternative is a per-record size the caller
         * does not have at this point. */
        per = bytes / records;
        if (!per) per = 1;
        room_b = room / per;
    }

    {
        po_u64 admit = room_r < room_b ? room_r : room_b;
        if (admit > records) admit = records;
        *w->records += admit;
        *w->bytes   += records ? (bytes / records) * admit : 0;
        *w->rejected += records - admit;
        return admit;
    }
}

/* ---- cardinality ----------------------------------------------------------
 *
 * po_shared.h owns the counter; this is the decision written where the other
 * two limits are, so all three read together.
 *
 * An existing series is NEVER evicted. `po_shared_admit_series` only ever
 * increments, so admission is monotonic and a refusal cannot displace
 * anything - the property is structural rather than a rule somebody has to
 * remember. */
static int po_limit_series(po_shared *s) {
    return po_shared_admit_series(s);
}

/* ---- the indexed-attribute allowlist --------------------------------------
 *
 * THE LIMIT THAT MATTERS MORE THAN ANY OF THE THREE NUMBERS.
 *
 * Logs and spans carry unbounded attributes. Only the configured set becomes
 * an index dimension; the rest stay in the record and are reachable by a
 * residual filter, so nothing is lost - it is just slower to find. Without
 * this, one service putting a request id in a resource attribute takes the
 * store down, and the store is right to refuse.
 *
 * THE OVERFLOW COUNTER NAMES THE ATTRIBUTE. The person who hits this first is
 * a self-hoster with no support contract and no dashboard telling them which
 * attribute did it, so "cardinality limit exceeded" is not an answer. The
 * name is. */
#define PO_ATTR_OVERFLOW_MAX 16

typedef struct {
    char     name[PO_ATTR_OVERFLOW_MAX][64];
    size_t   name_len[PO_ATTR_OVERFLOW_MAX];
    po_u64   count[PO_ATTR_OVERFLOW_MAX];
    uint32_t n;
    po_u64   dropped_other;   /* past the naming cap, still counted */
} po_attr_overflow;

static void po_attr_overflow_init(po_attr_overflow *o) {
    memset(o, 0, sizeof(*o));
}

static void po_attr_overflow_note(po_attr_overflow *o, const char *k,
                                  size_t klen) {
    uint32_t i;
    if (klen > 63) klen = 63;
    for (i = 0; i < o->n; i++)
        if (o->name_len[i] == klen && memcmp(o->name[i], k, klen) == 0) {
            o->count[i]++;
            return;
        }
    if (o->n >= PO_ATTR_OVERFLOW_MAX) { o->dropped_other++; return; }
    memcpy(o->name[o->n], k, klen);
    o->name[o->n][klen] = '\0';
    o->name_len[o->n]   = klen;
    o->count[o->n]      = 1;
    o->n++;
}

/* The worst offender, which is what a status page shows. */
static int po_attr_overflow_worst(const po_attr_overflow *o) {
    uint32_t i;
    int best = -1;
    po_u64 most = 0;
    for (i = 0; i < o->n; i++)
        if (best < 0 || o->count[i] > most) { best = (int)i; most = o->count[i]; }
    return best;
}

/* ---- storage bytes --------------------------------------------------------
 *
 * The retention job's answer to a byte budget: how far back can be kept.
 *
 * Blocks are given oldest-first with their sizes. The horizon returned is the
 * age at which keeping any more would exceed the budget. Nothing is refused
 * and no write fails; the store simply remembers less.
 *
 * Returns the number of blocks to KEEP (the newest ones). Zero means the
 * budget cannot hold even the newest block, which is a configuration error
 * rather than a reason to drop it - the caller keeps one and says so. */
typedef struct {
    po_u64 age_ns;    /* how old the block is */
    po_u64 bytes;
} po_blk_size;

static uint32_t po_limit_storage(const po_blk_size *b, uint32_t n,
                                 po_u64 budget, po_u64 *kept_bytes,
                                 po_u64 *horizon_ns) {
    po_u64 total = 0;
    uint32_t keep = 0;
    int i;

    if (kept_bytes) *kept_bytes = 0;
    if (horizon_ns) *horizon_ns = 0;
    if (!n) return 0;
    if (!budget) {                       /* unconfigured: keep everything */
        for (i = 0; i < (int)n; i++) total += b[i].bytes;
        if (kept_bytes) *kept_bytes = total;
        if (horizon_ns) *horizon_ns = PO_U64_MAX;
        return n;
    }

    /* Newest first, because the newest data is the data being looked at. */
    for (i = (int)n - 1; i >= 0; i--) {
        if (total + b[i].bytes > budget) break;
        total += b[i].bytes;
        keep++;
        if (horizon_ns) *horizon_ns = b[i].age_ns;
    }
    if (kept_bytes) *kept_bytes = total;

    /* THE NEWEST BLOCK IS ALWAYS KEPT. A budget smaller than one block is a
     * misconfiguration, and answering it by deleting the incident in progress
     * would be the limiter doing more damage than the thing it limits. */
    if (!keep) {
        keep = 1;
        if (kept_bytes) *kept_bytes = b[n - 1].bytes;
        if (horizon_ns) *horizon_ns = b[n - 1].age_ns;
    }
    return keep;
}

#endif /* PO_LIMIT_H */
