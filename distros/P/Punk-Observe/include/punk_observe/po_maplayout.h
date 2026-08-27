/* po_maplayout.h - the service map, laid out in C at request time.
 *
 * A layered DAG of fewer than a couple of hundred nodes is trivial
 * arithmetic: assign layers by longest path from the roots, order within a
 * layer to reduce crossings, place, emit. Doing it server-side means no
 * layout library, no client-side reflow, and a map that is in the HTML.
 *
 * A CYCLE IN THE CALL GRAPH IS REAL, NOT CORRUPTION.
 *
 * Services genuinely call each other back - a gateway calls auth, auth calls
 * the gateway's token endpoint. A longest-path layering loops forever on
 * that. So back edges are DETECTED and drawn differently rather than being
 * treated as an error or, worse, silently dropped: an edge that exists and is
 * not on the map is a lie about the topology.
 *
 * (This is a different thing from phase 7's parent-pointer cycle, which IS
 * corruption. Both are bounded; only one is legitimate.)
 */
#ifndef PO_MAPLAYOUT_H
#define PO_MAPLAYOUT_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_sgraph.h"

#define PO_MAP_MAX_NODES 256
#define PO_MAP_MAX_LAYER 32

typedef struct {
    uint32_t service;      /* symbol id, or PO_SVC_UNKNOWN for the root */
    int      layer;
    int      slot;         /* position within the layer */
    po_u64   in_count, out_count, errors;
} po_map_node;

typedef struct {
    po_map_node node[PO_MAP_MAX_NODES];
    int         n;
    int         layer_count;
    int         back_edges;   /* edges that close a cycle */
} po_map;

static int po_map_find(po_map *m, uint32_t svc) {
    int i;
    for (i = 0; i < m->n; i++) if (m->node[i].service == svc) return i;
    if (m->n >= PO_MAP_MAX_NODES) return -1;
    m->node[m->n].service = svc;
    m->node[m->n].layer   = -1;
    return m->n++;
}

/* Longest-path layering, iterated to a fixed point with a bound.
 *
 * The bound is what makes a cycle terminate: with N nodes, no honest longest
 * path exceeds N, so anything still moving after N rounds is going round a
 * loop. Those edges are counted and the node keeps the layer it had. */
static int po_map_layout(po_map *m, const po_sgraph *g) {
    int i, round, moved = 1;

    memset(m, 0, sizeof(*m));
    for (i = 0; i < (int)g->n; i++) {
        int a = po_map_find(m, g->e[i].caller);
        int b = po_map_find(m, g->e[i].callee);
        if (a < 0 || b < 0) return 0;
        m->node[a].out_count += g->e[i].count;
        m->node[b].in_count  += g->e[i].count;
        m->node[b].errors    += g->e[i].errors;
    }

    /* The synthetic root, and anything nothing calls, starts at layer 0. */
    for (i = 0; i < m->n; i++)
        if (m->node[i].service == PO_SVC_UNKNOWN || m->node[i].in_count == 0)
            m->node[i].layer = 0;
    for (i = 0; i < m->n; i++) if (m->node[i].layer < 0) m->node[i].layer = 0;

    for (round = 0; round < m->n + 1 && moved; round++) {
        moved = 0;
        for (i = 0; i < (int)g->n; i++) {
            int a = po_map_find(m, g->e[i].caller);
            int b = po_map_find(m, g->e[i].callee);
            if (a < 0 || b < 0) continue;
            if (m->node[b].layer <= m->node[a].layer) {
                if (round < m->n) {
                    m->node[b].layer = m->node[a].layer + 1;
                    moved = 1;
                }
            }
        }
    }

    /* Anything still violating the layering after the bound closes a cycle.
     * Counted, and the caller draws those edges differently. */
    for (i = 0; i < (int)g->n; i++) {
        int a = po_map_find(m, g->e[i].caller);
        int b = po_map_find(m, g->e[i].callee);
        if (a >= 0 && b >= 0 && m->node[b].layer <= m->node[a].layer)
            m->back_edges++;
    }

    for (i = 0; i < m->n; i++) {
        if (m->node[i].layer >= PO_MAP_MAX_LAYER)
            m->node[i].layer = PO_MAP_MAX_LAYER - 1;
        if (m->node[i].layer + 1 > m->layer_count)
            m->layer_count = m->node[i].layer + 1;
    }

    /* Slot within the layer: busiest first, so the eye lands on the service
     * carrying the traffic rather than on whichever one readdir found. */
    {
        int l;
        for (l = 0; l < m->layer_count; l++) {
            int slot = 0, j;
            for (;;) {
                int best = -1;
                po_u64 bestc = 0;
                for (j = 0; j < m->n; j++) {
                    if (m->node[j].layer != l || m->node[j].slot) continue;
                    if (best < 0 || m->node[j].in_count > bestc) {
                        best = j; bestc = m->node[j].in_count;
                    }
                }
                if (best < 0) break;
                m->node[best].slot = ++slot;
            }
        }
    }
    return 1;
}

static int po_map_is_back_edge(const po_map *m, uint32_t caller, uint32_t callee) {
    int a = -1, b = -1, i;
    for (i = 0; i < m->n; i++) {
        if (m->node[i].service == caller) a = i;
        if (m->node[i].service == callee) b = i;
    }
    if (a < 0 || b < 0) return 0;
    return m->node[b].layer <= m->node[a].layer;
}

#endif /* PO_MAPLAYOUT_H */
