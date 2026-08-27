/* po_sgraph.h - the service graph, accumulated at seal.
 *
 * The service map needs edges: which service called which, how often, how
 * fast, how often it failed. Computing that at QUERY time means scanning
 * every span in the range on every page load, which makes the most-visited
 * screen the most expensive one.
 *
 * The compactor already walks every span, so it also accumulates a small edge
 * table. The table is tiny - services times services, not spans - so the
 * service map reads a few kilobytes per segment and aggregates.
 *
 * THE EDGE RULE. A span whose parent belongs to a DIFFERENT service is a call
 * across a service boundary. That is simpler than matching CLIENT spans to
 * their SERVER children and it is more robust: it produces an edge whether or
 * not both sides set span.kind, which plenty of instrumentation does not.
 *
 * A SPAN WHOSE PARENT IS ABSENT gets an edge from a synthetic root rather
 * than being dropped. A request whose caller was not instrumented is exactly
 * the thing a service map should SHOW - "traffic is arriving from somewhere I
 * cannot see" is a finding, not a gap to hide.
 */
#ifndef PO_SGRAPH_H
#define PO_SGRAPH_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_span.h"

#define PO_SVC_UNKNOWN 0xFFFFFFFFu   /* the synthetic root */

typedef struct {
    uint32_t caller;      /* service symbol, or PO_SVC_UNKNOWN */
    uint32_t callee;
    po_u64   count;
    po_u64   errors;
    po_u64   dur_sum;     /* nanoseconds; enough for a mean */
    po_u64   dur_max;
} po_edge;

typedef struct {
    po_edge *e;
    uint32_t n, cap;
} po_sgraph;

static int po_sgraph_init(po_sgraph *g) {
    memset(g, 0, sizeof(*g));
    g->cap = 32;
    g->e = (po_edge *)calloc(g->cap, sizeof(po_edge));
    return g->e != NULL;
}

static void po_sgraph_free(po_sgraph *g) {
    free(g->e); g->e = NULL; g->n = g->cap = 0;
}

static po_edge *po_sgraph_find(po_sgraph *g, uint32_t caller, uint32_t callee) {
    uint32_t i;
    /* Linear: the table is services-squared, which is tens, not thousands.
     * A hash here would be more code than it saves. */
    for (i = 0; i < g->n; i++)
        if (g->e[i].caller == caller && g->e[i].callee == callee)
            return &g->e[i];
    if (g->n == g->cap) {
        uint32_t want = g->cap * 2;
        po_edge *ne = (po_edge *)realloc(g->e, want * sizeof(po_edge));
        if (!ne) return NULL;
        memset(ne + g->cap, 0, (want - g->cap) * sizeof(po_edge));
        g->e = ne; g->cap = want;
    }
    g->e[g->n].caller = caller;
    g->e[g->n].callee = callee;
    return &g->e[g->n++];
}

/* Accumulate edges from one trace's spans, using the tree already built.
 *
 * Walks the assembled tree rather than raw parent ids, so a span whose parent
 * is genuinely absent is distinguished from one whose parent simply has not
 * been looked up yet. */
static int po_sgraph_add_trace(po_sgraph *g, const po_span *s, uint32_t n,
                               const po_tree *t) {
    uint32_t i;
    for (i = 0; i < n; i++) {
        uint32_t caller;
        po_edge *e;

        if (t->parent[i] >= 0) {
            uint32_t p = (uint32_t)t->parent[i];
            /* Same service: an internal call, not a graph edge. Counting it
             * would make every service a self-loop dominating the map. */
            if (s[p].service_sym == s[i].service_sym) continue;
            caller = s[p].service_sym;
        }
        else {
            /* No parent in the trace. A true root is entry traffic; a span
             * whose named parent is missing is traffic from something
             * uninstrumented. Both are edges from the synthetic root, and
             * both are worth seeing. */
            caller = PO_SVC_UNKNOWN;
        }

        e = po_sgraph_find(g, caller, s[i].service_sym);
        if (!e) return 0;
        e->count++;
        if (po_span_is_error(&s[i])) e->errors++;
        e->dur_sum += s[i].dur_ns;
        if (s[i].dur_ns > e->dur_max) e->dur_max = s[i].dur_ns;
    }
    return 1;
}

/* Build over a whole segment's sorted spans. */
static int po_sgraph_build(po_sgraph *g, const po_span *s, uint32_t n) {
    uint32_t i = 0;
    while (i < n) {
        uint32_t j = i + 1;
        po_tree t;
        while (j < n && s[j].trace_hi == s[i].trace_hi
                     && s[j].trace_lo == s[i].trace_lo) j++;
        if (!po_tree_build(&t, s + i, j - i)) return 0;
        if (!po_sgraph_add_trace(g, s + i, j - i, &t)) { po_tree_free(&t); return 0; }
        po_tree_free(&t);
        i = j;
    }
    return 1;
}

#endif /* PO_SGRAPH_H */
