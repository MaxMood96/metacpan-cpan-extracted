/* po_parse.h - recursive descent, into a bump allocator.
 *
 * The stage list is trivially LL(1); only the `where` expression needs
 * precedence, and that is precedence climbing rather than a generator.
 *
 * EVERY NODE IS BUMP-ALLOCATED. The whole AST frees in one call, there is no
 * ownership question, and no node can outlive the tree. Identifiers are
 * COPIED rather than borrowed from the query string, because the string is
 * an SV that Perl may free while the AST is still being planned.
 *
 * PRECEDENCE: `not` binds tightest, then `and`, then `or`. Getting that wrong
 * does not produce an error, it produces plausible WRONG ANSWERS.
 */
#ifndef PO_PARSE_H
#define PO_PARSE_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_lex.h"
#include "punk_observe/po_query.h"

/* The input is untrusted, so recursion is bounded. A thousand nested
 * parentheses must be a refusal, not a blown C stack. */
#define PO_MAX_DEPTH 64

typedef struct {
    po_lex    lex;
    po_query *q;
    int       depth;
} po_parser;

static void po_perr(po_parser *p, size_t off, const char *fmt, const char *a) {
    if (p->q->failed) return;

    /* THE LEXER'S MESSAGE WINS.
     *
     * When the lexer has already failed, the current token is PO_T_ERROR and
     * the parser will duly complain that it "expected a value" - which is
     * true and useless. The lexer knows it was an unterminated string, or an
     * unknown duration unit, or a lone '!', and it knows where. Reporting the
     * parser's generic disappointment instead throws that away and points at
     * the wrong character. */
    if (p->lex.failed) {
        size_t n = strlen(p->lex.err);
        if (n >= sizeof(p->q->err)) n = sizeof(p->q->err) - 1;
        p->q->failed  = 1;
        p->q->err_off = p->lex.err_off;
        memcpy(p->q->err, p->lex.err, n);
        p->q->err[n] = '\0';
        return;
    }

    p->q->failed  = 1;
    p->q->err_off = off;
    if (a) {
        /* my_snprintf is not available in a plain header; build by hand so
         * nothing here reaches for a Perl-flavoured formatter. */
        size_t n = 0, i;
        for (i = 0; fmt[i] && n < sizeof(p->q->err) - 1; i++) {
            if (fmt[i] == '%' && fmt[i + 1] == 's') {
                size_t k;
                for (k = 0; a[k] && n < sizeof(p->q->err) - 1; k++)
                    p->q->err[n++] = a[k];
                i++;
            }
            else p->q->err[n++] = fmt[i];
        }
        p->q->err[n] = '\0';
    }
    else {
        size_t n = strlen(fmt);
        if (n >= sizeof(p->q->err)) n = sizeof(p->q->err) - 1;
        memcpy(p->q->err, fmt, n);
        p->q->err[n] = '\0';
    }
}

static void *po_alloc(po_parser *p, size_t n) {
    return po_bump_alloc(&p->q->bump, n);
}

/* Copy a token's text into the bump and return a stable pointer.
 *
 * COPIED, not borrowed from the query string: that string is an SV, and Perl
 * may free it while the AST is still being planned. A borrowed field name is
 * a use-after-free that only shows when the caller does something ordinary
 * between parsing and executing. */
static const char *po_intern_tok(po_parser *p, const po_tok *t, size_t *len) {
    char *d = (char *)po_bump_alloc(&p->q->bump, t->len + 1);
    if (!d) return NULL;
    if (t->len) memcpy(d, t->p, t->len);
    d[t->len] = '\0';
    *len = t->len;
    return d;
}

static po_expr *po_parse_or(po_parser *p);

/* field op value */
static po_expr *po_parse_cmp(po_parser *p) {
    po_expr *e;
    po_tok f;

    if (p->lex.cur.kind != PO_T_IDENT) {
        po_perr(p, p->lex.cur.off, "expected a column or attribute name", NULL);
        return NULL;
    }
    f = p->lex.cur;
    po_lex_next(&p->lex);

    if (p->lex.cur.kind != PO_T_OP) {
        po_perr(p, p->lex.cur.off,
                "expected a comparison operator after the field", NULL);
        return NULL;
    }

    e = (po_expr *)po_alloc(p, sizeof(po_expr));
    if (!e) return NULL;
    e->kind  = PO_E_CMP;
    e->op    = p->lex.cur.op;
    e->field = po_intern_tok(p, &f, &e->field_len);
    po_lex_next(&p->lex);

    switch (p->lex.cur.kind) {
        case PO_T_STRING:
            e->vkind = PO_V_STRING;
            e->sval  = po_intern_tok(p, &p->lex.cur, &e->sval_len);
            break;
        case PO_T_NUMBER:
            e->vkind = PO_V_NUMBER;
            e->nval  = p->lex.cur.num;
            e->uval  = p->lex.cur.inum;
            break;
        case PO_T_DURATION:
            e->vkind = PO_V_DURATION;
            e->uval  = p->lex.cur.dur;
            break;
        case PO_T_IDENT: {
            /* A bare word on the right is a SEVERITY name or nothing.
             *
             * It is deliberately NOT an implicit string: `where service = api`
             * looks reasonable and is ambiguous with a column reference, so it
             * is refused with a message saying to quote it. Accepting it would
             * make a typo in a column name silently become a string
             * comparison that never matches. */
            po_u64 sev;
            if (po_severity_value(p->lex.cur.p, p->lex.cur.len, &sev)) {
                e->vkind = PO_V_SEVERITY;
                e->uval  = sev;
            }
            else {
                po_perr(p, p->lex.cur.off,
                        "a bare word is not a value: quote it, as in \"...\"",
                        NULL);
                return NULL;
            }
            break;
        }
        default:
            po_perr(p, p->lex.cur.off, "expected a value", NULL);
            return NULL;
    }
    po_lex_next(&p->lex);
    return e;
}

static po_expr *po_parse_unary(po_parser *p) {
    if (++p->depth > PO_MAX_DEPTH) {
        po_perr(p, p->lex.cur.off, "expression nested too deeply", NULL);
        p->depth--;
        return NULL;
    }
    if (po_tok_is(&p->lex.cur, "not")) {
        po_expr *e = (po_expr *)po_alloc(p, sizeof(po_expr));
        po_lex_next(&p->lex);
        if (!e) { p->depth--; return NULL; }
        e->kind = PO_E_NOT;
        e->a = po_parse_unary(p);
        p->depth--;
        return e->a ? e : NULL;
    }
    if (p->lex.cur.kind == PO_T_LPAREN) {
        po_expr *e;
        po_lex_next(&p->lex);
        e = po_parse_or(p);
        if (!e) { p->depth--; return NULL; }
        if (p->lex.cur.kind != PO_T_RPAREN) {
            po_perr(p, p->lex.cur.off, "expected ')'", NULL);
            p->depth--;
            return NULL;
        }
        po_lex_next(&p->lex);
        p->depth--;
        return e;
    }
    {
        po_expr *e = po_parse_cmp(p);
        p->depth--;
        return e;
    }
}

/* `and` binds tighter than `or`. */
static po_expr *po_parse_and(po_parser *p) {
    po_expr *l = po_parse_unary(p);
    if (!l) return NULL;
    while (po_tok_is(&p->lex.cur, "and")) {
        po_expr *n = (po_expr *)po_alloc(p, sizeof(po_expr));
        po_lex_next(&p->lex);
        if (!n) return NULL;
        n->kind = PO_E_AND;
        n->a = l;
        n->b = po_parse_unary(p);
        if (!n->b) return NULL;
        l = n;
    }
    return l;
}

static po_expr *po_parse_or(po_parser *p) {
    po_expr *l = po_parse_and(p);
    if (!l) return NULL;
    while (po_tok_is(&p->lex.cur, "or")) {
        po_expr *n = (po_expr *)po_alloc(p, sizeof(po_expr));
        po_lex_next(&p->lex);
        if (!n) return NULL;
        n->kind = PO_E_OR;
        n->a = l;
        n->b = po_parse_or(p);   /* right-assoc is fine for a boolean or */
        if (!n->b) return NULL;
        l = n;
    }
    return l;
}

/* Walk an expression checking every field against the source. */
static int po_check_expr(po_parser *p, const po_expr *e, int src) {
    if (!e) return 1;
    if (e->kind == PO_E_CMP) {
        int elsewhere = 0;
        int ok = po_column_ok(e->field, e->field_len, src, &elsewhere);
        if (ok == 0) {
            char msg[192];
            size_t n = 0, i;
            const char *pre = "column '";
            const char *mid = "' does not exist on ";
            const char *suf = " (it belongs to another signal)";
            for (i = 0; pre[i]; i++) msg[n++] = pre[i];
            for (i = 0; i < e->field_len && n < 150; i++) msg[n++] = e->field[i];
            for (i = 0; mid[i]; i++) msg[n++] = mid[i];
            { const char *s = po_src_name(src);
              for (i = 0; s[i]; i++) msg[n++] = s[i]; }
            for (i = 0; suf[i] && n < 190; i++) msg[n++] = suf[i];
            msg[n] = '\0';
            po_perr(p, 0, msg, NULL);
            return 0;
        }
        return 1;
    }
    if (!po_check_expr(p, e->a, src)) return 0;
    if (!po_check_expr(p, e->b, src)) return 0;
    return 1;
}

static int po_agg_of(const po_tok *t) {
    if (po_tok_is(t, "count")) return PO_AGG_COUNT;
    if (po_tok_is(t, "sum"))   return PO_AGG_SUM;
    if (po_tok_is(t, "avg"))   return PO_AGG_AVG;
    if (po_tok_is(t, "min"))   return PO_AGG_MIN;
    if (po_tok_is(t, "max"))   return PO_AGG_MAX;
    if (po_tok_is(t, "p50"))   return PO_AGG_P50;
    if (po_tok_is(t, "p90"))   return PO_AGG_P90;
    if (po_tok_is(t, "p95"))   return PO_AGG_P95;
    if (po_tok_is(t, "p99"))   return PO_AGG_P99;
    if (po_tok_is(t, "distinct")) return PO_AGG_DISTINCT;
    return 0;
}

/* ---- stages ---------------------------------------------------------------
 *
 * THE RE-KEYING RULE, which is the feature.
 *
 * `| traces` needs a trace_id on the incoming rows. Logs and spans have one;
 * `| exemplars` produces one; a bare metric stream does NOT. So
 *
 *     metric x | traces
 *
 * is a parse error, and the message says to add `| exemplars` first. That
 * message is part of the deliverable: this is the thing the whole project is
 * built for, and it has to be discoverable by typing rather than by reading
 * the manual.
 */
static int po_has_trace_key(int src, const po_stage *upto) {
    const po_stage *s;
    if (src == PO_SRC_LOG || src == PO_SRC_TRACE || src == PO_SRC_SPAN) return 1;
    for (s = upto; s; s = s->next) {
        if (s->kind == PO_ST_EXEMPLARS) return 1;
        if (s->kind == PO_ST_TRACES || s->kind == PO_ST_LOGS
            || s->kind == PO_ST_SPANS) return 1;
    }
    return 0;
}

/* `by` attaches to the aggregate it groups.
 *
 * The plan's grammar listed `by` as its own stage, but every example in it
 * writes `| count by service` and `| p99 by http.route` as ONE thing - and so
 * does everybody who tries the language. The examples are the specification
 * here: an aggregate and its grouping are one stage. */
static int po_absorb_by(po_parser *p, po_stage *st) {
    if (!po_tok_is(&p->lex.cur, "by")) return 1;
    po_lex_next(&p->lex);
    for (;;) {
        if (p->lex.cur.kind != PO_T_IDENT) {
            po_perr(p, p->lex.cur.off, "by takes field names", NULL);
            return 0;
        }
        if (st->nfields >= 8) {
            po_perr(p, p->lex.cur.off, "too many group-by fields", NULL);
            return 0;
        }
        st->fields[st->nfields] =
            po_intern_tok(p, &p->lex.cur, &st->field_lens[st->nfields]);
        st->nfields++;
        po_lex_next(&p->lex);
        if (p->lex.cur.kind != PO_T_COMMA) break;
        po_lex_next(&p->lex);
    }
    return 1;
}

static po_stage *po_parse_stage(po_parser *p, int *src) {
    po_stage *st = (po_stage *)po_alloc(p, sizeof(po_stage));
    if (!st) return NULL;

    if (po_tok_is(&p->lex.cur, "where")) {
        st->kind = PO_ST_WHERE;
        po_lex_next(&p->lex);
        st->expr = po_parse_or(p);
        if (!st->expr) return NULL;
        if (!po_check_expr(p, st->expr, *src)) return NULL;
        return st;
    }
    if (po_tok_is(&p->lex.cur, "search")) {
        st->kind = PO_ST_SEARCH;
        po_lex_next(&p->lex);
        if (p->lex.cur.kind != PO_T_STRING) {
            po_perr(p, p->lex.cur.off, "search takes a quoted string", NULL);
            return NULL;
        }
        st->str = po_intern_tok(p, &p->lex.cur, &st->str_len);
        po_lex_next(&p->lex);
        if (*src == PO_SRC_METRIC) {
            po_perr(p, 0,
                "search needs text: a metric stream has no body to search",
                NULL);
            return NULL;
        }
        return st;
    }
    if (po_tok_is(&p->lex.cur, "by")) {
        st->kind = PO_ST_BY;
        po_lex_next(&p->lex);
        for (;;) {
            if (p->lex.cur.kind != PO_T_IDENT) {
                po_perr(p, p->lex.cur.off, "by takes field names", NULL);
                return NULL;
            }
            if (st->nfields >= 8) {
                po_perr(p, p->lex.cur.off, "too many group-by fields", NULL);
                return NULL;
            }
            st->fields[st->nfields] =
                po_intern_tok(p, &p->lex.cur, &st->field_lens[st->nfields]);
            st->nfields++;
            po_lex_next(&p->lex);
            if (p->lex.cur.kind != PO_T_COMMA) break;
            po_lex_next(&p->lex);
        }
        return st;
    }
    /* BUCKET AND RATE ARE THE SAME STAGE WITH DIFFERENT UNITS.
     *
     * Both cut the window into equal spans and aggregate within each. The
     * only difference is what the number means at the end: `bucket` reports
     * the aggregate, `rate` divides it by the span so the answer is per
     * second and does not change when somebody widens the window.
     *
     * One parse, therefore, and one execution path. Two would be two places
     * for the boundary arithmetic to disagree, and the disagreement would
     * show up as a rate chart and a count chart that do not line up. */
    if (po_tok_is(&p->lex.cur, "bucket") || po_tok_is(&p->lex.cur, "rate")) {
        const int is_rate = po_tok_is(&p->lex.cur, "rate");
        /* The example carries the stage's own name, which is why the messages
         * below need only one substitution: po_perr expands every %s from the
         * same argument, so a message wanting both the word and an example of
         * it could not have them. */
        const char *eg = is_rate ? "rate(5m)" : "bucket(5m)";
        /* THE MESSAGE NAMES THE STAGE. "takes a window" does not say what
         * takes one, and a parse error that does not name the thing it is
         * about sends the reader back to count pipes. po_perr substitutes one
         * argument, so the two messages are written out rather than built. */
        const char *want = is_rate ? "rate takes a window, as in rate(5m)"
                                   : "bucket takes a window, as in bucket(5m)";
        st->kind = is_rate ? PO_ST_RATE : PO_ST_BUCKET;
        po_lex_next(&p->lex);
        if (p->lex.cur.kind != PO_T_LPAREN) {
            po_perr(p, p->lex.cur.off, want, NULL);
            return NULL;
        }
        po_lex_next(&p->lex);
        if (p->lex.cur.kind != PO_T_DURATION) {
            po_perr(p, p->lex.cur.off, "needs a duration, as in %s", eg);
            return NULL;
        }
        /* A ZERO WINDOW IS A DIVISION BY ZERO AND AN UNBOUNDED BUCKET COUNT.
         * The lexer will not produce one from `5m`, but `0s` lexes fine. */
        if (p->lex.cur.dur == 0) {
            po_perr(p, p->lex.cur.off, "the window cannot be zero, as in %s", eg);
            return NULL;
        }
        st->dur = p->lex.cur.dur;
        po_lex_next(&p->lex);
        if (p->lex.cur.kind != PO_T_RPAREN) {
            po_perr(p, p->lex.cur.off, "expected ')' after the window, as in %s", eg);
            return NULL;
        }
        po_lex_next(&p->lex);

        /* An aggregate may follow, and counting is what it means without one:
         * `bucket(1m)` alone is the histogram of arrivals, which is the
         * commonest thing anybody wants from a bucketed query.
         *
         * Left at 0 rather than defaulted to count HERE, because the stage
         * can also be written apart from its aggregate - `| p95 | bucket(1m)`
         * - and a default applied at parse time would overwrite the p95 with
         * a count of rows. The planner applies it only if nothing else did. */
        st->agg = po_agg_of(&p->lex.cur);
        if (st->agg) po_lex_next(&p->lex);

        if (!po_absorb_by(p, st)) return NULL;
        return st;
    }
    if (po_tok_is(&p->lex.cur, "limit") || po_tok_is(&p->lex.cur, "slowest")) {
        st->kind = po_tok_is(&p->lex.cur, "limit") ? PO_ST_LIMIT : PO_ST_SLOWEST;
        if (st->kind == PO_ST_SLOWEST && *src == PO_SRC_METRIC) {
            po_perr(p, p->lex.cur.off,
                    "slowest needs a duration: a metric stream has none", NULL);
            return NULL;
        }
        po_lex_next(&p->lex);
        if (p->lex.cur.kind != PO_T_NUMBER || !p->lex.cur.is_int) {
            po_perr(p, p->lex.cur.off, "expected a whole number", NULL);
            return NULL;
        }
        st->num = p->lex.cur.inum;
        po_lex_next(&p->lex);
        return st;
    }
    if (po_tok_is(&p->lex.cur, "sort")) {
        st->kind = PO_ST_SORT;
        po_lex_next(&p->lex);
        if (p->lex.cur.kind != PO_T_IDENT) {
            po_perr(p, p->lex.cur.off, "sort takes a field name", NULL);
            return NULL;
        }
        st->fields[0] = po_intern_tok(p, &p->lex.cur, &st->field_lens[0]);
        st->nfields = 1;
        po_lex_next(&p->lex);
        if (po_tok_is(&p->lex.cur, "desc")) { st->desc = 1; po_lex_next(&p->lex); }
        else if (po_tok_is(&p->lex.cur, "asc")) po_lex_next(&p->lex);
        return st;
    }
    if (po_tok_is(&p->lex.cur, "top")) {
        st->kind = PO_ST_TOPN;
        po_lex_next(&p->lex);
        if (p->lex.cur.kind != PO_T_NUMBER || !p->lex.cur.is_int) {
            po_perr(p, p->lex.cur.off, "top takes a whole number", NULL);
            return NULL;
        }
        st->num = p->lex.cur.inum;
        po_lex_next(&p->lex);
        if (!po_tok_is(&p->lex.cur, "by")) {
            po_perr(p, p->lex.cur.off, "top N needs 'by', as in top 10 by count", NULL);
            return NULL;
        }
        po_lex_next(&p->lex);
        st->agg = po_agg_of(&p->lex.cur);
        if (!st->agg) {
            po_perr(p, p->lex.cur.off, "top N by needs an aggregate", NULL);
            return NULL;
        }
        po_lex_next(&p->lex);
        return st;
    }
    {
        int a = po_agg_of(&p->lex.cur);
        if (a) {
            st->kind = PO_ST_AGG;
            st->agg  = a;
            /* A percentile over a log BODY is meaningless. Named here rather
             * than discovered as a strange number later. */
            if (*src == PO_SRC_LOG && a >= PO_AGG_SUM && a != PO_AGG_DISTINCT) {
                po_perr(p, p->lex.cur.off,
                    "that aggregate needs a numeric column; a log stream has none",
                    NULL);
                return NULL;
            }
            po_lex_next(&p->lex);
            if (!po_absorb_by(p, st)) return NULL;
            return st;
        }
    }

    /* the re-keying stages */
    if (po_tok_is(&p->lex.cur, "exemplars")) {
        if (*src != PO_SRC_METRIC) {
            po_perr(p, p->lex.cur.off,
                    "exemplars come from a metric stream", NULL);
            return NULL;
        }
        st->kind = PO_ST_EXEMPLARS;
        po_lex_next(&p->lex);
        return st;
    }
    if (po_tok_is(&p->lex.cur, "traces") || po_tok_is(&p->lex.cur, "logs")
        || po_tok_is(&p->lex.cur, "spans")) {
        int k = po_tok_is(&p->lex.cur, "traces") ? PO_ST_TRACES
              : po_tok_is(&p->lex.cur, "logs")   ? PO_ST_LOGS : PO_ST_SPANS;
        st->kind = k;
        po_lex_next(&p->lex);
        return st;
    }

    po_perr(p, p->lex.cur.off, "unknown stage", NULL);
    return NULL;
}

/* The {a="b", c="d"} selector: sugar for a leading `where` of equalities.
 *
 * `log {service="api"} | search "refused"` is the shape people type, and
 * forcing `| where` for the common case is friction for nothing. */
static po_expr *po_parse_selector(po_parser *p, int src) {
    po_expr *acc = NULL;
    po_lex_next(&p->lex);              /* past '{' */
    if (p->lex.cur.kind == PO_T_RBRACE) { po_lex_next(&p->lex); return NULL; }
    for (;;) {
        po_expr *e = po_parse_cmp(p);
        if (!e) return NULL;
        if (!po_check_expr(p, e, src)) return NULL;
        if (!acc) acc = e;
        else {
            po_expr *n = (po_expr *)po_alloc(p, sizeof(po_expr));
            if (!n) return NULL;
            n->kind = PO_E_AND; n->a = acc; n->b = e;
            acc = n;
        }
        if (p->lex.cur.kind == PO_T_COMMA) { po_lex_next(&p->lex); continue; }
        break;
    }
    if (p->lex.cur.kind != PO_T_RBRACE) {
        po_perr(p, p->lex.cur.off, "expected '}'", NULL);
        return NULL;
    }
    po_lex_next(&p->lex);
    return acc;
}

static int po_parse(po_query *q, const char *src, size_t len) {
    po_parser p;
    po_stage *tail = NULL;

    memset(q, 0, sizeof(*q));
    memset(&p, 0, sizeof(p));
    p.q = q;
    po_lex_init(&p.lex, src, len);
    po_lex_next(&p.lex);

    if (p.lex.failed) {
        q->failed = 1; q->err_off = p.lex.err_off;
        memcpy(q->err, p.lex.err, sizeof(p.lex.err) < sizeof(q->err)
                                  ? sizeof(p.lex.err) : sizeof(q->err) - 1);
        return 0;
    }

    if      (po_tok_is(&p.lex.cur, "metric")) q->source = PO_SRC_METRIC;
    else if (po_tok_is(&p.lex.cur, "log")
          || po_tok_is(&p.lex.cur, "logs"))   q->source = PO_SRC_LOG;
    else if (po_tok_is(&p.lex.cur, "trace")
          || po_tok_is(&p.lex.cur, "traces")) q->source = PO_SRC_TRACE;
    else if (po_tok_is(&p.lex.cur, "span")
          || po_tok_is(&p.lex.cur, "spans"))  q->source = PO_SRC_SPAN;
    else {
        po_perr(&p, p.lex.cur.off,
                "a query starts with metric, log, trace or spans", NULL);
        return 0;
    }
    po_lex_next(&p.lex);

    if (q->source == PO_SRC_METRIC) {
        if (p.lex.cur.kind != PO_T_IDENT) {
            po_perr(&p, p.lex.cur.off, "metric needs a name", NULL);
            return 0;
        }
        q->name = po_intern_tok(&p, &p.lex.cur, &q->name_len);
        po_lex_next(&p.lex);
    }

    if (p.lex.cur.kind == PO_T_LBRACE) {
        q->selector = po_parse_selector(&p, q->source);
        if (q->failed) return 0;
    }

    while (p.lex.cur.kind == PO_T_PIPE) {
        po_stage *st;
        po_lex_next(&p.lex);
        st = po_parse_stage(&p, &q->source);
        if (!st) return 0;

        /* The re-keying check runs against what came BEFORE this stage. */
        if (st->kind == PO_ST_TRACES || st->kind == PO_ST_LOGS
            || st->kind == PO_ST_SPANS) {
            if (!po_has_trace_key(q->source, q->stages)) {
                po_perr(&p, p.lex.cur.off,
                    "this stage needs a trace id on its rows; add | exemplars "
                    "first to get one from the metric", NULL);
                return 0;
            }
        }

        if (tail) tail->next = st; else q->stages = st;
        tail = st;

        if (p.lex.failed) {
            q->failed = 1; q->err_off = p.lex.err_off;
            memcpy(q->err, p.lex.err, sizeof(q->err) - 1);
            return 0;
        }
    }

    if (p.lex.cur.kind != PO_T_EOF) {
        po_perr(&p, p.lex.cur.off, "expected '|' or the end of the query", NULL);
        return 0;
    }
    return !q->failed;
}

#endif /* PO_PARSE_H */
