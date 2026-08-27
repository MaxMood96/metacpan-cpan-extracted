/* po_retain.h - making the disk stop growing, without SIGBUS.
 *
 * TWO RULES, AND THE SECOND ONE IS WHY LOCK-FREE READERS WORK.
 *
 * 1. DELETION IS BY WHOLE BLOCK, NEVER BY RECORD. "Delete these logs" would
 *    require rewriting a compressed block, which means a segment is no longer
 *    immutable, which removes the property every reader depends on. A block
 *    is two hours; it expires as a unit. Per-record deletion, if a legal
 *    request ever needs it, is a separate feature that rewrites a block into
 *    a new generation - it does not get smuggled in here.
 *
 * 2. THE PRIMITIVE IS unlink(2), NEVER ftruncate(2).
 *
 *    A reader holding an mmap of an UNLINKED file keeps valid pages on POSIX:
 *    the name is gone, the inode lives until the last mapping drops. That is
 *    what makes it safe to delete a segment somebody is reading.
 *
 *    A reader holding an mmap of a TRUNCATED file takes SIGBUS on the next
 *    touch of a removed page. Not an error return - a signal, killing the
 *    worker, mid-request, for every connection it held.
 *
 *    So there is no ftruncate in this file, and t/0082-retention.t fails the
 *    suite if one appears anywhere on a segment path. "Reclaim the tail of a
 *    partly-expired segment" is the optimisation that will be suggested, and
 *    this is the answer to it.
 *
 * AND THE THING NOBODY FINDS BY TESTING ON A LAPTOP: a deleted file that is
 * still mapped is still on the disk. A 2GB segment unlinked an hour ago
 * occupies 2GB until the last worker drops its mapping, so the space a
 * retention policy promises and the space `df` reports diverge with no
 * explanation. This file counts it.
 */
#ifndef PO_RETAIN_H
#define PO_RETAIN_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_seg.h"
#include "punk_observe/po_time.h"

#ifndef _WIN32
#  include <dirent.h>
#  include <sys/stat.h>
#endif

#define PO_RETAIN_MAX 4096

typedef struct {
    char   path[PO_PATH_MAX];
    po_u64 t_min, t_max;
    po_u64 bytes;
    int    expired;
} po_seg_info;

typedef struct {
    po_seg_info *seg;
    uint32_t     n, cap;

    /* what the sweep did */
    uint32_t unlinked;
    po_u64   bytes_freed;
    uint32_t kept;

    /* what is gone but still occupying the disk */
    uint32_t mapped_deleted;
    po_u64   mapped_deleted_bytes;

    uint32_t truncate_calls;   /* MUST stay zero; the tests assert it */
} po_retain;

static int po_retain_init(po_retain *r) {
    memset(r, 0, sizeof(*r));
    r->cap = 64;
    r->seg = (po_seg_info *)calloc(r->cap, sizeof(po_seg_info));
    return r->seg != NULL;
}

static void po_retain_free(po_retain *r) {
    free(r->seg); r->seg = NULL; r->n = r->cap = 0;
}

static int po_retain_add(po_retain *r, const char *path) {
    po_seg_r s;
    po_seg_info *e;
#ifndef _WIN32
    struct stat st;
#endif

    if (r->n == r->cap) {
        uint32_t want = r->cap * 2;
        po_seg_info *ns = (po_seg_info *)realloc(r->seg, want * sizeof(po_seg_info));
        if (!ns) return 0;
        memset(ns + r->cap, 0, (want - r->cap) * sizeof(po_seg_info));
        r->seg = ns; r->cap = want;
    }
    e = &r->seg[r->n];
    memset(e, 0, sizeof(*e));
    strncpy(e->path, path, sizeof(e->path) - 1);

    /* The footer carries the span, so expiry is decided WITHOUT reading the
     * data - which is the same pruning a query uses. */
    if (!po_seg_open(&s, path)) return 0;
    e->t_min = s.hdr.t_min;
    e->t_max = s.hdr.t_max;
    po_seg_close(&s);

#ifndef _WIN32
    if (stat(path, &st) == 0) e->bytes = (po_u64)st.st_size;
#endif
    r->n++;
    return 1;
}

/* Mark everything whose LATEST record is older than the cutoff.
 *
 * t_max, not t_min: a segment is expired only when every record in it is,
 * because a block is deleted as a unit and a partly-expired one keeps its
 * whole span. Using t_min would delete data inside the retention window. */
static uint32_t po_retain_mark(po_retain *r, po_u64 cutoff) {
    uint32_t i, n = 0;
    for (i = 0; i < r->n; i++) {
        r->seg[i].expired = (r->seg[i].t_max < cutoff);
        if (r->seg[i].expired) n++;
    }
    return n;
}

/* Delete the marked segments.
 *
 * unlink only. There is deliberately no code path here that shortens a file. */
static int po_retain_sweep(po_retain *r) {
    uint32_t i;
    for (i = 0; i < r->n; i++) {
        if (!r->seg[i].expired) { r->kept++; continue; }
        if (unlink(r->seg[i].path) == 0) {
            r->unlinked++;
            r->bytes_freed += r->seg[i].bytes;
        }
    }
    return 1;
}

/* Account for segments that are unlinked but still mapped.
 *
 * `open_maps` is what the reader side reports: how many mappings of
 * now-nameless segments are still held. Those bytes are NOT free, whatever
 * the retention policy promised, and the status page shows this number so an
 * operator can see why the disk has not shrunk. */
static void po_retain_account_mapped(po_retain *r, uint32_t open_maps,
                                     po_u64 open_bytes) {
    r->mapped_deleted       = open_maps;
    r->mapped_deleted_bytes = open_bytes;
}

/* An empty block directory is NOT an expired one.
 *
 * A tenant with no traffic for two hours must not have its directory removed
 * and recreated in a loop - that is churn with no benefit and it makes every
 * sweep look like it did something. */
static int po_block_removable(uint32_t segments, int expired_all) {
    return segments > 0 && expired_all;
}

/* ---- generations ----------------------------------------------------------
 *
 * A query reading generation N must keep reading it while retention moves on.
 * Generations are reference-counted, the count lives with the reader, and a
 * generation with a live reader is never the one whose segments are unlinked.
 *
 * (Unlinking one it IS reading would still be safe, by the mmap rule above.
 * The reference count is about not losing the MANIFEST entry that tells the
 * reader which segments belong together.) */
typedef struct {
    po_u64   generation;
    uint32_t readers;
} po_gen_ref;

typedef struct {
    po_gen_ref g[32];
    int        n;
} po_gen_table;

static void po_gen_acquire(po_gen_table *t, po_u64 gen) {
    int i;
    for (i = 0; i < t->n; i++)
        if (t->g[i].generation == gen) { t->g[i].readers++; return; }
    if (t->n < 32) {
        t->g[t->n].generation = gen;
        t->g[t->n].readers = 1;
        t->n++;
    }
}

static void po_gen_release(po_gen_table *t, po_u64 gen) {
    int i;
    for (i = 0; i < t->n; i++)
        if (t->g[i].generation == gen && t->g[i].readers)
            { t->g[i].readers--; return; }
}

static int po_gen_busy(const po_gen_table *t, po_u64 gen) {
    int i;
    for (i = 0; i < t->n; i++)
        if (t->g[i].generation == gen) return t->g[i].readers > 0;
    return 0;
}

#endif /* PO_RETAIN_H */
