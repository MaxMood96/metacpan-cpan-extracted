/* po_seg.h - the immutable segment.
 *
 * One container, three payload regions, so a query over a time range opens
 * one file per range rather than three and the timestamp pruning is written
 * once.
 *
 * TWO INVARIANTS CARRY EVERYTHING ELSE.
 *
 * 1. THE FOOTER IS LAST, AND THE MAGIC IS THE LAST BYTES OF IT. A segment is
 *    valid if and only if that magic is present, which makes "was this
 *    completely written" a read of the last few bytes rather than a scan. Any
 *    code path that opens a segment without checking will one day read a torn
 *    one, and it will not look torn - it will look like missing data.
 *
 * 2. A SEALED SEGMENT IS NEVER MODIFIED. Written to .tmp, fsync'd, renamed.
 *    The rename is the commit in the directory; the footer is the commit
 *    inside the file. It is deleted by unlink and NEVER by ftruncate: an
 *    unlinked file's existing mappings stay valid on POSIX, a truncated
 *    file's mappings SIGBUS on the next touch of a removed page. That is what
 *    makes lock-free readers possible, and phase 10 is where it gets broken
 *    if it is going to be.
 */
#ifndef PO_SEG_H
#define PO_SEG_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_rec.h"
#include "punk_observe/po_crc32c.h"
#include "punk_observe/po_intern.h"
#include "punk_observe/po_labels.h"

#include <stdio.h>
#include <errno.h>
#ifndef _WIN32
#  include <unistd.h>
#  include <fcntl.h>
#  include <sys/stat.h>
#  include <sys/mman.h>
#else
#  include <io.h>
#  include <fcntl.h>
#endif

#define PO_SEG_MAGIC   0x47534F4Fu    /* "OOSG" */
#define PO_FOOT_MAGIC  0x54464F4Fu    /* "OOFT" */
#define PO_SEG_VERSION 1

#define PO_SEG_HDR  64
#define PO_SEG_FOOT 96
#define PO_SEG_MAX_REGIONS 16

/* REGION KINDS.
 *
 * The first three are the original fixed areas. Everything after is a
 * per-signal area that phases 5-7 produce: metric chunks, log blocks, span
 * arrays and their indexes. They live in a TABLE rather than at fixed
 * offsets, so a signal that gains a structure later does not shift the ones
 * beside it and a reader that does not know a kind can skip it.
 *
 * That is the point of a table: an older reader meeting a newer segment
 * skips what it does not recognise, instead of misreading it. */
#define PO_RGN_RECORDS    1
#define PO_RGN_ARENA      2
#define PO_RGN_SYMBOLS    3
#define PO_RGN_MSERIES    4    /* metric series directory        */
#define PO_RGN_MCHUNKS    5    /* gorilla bit streams            */
#define PO_RGN_MEXEMPLAR  6
#define PO_RGN_LOGDIR     7    /* log block directory            */
#define PO_RGN_LOGBLOCKS  8    /* deflated blocks + blooms       */
#define PO_RGN_SPANS      9    /* the 64-byte span array         */
#define PO_RGN_TRACEIDX  10
#define PO_RGN_TRACESUM  11
#define PO_RGN_SGRAPH    12

typedef struct {
    uint32_t kind;
    po_u64   off, len;
} po_region;

/* signal, so a reader knows what the records region holds without decoding */
#define PO_SIG_MIXED  0
#define PO_SIG_TRACE  1
#define PO_SIG_METRIC 2
#define PO_SIG_LOG    3

typedef struct {
    uint32_t magic;
    uint16_t version;
    uint8_t  signal;
    uint8_t  flags;
    uint32_t tenant_hash;   /* of the tenant id: checked on OPEN, so a
                             * mis-filed segment is caught then rather than
                             * after it has been served */
    uint32_t worker_slot;
    po_u64   t_min, t_max;
    po_u64   records;
    uint8_t  ulid[16];
} po_seg_hdr;

/* A writer accumulates records and symbols, then emits the whole file. */
typedef struct {
    po_rec       *rec;
    size_t        n, cap;
    po_arena      arena;      /* record payloads: bodies                   */
    po_intern     sym;        /* every string in the segment               */
    po_arena      labels;     /* canonical blocks, owned by the series tab */
    po_series_tab series;
    po_u64        t_min, t_max;
    uint8_t       signal;
    uint32_t      worker_slot;
    uint32_t      tenant_hash;

    /* per-signal blobs, attached by the caller and written verbatim */
    char     *rgn[PO_SEG_MAX_REGIONS];
    size_t    rgn_len[PO_SEG_MAX_REGIONS];
    uint32_t  rgn_kind[PO_SEG_MAX_REGIONS];
    int       nrgn;
    int       rgn_owned[PO_SEG_MAX_REGIONS];
} po_seg_w;

/* Attach a prepared region. The writer takes ownership when `owned` is set,
 * which is what a serialiser that malloc'd its output wants. */
static int po_seg_w_region(po_seg_w *w, uint32_t kind,
                           char *blob, size_t len, int owned) {
    if (w->nrgn >= PO_SEG_MAX_REGIONS) return 0;
    w->rgn[w->nrgn]       = blob;
    w->rgn_len[w->nrgn]   = len;
    w->rgn_kind[w->nrgn]  = kind;
    w->rgn_owned[w->nrgn] = owned;
    w->nrgn++;
    return 1;
}

/* Widen the segment's declared time span to cover something the records
 * region does not.
 *
 * THE FOOTER'S SPAN IS A PROMISE THE PRUNER BELIEVES. `po_seg_overlaps`
 * decides from t_min/t_max alone whether a segment is worth opening, so a
 * segment whose metric chunks or log blocks reach outside the span its
 * records declare is a segment a correct query will skip. That is a silent
 * loss of data, not a slow query, so anything attached as a region widens the
 * span here. */
static void po_seg_w_span(po_seg_w *w, po_u64 t_min, po_u64 t_max) {
    if (t_min < w->t_min) w->t_min = t_min;
    if (t_max > w->t_max) w->t_max = t_max;
}

static int po_seg_w_init(po_seg_w *w, uint8_t signal, uint32_t slot,
                         const char *tenant, size_t tlen) {
    memset(w, 0, sizeof(*w));
    w->cap = 256;
    w->rec = (po_rec *)malloc(w->cap * sizeof(po_rec));
    if (!w->rec) return 0;
    if (!po_arena_init(&w->arena, 4096))  goto fail1;
    if (!po_intern_init(&w->sym, 256))    goto fail2;
    if (!po_arena_init(&w->labels, 4096)) goto fail3;
    if (!po_series_tab_init(&w->series, &w->labels, 256)) goto fail4;
    w->signal      = signal;
    w->worker_slot = slot;
    w->tenant_hash = po_hash32(tenant ? tenant : "", tenant ? tlen : 0);
    w->t_min       = PO_U64_MAX;
    w->t_max       = 0;
    return 1;
fail4: po_arena_free(&w->labels);
fail3: po_intern_free(&w->sym);
fail2: po_arena_free(&w->arena);
fail1: free(w->rec); w->rec = NULL;
    return 0;
}

static void po_seg_w_free(po_seg_w *w) {
    int i;
    for (i = 0; i < w->nrgn; i++)
        if (w->rgn_owned[i]) free(w->rgn[i]);
    w->nrgn = 0;
    free(w->rec); w->rec = NULL;
    po_arena_free(&w->arena);
    po_intern_free(&w->sym);
    po_series_tab_free(&w->series);
    po_arena_free(&w->labels);
    w->n = w->cap = 0;
}

/* Add a record, interning its body and its label block. `created` reports
 * whether the series is new, which is the only moment the cardinality cap can
 * be enforced. */
static int po_seg_w_add(po_seg_w *w, const po_rec *src,
                        const char *body, uint32_t body_len,
                        const char *labels, uint32_t labels_len,
                        int *series_created) {
    po_rec *r;
    uint32_t slot;
    po_h128 id;

    if (w->n == w->cap) {
        size_t want = w->cap * 2;
        po_rec *nr = (po_rec *)realloc(w->rec, want * sizeof(po_rec));
        if (!nr) return 0;
        w->rec = nr; w->cap = want;
    }

    slot = po_series_intern(&w->series, labels, labels_len, &id, series_created);
    if (slot == PO_SERIES_ERR) return 0;

    r = &w->rec[w->n];
    *r = *src;
    r->series = po_series_key(id);

    if (body_len) {
        uint32_t sym = po_intern_put(&w->sym, body, body_len);
        if (sym == PO_SYM_NONE) return 0;
        /* The body becomes a SYMBOL id, not a copy. body_len is repurposed as
         * a marker that the field is a symbol reference; the reader resolves
         * through the segment's table. */
        r->body_off = sym;
        r->body_len = 0;
    }
    r->attr_off = labels_len ? po_arena_put(&w->arena, labels, labels_len) : 0;
    if (labels_len && r->attr_off == PO_ARENA_ERR) return 0;
    r->attr_len = labels_len;

    if (r->t_unix_nano < w->t_min) w->t_min = r->t_unix_nano;
    if (r->t_unix_nano > w->t_max) w->t_max = r->t_unix_nano;
    w->n++;
    return 1;
}

static int po_write_all_fd(int fd, const char *p, size_t n) {
    while (n) {
        ssize_t k = write(fd, p, n);
        if (k < 0) { if (errno == EINTR) continue; return 0; }
        if (k == 0) return 0;
        p += (size_t)k; n -= (size_t)k;
    }
    return 1;
}

/* Write the segment to `path`, atomically.
 *
 * .tmp in the SAME DIRECTORY as the destination, because rename is atomic
 * within a filesystem and not across one. Then fsync the file, rename, and
 * fsync the DIRECTORY - without that last one the rename itself can be lost
 * on a crash even though the data was not. */
static int po_seg_write(po_seg_w *w, const char *path, const uint8_t ulid[16]) {
    char tmp[4096];
    int fd;
    size_t symlen, reclen, arlen;
    char hdr[PO_SEG_HDR], foot[PO_SEG_FOOT];
    uint32_t crc = 0;
    po_u64 off_rec, off_ar, off_sym, off_tab = 0;
    uint32_t n_tab = 0;

    if (strlen(path) + 5 >= sizeof(tmp)) { errno = ENAMETOOLONG; return 0; }
    sprintf(tmp, "%s.tmp", path);

    reclen = w->n * sizeof(po_rec);
    arlen  = w->arena.len;
    symlen = po_intern_size(&w->sym);

    off_rec = PO_SEG_HDR;
    off_ar  = off_rec + reclen;
    off_sym = off_ar + arlen;

    {   /* header */
        char *q = hdr;
        uint32_t u32; uint16_t u16; po_u64 u64;
        memset(hdr, 0, sizeof(hdr));
        u32 = po_le32(PO_SEG_MAGIC);   memcpy(q, &u32, 4); q += 4;
        u16 = PO_SEG_VERSION;          q[0] = (char)(u16 & 0xFF);
                                       q[1] = (char)(u16 >> 8); q += 2;
        *q++ = (char)w->signal;
        *q++ = 0;                                          /* flags */
        u32 = po_le32(w->tenant_hash); memcpy(q, &u32, 4); q += 4;
        u32 = po_le32(w->worker_slot); memcpy(q, &u32, 4); q += 4;
        u64 = po_le64(w->n ? w->t_min : 0); memcpy(q, &u64, 8); q += 8;
        u64 = po_le64(w->t_max);            memcpy(q, &u64, 8); q += 8;
        u64 = po_le64((po_u64)w->n);        memcpy(q, &u64, 8); q += 8;
        memcpy(q, ulid, 16);                q += 16;
    }

    crc = po_crc32c(0, hdr, PO_SEG_HDR);
    if (reclen) crc = po_crc32c(crc, w->rec, reclen);
    if (arlen)  crc = po_crc32c(crc, w->arena.base, arlen);

#ifdef _WIN32
    fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC | O_BINARY, 0644);
#else
    fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0644);
#endif
    if (fd < 0) return 0;

    if (!po_write_all_fd(fd, hdr, PO_SEG_HDR)) goto fail;
    if (reclen && !po_write_all_fd(fd, (const char *)w->rec, reclen)) goto fail;
    if (arlen  && !po_write_all_fd(fd, w->arena.base, arlen)) goto fail;
    {
        char *sb = (char *)malloc(symlen);
        int ok;
        if (!sb) goto fail;
        po_intern_write(&w->sym, sb);
        crc = po_crc32c(crc, sb, symlen);
        ok = po_write_all_fd(fd, sb, symlen);
        free(sb);
        if (!ok) goto fail;
    }

    /* the per-signal regions, then the table that locates them */
    {
        po_u64 at = off_sym + symlen;
        po_region tab[PO_SEG_MAX_REGIONS];
        int i;
        char *tbuf;
        size_t tlen;

        for (i = 0; i < w->nrgn; i++) {
            tab[i].kind = w->rgn_kind[i];
            tab[i].off  = at;
            tab[i].len  = (po_u64)w->rgn_len[i];
            if (w->rgn_len[i]) {
                crc = po_crc32c(crc, w->rgn[i], w->rgn_len[i]);
                if (!po_write_all_fd(fd, w->rgn[i], w->rgn_len[i])) goto fail;
            }
            at += w->rgn_len[i];
        }

        tlen = (size_t)w->nrgn * 20;
        off_tab = at;
        tbuf = (char *)malloc(tlen ? tlen : 1);
        if (!tbuf) goto fail;
        for (i = 0; i < w->nrgn; i++) {
            uint32_t k = po_le32(tab[i].kind);
            po_u64   o = po_le64(tab[i].off);
            po_u64   l = po_le64(tab[i].len);
            memcpy(tbuf + i * 20,      &k, 4);
            memcpy(tbuf + i * 20 + 4,  &o, 8);
            memcpy(tbuf + i * 20 + 12, &l, 8);
        }
        if (tlen) crc = po_crc32c(crc, tbuf, tlen);
        if (tlen && !po_write_all_fd(fd, tbuf, tlen)) { free(tbuf); goto fail; }
        free(tbuf);
        n_tab = (uint32_t)w->nrgn;
    }

    {   /* footer, and the magic is the LAST four bytes of the file */
        char *q = foot;
        uint32_t u32; po_u64 u64;
        memset(foot, 0, sizeof(foot));
        u32 = po_le32(PO_FOOT_MAGIC); memcpy(q, &u32, 4); q += 4;
        u64 = po_le64(off_rec); memcpy(q, &u64, 8); q += 8;
        u64 = po_le64((po_u64)reclen); memcpy(q, &u64, 8); q += 8;
        u64 = po_le64(off_ar);  memcpy(q, &u64, 8); q += 8;
        u64 = po_le64((po_u64)arlen);  memcpy(q, &u64, 8); q += 8;
        u64 = po_le64(off_sym); memcpy(q, &u64, 8); q += 8;
        u64 = po_le64((po_u64)symlen); memcpy(q, &u64, 8); q += 8;
        u32 = po_le32(crc);     memcpy(q, &u32, 4); q += 4;
        u64 = po_le64(off_tab); memcpy(q, &u64, 8); q += 8;
        u32 = po_le32(n_tab);   memcpy(q, &u32, 4); q += 4;
        /* the trailing magic: the ONLY thing that says this file is whole */
        u32 = po_le32(PO_SEG_MAGIC);
        memcpy(foot + PO_SEG_FOOT - 4, &u32, 4);
    }
    if (!po_write_all_fd(fd, foot, PO_SEG_FOOT)) goto fail;

#ifndef _WIN32
    if (fsync(fd) != 0) goto fail;
#endif
    close(fd);

    if (rename(tmp, path) != 0) { unlink(tmp); return 0; }

#ifndef _WIN32
    {   /* fsync the directory, or the rename can be lost on a crash */
        char dir[4096];
        char *slash;
        int dfd;
        strncpy(dir, path, sizeof(dir) - 1);
        dir[sizeof(dir) - 1] = '\0';
        slash = strrchr(dir, '/');
        if (slash) { *slash = '\0'; } else { strcpy(dir, "."); }
        dfd = open(dir, O_RDONLY);
        if (dfd >= 0) { fsync(dfd); close(dfd); }
    }
#endif
    return 1;

fail:
    close(fd);
    unlink(tmp);
    return 0;
}

/* ---- reading ------------------------------------------------------------- */

typedef struct {
    const char    *base;
    size_t         len;
    int            fd;
    int            mapped;
    po_seg_hdr     hdr;
    const po_rec  *rec;
    size_t         n;
    const char    *arena;
    size_t         arena_len;
    po_intern_view sym;
    po_region      rgn[PO_SEG_MAX_REGIONS];
    int            nrgn;
} po_seg_r;

/* Find a region by kind. Returns NULL when this segment does not carry one,
 * which is the normal answer for a signal it does not hold. */
static const po_region *po_seg_region(const po_seg_r *s, uint32_t kind) {
    int i;
    for (i = 0; i < s->nrgn; i++) if (s->rgn[i].kind == kind) return &s->rgn[i];
    return NULL;
}

static const char *po_seg_region_ptr(const po_seg_r *s, uint32_t kind,
                                     size_t *len) {
    const po_region *r = po_seg_region(s, kind);
    if (!r) { if (len) *len = 0; return NULL; }
    if (len) *len = (size_t)r->len;
    return s->base + r->off;
}

/* Validate an in-memory image. Separated from the mmap so a test can feed it
 * a deliberately damaged buffer without touching a filesystem. */
static int po_seg_parse(po_seg_r *s, const char *p, size_t len) {
    uint32_t magic, tail, crc, want;
    po_u64 off_rec, len_rec, off_ar, len_ar, off_sym, len_sym, off_tab;
    uint32_t n_tab;
    const char *f;

    memset(&s->hdr, 0, sizeof(s->hdr));
    if (len < PO_SEG_HDR + PO_SEG_FOOT) return 0;

    memcpy(&magic, p, 4);
    if (po_le32(magic) != PO_SEG_MAGIC) return 0;

    /* The trailing magic FIRST. This is the cheap question - is the file
     * whole - and everything else is only worth asking once it is yes. */
    memcpy(&tail, p + len - 4, 4);
    if (po_le32(tail) != PO_SEG_MAGIC) return 0;

    f = p + len - PO_SEG_FOOT;
    memcpy(&magic, f, 4);
    if (po_le32(magic) != PO_FOOT_MAGIC) return 0;

    memcpy(&off_rec, f + 4,  8); off_rec = po_le64(off_rec);
    memcpy(&len_rec, f + 12, 8); len_rec = po_le64(len_rec);
    memcpy(&off_ar,  f + 20, 8); off_ar  = po_le64(off_ar);
    memcpy(&len_ar,  f + 28, 8); len_ar  = po_le64(len_ar);
    memcpy(&off_sym, f + 36, 8); off_sym = po_le64(off_sym);
    memcpy(&len_sym, f + 44, 8); len_sym = po_le64(len_sym);
    memcpy(&crc,     f + 52, 4); crc     = po_le32(crc);
    memcpy(&off_tab, f + 56, 8); off_tab = po_le64(off_tab);
    memcpy(&n_tab,   f + 64, 4); n_tab   = po_le32(n_tab);

    /* Every region must lie inside the file. A footer that points outside it
     * is a corrupt footer, not a large segment.
     *
     * WRITTEN AS SUBTRACTION, DELIBERATELY. `off + len > file_len` OVERFLOWS
     * in a uint64_t: a corrupt footer claiming an offset near 2^64 wraps the
     * sum to something small, the check passes, and the read runs off the end
     * of the mapping - which is a SIGBUS, not an error return. That is the
     * exact failure this format exists to make impossible, and the first cut
     * of the region table reintroduced it. */
#define PO_IN_FILE(off, l) ((off) <= len && (l) <= len - (off))
    if (!PO_IN_FILE(off_rec, len_rec) || !PO_IN_FILE(off_ar, len_ar)
        || !PO_IN_FILE(off_sym, len_sym)) return 0;
    if (off_rec != PO_SEG_HDR) return 0;
    if (len_rec % sizeof(po_rec)) return 0;

    if (n_tab > PO_SEG_MAX_REGIONS) return 0;
    if (n_tab && !PO_IN_FILE(off_tab, (po_u64)n_tab * 20)) return 0;

    want = po_crc32c(0, p, PO_SEG_HDR);
    if (len_rec) want = po_crc32c(want, p + off_rec, (size_t)len_rec);
    if (len_ar)  want = po_crc32c(want, p + off_ar,  (size_t)len_ar);
    if (len_sym) want = po_crc32c(want, p + off_sym, (size_t)len_sym);
    {
        uint32_t i;
        for (i = 0; i < n_tab; i++) {
            po_u64 o, l;
            memcpy(&o, p + off_tab + i * 20 + 4,  8); o = po_le64(o);
            memcpy(&l, p + off_tab + i * 20 + 12, 8); l = po_le64(l);
            /* Same subtraction, same reason. */
            if (!PO_IN_FILE(o, l)) return 0;
            if (l) want = po_crc32c(want, p + o, (size_t)l);
        }
        if (n_tab) want = po_crc32c(want, p + off_tab, (size_t)n_tab * 20);
    }
    if (want != crc) return 0;

    {
        uint16_t v;
        memcpy(&s->hdr.magic, p, 4); s->hdr.magic = po_le32(s->hdr.magic);
        v = (uint16_t)((unsigned char)p[4] | ((unsigned char)p[5] << 8));
        s->hdr.version = v;
        s->hdr.signal  = (uint8_t)p[6];
        s->hdr.flags   = (uint8_t)p[7];
        memcpy(&s->hdr.tenant_hash, p + 8,  4);
        s->hdr.tenant_hash = po_le32(s->hdr.tenant_hash);
        memcpy(&s->hdr.worker_slot, p + 12, 4);
        s->hdr.worker_slot = po_le32(s->hdr.worker_slot);
        memcpy(&s->hdr.t_min,   p + 16, 8); s->hdr.t_min   = po_le64(s->hdr.t_min);
        memcpy(&s->hdr.t_max,   p + 24, 8); s->hdr.t_max   = po_le64(s->hdr.t_max);
        memcpy(&s->hdr.records, p + 32, 8); s->hdr.records = po_le64(s->hdr.records);
        memcpy(s->hdr.ulid, p + 40, 16);
    }

    s->base      = p;
    s->len       = len;
    s->rec       = (const po_rec *)(p + off_rec);
    s->n         = (size_t)(len_rec / sizeof(po_rec));
    s->arena     = p + off_ar;
    s->arena_len = (size_t)len_ar;
    if (!po_intern_open(&s->sym, p + off_sym, (size_t)len_sym)) return 0;
    if (s->hdr.records != (po_u64)s->n) return 0;

    s->nrgn = (int)n_tab;
    {
        uint32_t i;
        for (i = 0; i < n_tab; i++) {
            uint32_t k; po_u64 o, l;
            memcpy(&k, p + off_tab + i * 20,      4); s->rgn[i].kind = po_le32(k);
            memcpy(&o, p + off_tab + i * 20 + 4,  8); s->rgn[i].off  = po_le64(o);
            memcpy(&l, p + off_tab + i * 20 + 12, 8); s->rgn[i].len  = po_le64(l);
        }
    }
    return 1;
#undef PO_IN_FILE
}

/* mmap a segment read-only.
 *
 * PROT_READ, MAP_SHARED: safe across fork, and page-cache backed so N workers
 * mapping the same segment cost one copy between them. */
static int po_seg_open(po_seg_r *s, const char *path) {
#ifndef _WIN32
    struct stat st;
    void *m;
    int fd = open(path, O_RDONLY);
    memset(s, 0, sizeof(*s));
    s->fd = -1;
    if (fd < 0) return 0;
    if (fstat(fd, &st) != 0 || st.st_size <= 0) { close(fd); return 0; }
    m = mmap(NULL, (size_t)st.st_size, PROT_READ, MAP_SHARED, fd, 0);
    if (m == MAP_FAILED) { close(fd); return 0; }
    if (!po_seg_parse(s, (const char *)m, (size_t)st.st_size)) {
        munmap(m, (size_t)st.st_size);
        close(fd);
        return 0;
    }
    s->fd = fd;
    s->mapped = 1;
    return 1;
#else
    (void)s; (void)path;
    return 0;
#endif
}

static void po_seg_close(po_seg_r *s) {
#ifndef _WIN32
    if (s->mapped && s->base) munmap((void *)s->base, s->len);
#endif
    if (s->fd >= 0) close(s->fd);
    s->base = NULL; s->fd = -1; s->mapped = 0;
}

/* Does this segment's time span overlap the query's? THIS is the pruning that
 * makes everything else affordable: list the directory, read the footer, open
 * the two that overlap instead of a week's worth. */
static int po_seg_overlaps(const po_seg_r *s, po_u64 from, po_u64 to) {
    return s->hdr.t_min <= to && s->hdr.t_max >= from;
}

#endif /* PO_SEG_H */
