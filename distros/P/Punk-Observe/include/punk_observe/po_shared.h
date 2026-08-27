/* po_shared.h - the fork-shared arena, and the cardinality cap in it.
 *
 * Cardinality is the failure mode that kills observability backends, and it
 * always arrives the same way: somebody puts a user id, a request id or a
 * full URL into an attribute, and the series count goes from thousands to
 * millions in an afternoon. The limit therefore has to be a HARD CAP enforced
 * at ingest, not a dashboard warning nobody is looking at.
 *
 * With phase 4's content-derived series ids there is no central assigner to
 * hang the counter on, so it lives here: one MAP_SHARED|MAP_ANONYMOUS region,
 * MAPPED BEFORE THE FORK, incremented atomically by every worker.
 *
 * THE ORDER MATTERS AND THE FAILURE IS SILENT. A region mapped AFTER the fork
 * is private per worker: each one counts its own series, the effective limit
 * becomes N times what was configured, and nothing anywhere reports a problem
 * - the operator simply finds the cap did not hold. hm_bus.h makes the same
 * point about its own waker descriptors, and calls the symptom "delivery
 * works to some workers", which is the same shape of bug.
 */
#ifndef PO_SHARED_H
#define PO_SHARED_H

#include "punk_observe/po_compat.h"

#ifndef _WIN32
#  include <sys/mman.h>
#  include <unistd.h>
#endif

#define PO_SHM_MAGIC 0x4D48534Fu     /* "OSHM" */

/* Deliberately small and flat. Anything that needs a variable-size shared
 * structure needs a different mechanism; this is a fixed set of counters. */
typedef struct {
    uint32_t magic;
    uint32_t slots;
    po_u64   pid_at_map;      /* the process that created it, for the guard */
    po_u64   series;          /* distinct series admitted                   */
    po_u64   series_cap;      /* 0 = unlimited                              */
    po_u64   rejected;        /* series refused by the cap                  */
    po_u64   overflow;        /* records attributed to the overflow series  */
    po_u64   records;         /* accepted                                   */
    po_u64   bytes;           /* accepted, for metering                     */

    /* The ingest rate window, HERE rather than in each worker.
     *
     * A per-worker window on a four-worker box is four times the configured
     * limit, and the symptom is a limiter that looks like it is not working
     * rather than like a fork bug. Appended to this struct because the arena
     * is already mapped before the fork and already carries the counters that
     * have to be shared. */
    po_u64   rate_window_start;
    po_u64   rate_records;
    po_u64   rate_bytes;
    po_u64   rate_rejected;
} po_shm;

typedef struct {
    po_shm *m;
    size_t  len;
    int     ok;
} po_shared;

static int po_shared_init(po_shared *s, po_u64 series_cap) {
#ifndef _WIN32
    void *p;
    memset(s, 0, sizeof(*s));
    s->len = 4096;
    p = mmap(NULL, s->len, PROT_READ | PROT_WRITE,
             MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if (p == MAP_FAILED) return 0;
    s->m = (po_shm *)p;
    memset(s->m, 0, sizeof(po_shm));
    s->m->magic      = PO_SHM_MAGIC;
    s->m->pid_at_map = (po_u64)getpid();
    s->m->series_cap = series_cap;
    s->ok = 1;
    return 1;
#else
    memset(s, 0, sizeof(*s));
    (void)series_cap;
    return 0;
#endif
}

static void po_shared_free(po_shared *s) {
#ifndef _WIN32
    if (s->m) munmap(s->m, s->len);
#endif
    s->m = NULL; s->ok = 0;
}

/* Admit a series, or refuse it.
 *
 * Returns 1 if the series may be created, 0 if the cap refuses it.
 *
 * OVER THE CAP, THE NEW SERIES IS DROPPED AND THE EXISTING ONES KEEP WORKING.
 * The tempting alternative - evict something to make room - converts a
 * cardinality problem into DATA LOSS on whichever series happens to be least
 * recently used, which is very likely the one somebody has open on a
 * dashboard right now. Dropping the new one is visible, bounded, and
 * attributable; evicting an old one is none of those.
 *
 * The refusal is counted and the records are attributed to a named overflow
 * series, in the shape Punk::OpenTelemetry already uses on the client
 * (otel.metric.overflow), so the data says "you exceeded the cap" rather than
 * going quietly missing. */
static int po_shared_admit_series(po_shared *s) {
    po_u64 cap, cur;
    if (!s->ok || !s->m) return 1;               /* unconfigured: no cap */
    cap = s->m->series_cap;
    if (!cap) { po_atomic_add(&s->m->series, 1); return 1; }

    cur = po_atomic_load(&s->m->series);
    if (cur >= cap) {
        po_atomic_add(&s->m->rejected, 1);
        po_atomic_add(&s->m->overflow, 1);
        return 0;
    }
    /* A racy check-then-increment can overshoot by at most the number of
     * workers, which is bounded and harmless: the cap is a guard rail, not an
     * accounting boundary. Making it exact would need a compare-and-swap loop
     * on the ingest path, and the cost of that is not worth a difference of
     * N series out of a million. What must be exact is that it STOPS. */
    po_atomic_add(&s->m->series, 1);
    return 1;
}

static void po_shared_record(po_shared *s, po_u64 n, po_u64 bytes) {
    if (!s->ok || !s->m) return;
    po_atomic_add(&s->m->records, n);
    po_atomic_add(&s->m->bytes, bytes);
}

/* Is this actually shared? A test asserts a write in one process is visible
 * in another; this is the cheap self-check for the boot diagnostic. */
static int po_shared_is_shared(const po_shared *s) {
#ifdef PO_HAVE_ATOMICS
    return s->ok && s->m && s->m->magic == PO_SHM_MAGIC;
#else
    /* Without atomics the region is shared but the counters are not safe to
     * increment from several processes. Saying so is better than miscounting
     * quietly, and phase 15 refuses a multi-worker configuration on it. */
    return 0;
#endif
}

#endif /* PO_SHARED_H */
