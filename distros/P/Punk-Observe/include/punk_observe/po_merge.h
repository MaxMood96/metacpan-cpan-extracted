/* po_merge.h - the k-way merge that repays phase 4's per-worker writing.
 *
 * Phase 4 accepted N segments per block from N workers, because the
 * alternative was a dedicated writer serialising every ingest. The bill comes
 * due here, once, off the hot path: N sorted runs become one.
 *
 * A loser tree would beat a linear scan of the heads above roughly sixteen
 * runs. N is the WORKER COUNT - four, eight, sixteen - so the linear scan
 * wins on cache behaviour and is a tenth of the code. If somebody ever runs
 * this with sixty-four workers, that is the moment to change it, with the
 * measurement that justified it.
 *
 * THE MERGE IS DETERMINISTIC. The same inputs produce a byte-identical
 * output, which makes a regression a diff rather than an investigation - and
 * it means a re-compaction after a crash produces the same segment rather
 * than a different-but-equivalent one.
 */
#ifndef PO_MERGE_H
#define PO_MERGE_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_rec.h"

#define PO_MERGE_MAX_RUNS 64

typedef struct {
    const po_rec *rec;
    size_t        n, i;
} po_run;

typedef struct {
    po_run   run[PO_MERGE_MAX_RUNS];
    int      nrun;
    po_u64   emitted;
    po_u64   duplicates;
} po_merge;

static void po_merge_init(po_merge *m) { memset(m, 0, sizeof(*m)); }

static int po_merge_add_run(po_merge *m, const po_rec *r, size_t n) {
    if (m->nrun >= PO_MERGE_MAX_RUNS) return 0;
    m->run[m->nrun].rec = r;
    m->run[m->nrun].n   = n;
    m->run[m->nrun].i   = 0;
    m->nrun++;
    return 1;
}

/* The ordering. Time first, then a TOTAL tiebreak - without one the merge is
 * unstable and two runs of the same inputs differ. */
static int po_rec_before(const po_rec *a, const po_rec *b) {
    if (a->t_unix_nano != b->t_unix_nano)
        return a->t_unix_nano < b->t_unix_nano;
    if (a->series != b->series) return a->series < b->series;
    if (a->kind != b->kind)     return a->kind < b->kind;
    if (a->span_id != b->span_id) return a->span_id < b->span_id;
    return 0;
}

static int po_rec_same(const po_rec *a, const po_rec *b) {
    return a->t_unix_nano == b->t_unix_nano
        && a->series      == b->series
        && a->kind        == b->kind
        && a->span_id     == b->span_id
        && a->trace_id_hi == b->trace_id_hi
        && a->trace_id_lo == b->trace_id_lo;
}

/* Pull the next record. Returns NULL when every run is drained.
 *
 * DUPLICATES ARE COLLAPSED HERE. Phase 4's crash window - a WAL consumed into
 * a segment, then re-consumed after a crash between rename and unlink -
 * leaves the same records twice. Making the write path idempotent would cost
 * a fsync and a lookup per batch on the hot path; collapsing on the read side
 * costs one comparison in a merge that is already comparing. */
static const po_rec *po_merge_next(po_merge *m) {
    int i, best = -1;
    const po_rec *out;

    for (;;) {
        best = -1;
        for (i = 0; i < m->nrun; i++) {
            if (m->run[i].i >= m->run[i].n) continue;
            if (best < 0 ||
                po_rec_before(&m->run[i].rec[m->run[i].i],
                              &m->run[best].rec[m->run[best].i]))
                best = i;
        }
        if (best < 0) return NULL;

        out = &m->run[best].rec[m->run[best].i];
        m->run[best].i++;

        /* Drain any identical record from the other runs. */
        {
            int dropped = 0;
            for (i = 0; i < m->nrun; i++) {
                while (m->run[i].i < m->run[i].n &&
                       po_rec_same(&m->run[i].rec[m->run[i].i], out)) {
                    m->run[i].i++;
                    dropped++;
                }
            }
            m->duplicates += (po_u64)dropped;
        }
        m->emitted++;
        return out;
    }
}

#endif /* PO_MERGE_H */
