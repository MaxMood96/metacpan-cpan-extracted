/* po_flame.h - the aggregated self-time tree.
 *
 * SELF TIME, NOT TOTAL TIME, is what a flamegraph is for. A root span that
 * lasts five seconds because it waited on a database did not SPEND five
 * seconds; the database did. Attributing total time to the parent makes every
 * flamegraph say "the entry point is slow", which is true and useless.
 *
 *     self = duration - (time covered by children)
 *
 * "Covered by", not "sum of": concurrent children overlap, and summing them
 * can exceed the parent's duration and produce a negative self time. Merging
 * the child intervals first is the difference between a correct graph and one
 * with impossible bars in it.
 */
#ifndef PO_FLAME_H
#define PO_FLAME_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_span.h"

#define PO_FLAME_MAX 4096

typedef struct {
    uint32_t name_sym;
    uint32_t service_sym;
    int32_t  parent;        /* index into the frame array, or -1 */
    int32_t  depth;
    po_u64   total;         /* summed across every trace merged in */
    po_u64   self;
    po_u64   count;
} po_frame;

typedef struct {
    po_frame *f;
    uint32_t  n, cap;
} po_flame;

static int po_flame_init(po_flame *fl) {
    memset(fl, 0, sizeof(*fl));
    fl->cap = 64;
    fl->f = (po_frame *)calloc(fl->cap, sizeof(po_frame));
    return fl->f != NULL;
}

static void po_flame_free(po_flame *fl) {
    free(fl->f); fl->f = NULL; fl->n = fl->cap = 0;
}

/* Frames are keyed by (parent, name, service), so the same function called
 * from two places stays two frames - which is what makes a flamegraph a
 * TREE rather than a bar chart of function names. */
static po_frame *po_flame_frame(po_flame *fl, int32_t parent,
                                uint32_t name, uint32_t service, int32_t depth) {
    uint32_t i;
    for (i = 0; i < fl->n; i++)
        if (fl->f[i].parent == parent && fl->f[i].name_sym == name
            && fl->f[i].service_sym == service) return &fl->f[i];
    if (fl->n == fl->cap) {
        uint32_t want = fl->cap * 2;
        po_frame *nf = (po_frame *)realloc(fl->f, want * sizeof(po_frame));
        if (!nf) return NULL;
        memset(nf + fl->cap, 0, (want - fl->cap) * sizeof(po_frame));
        fl->f = nf; fl->cap = want;
    }
    fl->f[fl->n].parent      = parent;
    fl->f[fl->n].name_sym    = name;
    fl->f[fl->n].service_sym = service;
    fl->f[fl->n].depth       = depth;
    return &fl->f[fl->n++];
}

/* Merged length of a set of intervals. The merge is what stops concurrent
 * children double-counting and driving self time negative. */
typedef struct { po_u64 a, b; } po_iv;

static int po_iv_cmp(const void *x, const void *y) {
    const po_iv *p = (const po_iv *)x, *q = (const po_iv *)y;
    return p->a < q->a ? -1 : (p->a > q->a ? 1 : 0);
}

static po_u64 po_iv_covered(po_iv *v, uint32_t n) {
    po_u64 total = 0, cur_a, cur_b;
    uint32_t i;
    if (!n) return 0;
    qsort(v, n, sizeof(po_iv), po_iv_cmp);
    cur_a = v[0].a; cur_b = v[0].b;
    for (i = 1; i < n; i++) {
        if (v[i].a <= cur_b) { if (v[i].b > cur_b) cur_b = v[i].b; }
        else { total += cur_b - cur_a; cur_a = v[i].a; cur_b = v[i].b; }
    }
    total += cur_b - cur_a;
    return total;
}

/* Fold one assembled trace in. */
static int po_flame_add(po_flame *fl, const po_span *s, uint32_t n,
                        const po_tree *t) {
    int32_t *map;
    uint32_t i, d;
    po_iv *kids;

    if (!n) return 1;
    map  = (int32_t *)malloc((size_t)n * sizeof(int32_t));
    kids = (po_iv *)malloc((size_t)n * sizeof(po_iv));
    if (!map || !kids) { free(map); free(kids); return 0; }
    for (i = 0; i < n; i++) map[i] = -1;

    /* Depth order, so a parent's frame exists before its children need it. */
    for (d = 0; d < PO_TREE_MAX_DEPTH; d++) {
        int any = 0;
        for (i = 0; i < n; i++) {
            po_frame *f;
            int32_t parent_frame;
            if (t->depth[i] != (int32_t)d) continue;
            any = 1;
            parent_frame = (t->parent[i] >= 0) ? map[t->parent[i]] : -1;
            f = po_flame_frame(fl, parent_frame, s[i].name_sym,
                               s[i].service_sym, (int32_t)d);
            if (!f) { free(map); free(kids); return 0; }
            map[i] = (int32_t)(f - fl->f);

            {   /* self = duration minus the span COVERED by children */
                uint32_t k, nk = 0;
                for (k = 0; k < n; k++) {
                    if (t->parent[k] != (int32_t)i) continue;
                    kids[nk].a = s[k].start_ns;
                    kids[nk].b = s[k].start_ns + s[k].dur_ns;
                    nk++;
                }
                {
                    po_u64 cov = po_iv_covered(kids, nk);
                    po_u64 self = s[i].dur_ns > cov ? s[i].dur_ns - cov : 0;
                    f->total += s[i].dur_ns;
                    f->self  += self;
                    f->count++;
                }
            }
        }
        if (!any && d > 0) break;
    }
    free(map); free(kids);
    return 1;
}

static po_u64 po_flame_total_self(const po_flame *fl) {
    po_u64 t = 0;
    uint32_t i;
    for (i = 0; i < fl->n; i++) t += fl->f[i].self;
    return t;
}

#endif /* PO_FLAME_H */
