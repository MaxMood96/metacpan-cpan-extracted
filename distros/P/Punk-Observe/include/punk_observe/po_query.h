/* po_query.h - the AST, and the column table that validates it.
 *
 * ONE LANGUAGE, THREE SOURCES. A source verb, then stages every signal
 * shares:
 *
 *     <source> [selector] | stage | stage | ...
 *
 * Every stage takes a row stream and returns a row stream. `where` filters,
 * `by` groups, `count`/`p95` reduce - ONE implementation each, working on a
 * log because a log line is a row and on a span because a span is a row.
 *
 * The signals differ only in WHICH COLUMNS EXIST, and checking that is this
 * file's job.
 *
 *     log | where duration > 5s
 *
 * is a parse error naming the column and the source. It is NOT an empty
 * result - an empty result for a nonsensical query is the worst outcome
 * available, because it looks like an answer.
 */
#ifndef PO_QUERY_H
#define PO_QUERY_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_lex.h"

/* sources */
#define PO_SRC_METRIC 1
#define PO_SRC_LOG    2
#define PO_SRC_TRACE  3
#define PO_SRC_SPAN   4     /* spans as rows, for span-level aggregation */

/* stages */
#define PO_ST_WHERE     1
#define PO_ST_SEARCH    2
#define PO_ST_BY        3
#define PO_ST_AGG       4
#define PO_ST_RATE      5
#define PO_ST_TOPN      6
#define PO_ST_SLOWEST   7
#define PO_ST_LIMIT     8
#define PO_ST_SORT      9
#define PO_ST_EXEMPLARS 10
#define PO_ST_TRACES    11
#define PO_ST_LOGS      12
#define PO_ST_SPANS     13
#define PO_ST_BUCKET    14

/* aggregates */
#define PO_AGG_COUNT 1
#define PO_AGG_SUM   2
#define PO_AGG_AVG   3
#define PO_AGG_MIN   4
#define PO_AGG_MAX   5
#define PO_AGG_P50   6
#define PO_AGG_P90   7
#define PO_AGG_P95   8
#define PO_AGG_P99   9
#define PO_AGG_DISTINCT 10

/* value kinds in a predicate */
#define PO_V_STRING   1
#define PO_V_NUMBER   2
#define PO_V_DURATION 3
#define PO_V_SEVERITY 4

/* expression node kinds */
#define PO_E_AND 1
#define PO_E_OR  2
#define PO_E_NOT 3
#define PO_E_CMP 4

typedef struct po_expr {
    int kind;
    struct po_expr *a, *b;      /* AND/OR: both; NOT: a */
    /* CMP: */
    const char *field; size_t field_len;
    int  op;
    int  vkind;
    const char *sval; size_t sval_len;
    double nval;
    po_u64 uval;                /* duration ns, severity, or exact integer */
} po_expr;

typedef struct po_stage {
    int kind;
    struct po_stage *next;

    po_expr *expr;              /* WHERE */
    const char *str; size_t str_len;   /* SEARCH */
    int  agg;                   /* AGG, TOPN, BUCKET, RATE */
    po_u64 dur;                 /* BUCKET and RATE window, ns */
    po_u64 num;                 /* LIMIT, TOPN, SLOWEST */
    const char *fields[8]; size_t field_lens[8]; int nfields;  /* BY, SORT */
    int  desc;                  /* SORT */
} po_stage;

/* A CHUNKED bump allocator, and the chunking is the point.
 *
 * The obvious move is to allocate nodes out of po_arena, which is what the
 * first draft did. It is WRONG: po_arena reallocs as it grows, so every node
 * handed out before a growth dangles the moment the tree gets big enough -
 * and "big enough" means a real query rather than a test one. Exactly the
 * bug phase 3 hit with JSON attributes pointing into a growing arena.
 *
 * Chunks are allocated and never moved. The whole tree still frees in one
 * call, which is the property the arena was wanted for. */
#define PO_BUMP_CHUNK 8192

typedef struct po_chunk {
    struct po_chunk *next;
    size_t used, cap;
    char   mem[1];              /* over-allocated */
} po_chunk;

typedef struct { po_chunk *head; } po_bump;

static void *po_bump_alloc(po_bump *b, size_t n) {
    n = (n + 7) & ~(size_t)7;                 /* 8-byte aligned */
    if (!b->head || b->head->used + n > b->head->cap) {
        size_t cap = n > PO_BUMP_CHUNK ? n : PO_BUMP_CHUNK;
        po_chunk *c = (po_chunk *)malloc(sizeof(po_chunk) + cap);
        if (!c) return NULL;
        c->next = b->head;
        c->used = 0;
        c->cap  = cap;
        b->head = c;
    }
    {
        void *p = b->head->mem + b->head->used;
        b->head->used += n;
        memset(p, 0, n);
        return p;
    }
}

static void po_bump_free(po_bump *b) {
    po_chunk *c = b->head;
    while (c) { po_chunk *n = c->next; free(c); c = n; }
    b->head = NULL;
}

typedef struct {
    int source;
    const char *name; size_t name_len;   /* metric name */
    po_expr  *selector;                  /* {a="b"} sugar, folded to a where */
    po_stage *stages;
    /* everything above is allocated in this bump and freed with it */
    po_bump   bump;
    char      err[256];
    size_t    err_off;
    int       failed;
} po_query;

static void po_query_free(po_query *q) { po_bump_free(&q->bump); }

/* ---- the column table ------------------------------------------------------
 *
 * Which columns exist on which source. This is the table from the plan, in
 * code, and it is what turns a nonsensical query into a named error.
 */
#define PO_C_ANY    0x0F        /* t, labels, attributes: every source */
#define PO_C_METRIC 0x01
#define PO_C_LOG    0x02
#define PO_C_TRACE  0x04
#define PO_C_SPAN   0x08

typedef struct { const char *name; int sources; } po_column;

static const po_column PO_COLUMNS[] = {
    { "t",          PO_C_ANY },
    { "time",       PO_C_ANY },
    { "service",    PO_C_ANY },
    { "value",      PO_C_METRIC },
    { "body",       PO_C_LOG },
    { "severity",   PO_C_LOG },
    { "duration",   PO_C_TRACE | PO_C_SPAN },
    { "name",       PO_C_TRACE | PO_C_SPAN },
    { "status",     PO_C_TRACE | PO_C_SPAN },
    { "kind",       PO_C_TRACE | PO_C_SPAN },
    { "trace_id",   PO_C_LOG | PO_C_TRACE | PO_C_SPAN },
    { "span_id",    PO_C_LOG | PO_C_TRACE | PO_C_SPAN },
    { NULL, 0 }
};

static int po_src_bit(int src) {
    switch (src) {
        case PO_SRC_METRIC: return PO_C_METRIC;
        case PO_SRC_LOG:    return PO_C_LOG;
        case PO_SRC_TRACE:  return PO_C_TRACE;
        case PO_SRC_SPAN:   return PO_C_SPAN;
        default: return 0;
    }
}

static const char *po_src_name(int src) {
    switch (src) {
        case PO_SRC_METRIC: return "metric";
        case PO_SRC_LOG:    return "log";
        case PO_SRC_TRACE:  return "trace";
        case PO_SRC_SPAN:   return "spans";
        default: return "?";
    }
}

/* Returns 1 if the column exists on this source, 0 if it exists on ANOTHER
 * source (so the error can say which), -1 if it is not a known column at all.
 *
 * An unknown name is NOT an error: it is an attribute. Attributes are
 * open-ended by nature, so only the RESERVED column names are checked. */
static int po_column_ok(const char *f, size_t len, int src, int *elsewhere) {
    int i;
    if (elsewhere) *elsewhere = 0;
    for (i = 0; PO_COLUMNS[i].name; i++) {
        size_t n = strlen(PO_COLUMNS[i].name);
        if (n == len && memcmp(PO_COLUMNS[i].name, f, len) == 0) {
            if (PO_COLUMNS[i].sources & po_src_bit(src)) return 1;
            if (elsewhere) *elsewhere = PO_COLUMNS[i].sources;
            return 0;
        }
    }
    return -1;                  /* an attribute; fine anywhere */
}

/* OTLP severity names, on the 24-point scale. `severity >= error` is a
 * NUMERIC comparison, not a string match on a level name. */
static int po_severity_value(const char *p, size_t len, po_u64 *out) {
    struct { const char *n; int v; } S[] = {
        { "trace", 1 }, { "debug", 5 }, { "info", 9 },
        { "warn", 13 }, { "warning", 13 },
        { "error", 17 }, { "fatal", 21 }, { NULL, 0 }
    };
    int i;
    for (i = 0; S[i].n; i++) {
        size_t n = strlen(S[i].n);
        if (n == len) {
            size_t k; int eq = 1;
            for (k = 0; k < len; k++) {
                char a = p[k], b = S[i].n[k];
                if (a >= 'A' && a <= 'Z') a = (char)(a - 'A' + 'a');
                if (a != b) { eq = 0; break; }
            }
            if (eq) { *out = (po_u64)S[i].v; return 1; }
        }
    }
    return 0;
}

#endif /* PO_QUERY_H */
