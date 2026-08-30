/* po_row.h - the one row shape every operator moves.
 *
 * This is phase 0's record decision arriving where it pays off. `where`,
 * `by`, `count` and `p95` are ONE implementation each because a log line is a
 * row and a span is a row and a metric point is a row. The signals differ in
 * which fields are populated, not in what a row is.
 *
 * Strings are (pointer, length) into memory the caller owns for the life of
 * the query - a segment mapping, or a seeded buffer. Nothing here allocates
 * per row; a scan over a million rows must not be a million mallocs.
 */
#ifndef PO_ROW_H
#define PO_ROW_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_rec.h"

#define PO_ROW_ATTRS 8

typedef struct {
    const char *key; size_t key_len;
    const char *val; size_t val_len;
} po_kv;

typedef struct {
    po_u64  t;
    int     kind;             /* PO_METRIC | PO_LOG | PO_SPAN */

    double  value;            /* metric */
    int     value_is_int;
    po_u64  ivalue;

    const char *body; size_t body_len;    /* log body, span name, metric name */
    uint16_t severity;                    /* log */
    po_u64   duration;                    /* span */
    uint8_t  status, span_kind;           /* span */

    po_u64  trace_hi, trace_lo, span_id;
    const char *service; size_t service_len;

    po_kv   attr[PO_ROW_ATTRS];
    int     nattr;
} po_row;

/* An identifier the way a person typed it, as the two integers a row holds.
 *
 * BOTH SPELLINGS, because both are things somebody pastes: 32 hex characters
 * is the wire form every other tool prints, and `<hi>-<lo>` decimal is what
 * this UI's own links carry. A span id is a single decimal integer.
 *
 * Returns 0 for anything that is not an identifier at all, which the caller
 * turns into a predicate that matches nothing - the same answer as before,
 * but now reached because the input was not an id rather than because the
 * column could not be read.
 *
 * The Perl side has the same parse in povw_trace_id_c, on SVs. This one is
 * plain bytes so that the ROW layer can use it, and so the literal is parsed
 * ONCE when the query is planned rather than once per row scanned. */
static int po_parse_id(const char *p, size_t len, po_u64 *hi, po_u64 *lo) {
    size_t i, start = 0, end;

    *hi = 0; *lo = 0;
    if (!p) return 0;
    while (start < len && (p[start] == ' ' || p[start] == '\t')) start++;
    end = len;
    while (end > start && (p[end - 1] == ' ' || p[end - 1] == '\t')) end--;
    p += start;
    len = end - start;
    if (!len) return 0;

    if (len == 32) {                       /* the wire form */
        po_u64 h = 0, l = 0;
        for (i = 0; i < 32; i++) {
            int d;
            char c = p[i];
            if      (c >= '0' && c <= '9') d = c - '0';
            else if (c >= 'a' && c <= 'f') d = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') d = c - 'A' + 10;
            else goto decimal;
            if (i < 16) h = (h << 4) | (po_u64)d;
            else        l = (l << 4) | (po_u64)d;
        }
        *hi = h; *lo = l;
        return (h || l) ? 1 : 0;           /* an all-zero id is not one */
    }

decimal:
    {   /* `<hi>-<lo>`, or a bare integer for a span id */
        size_t dash = 0;
        int found = 0;
        po_u64 a = 0, b = 0;
        for (i = 0; i < len; i++) if (p[i] == '-') { dash = i; found = 1; break; }
        for (i = 0; i < len; i++) {
            if (found && i == dash) continue;
            if (p[i] < '0' || p[i] > '9') return 0;
        }
        if (!found) {
            for (i = 0; i < len; i++) b = b * 10 + (po_u64)(p[i] - '0');
            *hi = 0; *lo = b;
            return 1;
        }
        if (!dash || dash + 1 >= len) return 0;
        for (i = 0; i < dash; i++)    a = a * 10 + (po_u64)(p[i] - '0');
        for (i = dash + 1; i < len; i++) b = b * 10 + (po_u64)(p[i] - '0');
        *hi = a; *lo = b;
        return (a || b) ? 1 : 0;
    }
}

/* Does this field name an identifier column? */
#define PO_IS_TRACE_ID(f, n) ((n) == 8 && memcmp((f), "trace_id", 8) == 0)
#define PO_IS_SPAN_ID(f, n)  ((n) == 7 && memcmp((f), "span_id",  7) == 0)

static const char *po_row_str(const po_row *r, const char *f, size_t flen,
                              size_t *out_len) {
    int i;
    if (flen == 4 && memcmp(f, "body", 4) == 0) { *out_len = r->body_len; return r->body; }
    if (flen == 7 && memcmp(f, "service", 7) == 0) { *out_len = r->service_len; return r->service; }
    if (flen == 4 && memcmp(f, "name", 4) == 0) { *out_len = r->body_len; return r->body; }
    for (i = 0; i < r->nattr; i++)
        if (r->attr[i].key_len == flen && memcmp(r->attr[i].key, f, flen) == 0) {
            *out_len = r->attr[i].val_len;
            return r->attr[i].val;
        }
    *out_len = 0;
    return NULL;
}

/* Numeric field access. Returns 1 if the field has a numeric meaning on this
 * row, so a comparison against a missing field is FALSE rather than zero -
 * `where duration > 0` must not match a row that has no duration. */
static int po_row_num(const po_row *r, const char *f, size_t flen, double *out) {
    if (flen == 5 && memcmp(f, "value", 5) == 0) {
        *out = r->value_is_int ? (double)r->ivalue : r->value;
        return r->kind == PO_METRIC;
    }
    if (flen == 8 && memcmp(f, "duration", 8) == 0) {
        *out = (double)r->duration;
        return r->kind == PO_SPAN;
    }
    if (flen == 8 && memcmp(f, "severity", 8) == 0) {
        *out = (double)r->severity;
        return r->kind == PO_LOG;
    }
    /* THE TWO SPAN COLUMNS THE ROW COULD NOT ANSWER.
     *
     * `status` and `kind` are declared columns for the trace and span sources
     * - the parser accepts them and validates them - and this function did
     * not know either. So `where status == 2` compared against a field that
     * did not exist, which is FALSE for every row: a filter for the failures
     * matched nothing at all, on a store holding forty-seven of them, and
     * said so by returning zero rather than by refusing.
     *
     * A column the language admits and the row cannot answer is worse than
     * one it rejects: a rejected column is a message, an unanswerable one is
     * an empty result that looks like an answer. */
    if (flen == 6 && memcmp(f, "status", 6) == 0) {
        *out = (double)r->status;
        return r->kind == PO_SPAN;
    }
    if (flen == 4 && memcmp(f, "kind", 4) == 0) {
        *out = (double)r->span_kind;
        return r->kind == PO_SPAN;
    }
    if (flen == 1 && f[0] == 't') { *out = (double)r->t; return 1; }
    if (flen == 4 && memcmp(f, "time", 4) == 0) { *out = (double)r->t; return 1; }
    {   /* a numeric-looking attribute */
        size_t vl;
        const char *v = po_row_str(r, f, flen, &vl);
        if (v && vl) {
            double acc = 0; size_t i; int any = 0, neg = 0, dot = 0; double frac = 0.1;
            for (i = 0; i < vl; i++) {
                if (i == 0 && v[i] == '-') { neg = 1; continue; }
                if (v[i] == '.' && !dot) { dot = 1; continue; }
                if (v[i] < '0' || v[i] > '9') return 0;
                if (!dot) acc = acc * 10 + (v[i] - '0');
                else { acc += (v[i] - '0') * frac; frac /= 10; }
                any = 1;
            }
            if (any) { *out = neg ? -acc : acc; return 1; }
        }
    }
    return 0;
}

/* ---- ordering ------------------------------------------------------------
 *
 * A row is 200-odd bytes and a result set is bounded by the planner's budget,
 * so this sorts the ROWS rather than an index into them: one memcpy per swap
 * against an indirection on every comparison and every read afterwards.
 *
 * A plain insertion sort would be quadratic on the case that matters - the
 * store hands rows over in time order, and `slowest` wants them in duration
 * order, so the input is arbitrary with respect to the key. This is a
 * bottom-up merge, which is O(n log n) whatever the input looks like and,
 * unlike quicksort, has no arrangement that degrades it.
 */
typedef int (*po_row_cmp_fn)(const po_row *a, const po_row *b, void *ud);

static void po_rows_merge(po_row *src, po_row *dst, size_t lo, size_t mid,
                          size_t hi, po_row_cmp_fn cmp, void *ud) {
    size_t i = lo, j = mid, k = lo;
    while (i < mid && j < hi)
        dst[k++] = cmp(&src[j], &src[i], ud) < 0 ? src[j++] : src[i++];
    while (i < mid) dst[k++] = src[i++];
    while (j < hi)  dst[k++] = src[j++];
}

static void po_rows_sort(po_row *rows, size_t n, po_row_cmp_fn cmp, void *ud) {
    po_row *buf, *a = rows, *b;
    size_t width;

    if (n < 2) return;
    buf = (po_row *)malloc(n * sizeof(po_row));
    if (!buf) return;            /* unsorted beats not answering */
    b = buf;

    for (width = 1; width < n; width *= 2) {
        size_t lo;
        for (lo = 0; lo < n; lo += 2 * width) {
            size_t mid = lo + width < n ? lo + width : n;
            size_t hi  = lo + 2 * width < n ? lo + 2 * width : n;
            po_rows_merge(a, b, lo, mid, hi, cmp, ud);
        }
        { po_row *t = a; a = b; b = t; }
    }
    if (a != rows) memcpy(rows, a, n * sizeof(po_row));
    free(buf);
}

/* Longest first. A row with no duration - a log line, a metric point - sorts
 * to the BOTTOM rather than being treated as zero-length, because "the
 * slowest" of a set that has no durations in it is not the first row of it. */
static int po_row_cmp_dur(const po_row *a, const po_row *b, void *ud) {
    po_u64 da = (a->kind == PO_SPAN) ? a->duration : 0;
    po_u64 db = (b->kind == PO_SPAN) ? b->duration : 0;
    (void)ud;
    if (da != db) return da > db ? -1 : 1;
    /* A stable tie-break, so two runs of the same query agree. */
    if (a->t != b->t) return a->t > b->t ? -1 : 1;
    return 0;
}

static void po_rows_sort_dur(po_row *rows, uint32_t n) {
    po_rows_sort(rows, (size_t)n, po_row_cmp_dur, NULL);
}

/* `sort by <field>`, numerically where the field has a numeric meaning on
 * both rows and by bytes otherwise - which is what makes `sort by service`
 * and `sort by duration` both do the obvious thing. */
typedef struct { const char *f; size_t flen; int desc; } po_row_sort_key;

static int po_row_cmp_field(const po_row *a, const po_row *b, void *ud) {
    po_row_sort_key *k = (po_row_sort_key *)ud;
    double na = 0, nb = 0;
    int ha = po_row_num(a, k->f, k->flen, &na);
    int hb = po_row_num(b, k->f, k->flen, &nb);
    int r = 0;

    if (ha && hb) r = na < nb ? -1 : (na > nb ? 1 : 0);
    else if (ha != hb) r = ha ? -1 : 1;   /* a row missing the field sorts last */
    else {
        size_t la = 0, lb = 0;
        const char *sa = po_row_str(a, k->f, k->flen, &la);
        const char *sb = po_row_str(b, k->f, k->flen, &lb);
        if (!sa && !sb) r = 0;
        else if (!sa) r = 1;
        else if (!sb) r = -1;
        else {
            size_t n = la < lb ? la : lb;
            r = n ? memcmp(sa, sb, n) : 0;
            if (r == 0 && la != lb) r = la < lb ? -1 : 1;
            if (r) r = r < 0 ? -1 : 1;
        }
    }
    if (r == 0) return a->t > b->t ? -1 : (a->t < b->t ? 1 : 0);
    return k->desc ? -r : r;
}

static void po_rows_sort_field(po_row *rows, uint32_t n, const char *f,
                               size_t flen, int desc) {
    po_row_sort_key k;
    k.f = f; k.flen = flen; k.desc = desc;
    po_rows_sort(rows, (size_t)n, po_row_cmp_field, &k);
}

#endif /* PO_ROW_H */
