/* po_lex.h - the query language's lexer.
 *
 * Hand-written, no generator, no regex. About 200 lines, and it is the reason
 * the language reads the way it does: DURATIONS ARE FIRST-CLASS TOKENS.
 * `duration > 500ms` is not a function call and not a string that something
 * later parses; the lexer knows what `500ms` is, so the parser can type-check
 * it against the column.
 *
 * Every token carries its byte OFFSET. An error that says "syntax error" is a
 * language people avoid; an error that points at the character is one they
 * can use.
 */
#ifndef PO_LEX_H
#define PO_LEX_H

#include "punk_observe/po_compat.h"

typedef enum {
    PO_T_EOF = 0,
    PO_T_IDENT,      /* bare word: a keyword, a column, or a metric name    */
    PO_T_STRING,     /* quoted                                             */
    PO_T_NUMBER,     /* integer or float                                   */
    PO_T_DURATION,   /* 500ms, 5m, 2h, 7d - value in NANOSECONDS           */
    PO_T_PIPE,       /* |                                                  */
    PO_T_LPAREN, PO_T_RPAREN,
    PO_T_LBRACE, PO_T_RBRACE,
    PO_T_COMMA,
    PO_T_OP,         /* = != < <= > >= =~ !~                               */
    PO_T_ERROR
} po_tok_kind;

/* comparison operators, in `op` */
#define PO_OP_EQ    1
#define PO_OP_NE    2
#define PO_OP_LT    3
#define PO_OP_LE    4
#define PO_OP_GT    5
#define PO_OP_GE    6
#define PO_OP_MATCH 7    /* =~ */
#define PO_OP_NMATCH 8   /* !~ */

typedef struct {
    po_tok_kind kind;
    const char *p;       /* into the query string; borrowed */
    size_t      len;
    size_t      off;     /* byte offset, for the error message */
    po_u64      dur;     /* PO_T_DURATION: nanoseconds */
    double      num;     /* PO_T_NUMBER */
    int         is_int;  /* PO_T_NUMBER: no fractional part seen */
    po_u64      inum;    /* PO_T_NUMBER when is_int: exact, no NV rounding */
    int         op;
} po_tok;

typedef struct {
    const char *src;
    size_t      len;
    size_t      pos;
    po_tok      cur;
    char        err[192];
    size_t      err_off;
    int         failed;
} po_lex;

static void po_lex_fail(po_lex *l, size_t off, const char *msg) {
    if (l->failed) return;
    l->failed = 1;
    l->err_off = off;
    {
        size_t n = strlen(msg);
        if (n >= sizeof(l->err)) n = sizeof(l->err) - 1;
        memcpy(l->err, msg, n);
        l->err[n] = '\0';
    }
    l->cur.kind = PO_T_ERROR;
}

static int po_is_ident_start(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_';
}
static int po_is_ident(char c) {
    /* Dots are part of an identifier: `http.response.status_code` is ONE
     * column name, not a field access. Semantic conventions are dotted, so a
     * lexer that split on dots would make every real attribute unquotable. */
    return po_is_ident_start(c) || (c >= '0' && c <= '9') || c == '.' || c == '-';
}
static int po_is_digit(char c) { return c >= '0' && c <= '9'; }

/* A duration suffix, in nanoseconds. `m` is minutes; there is deliberately no
 * month, because `1m` meaning a month somewhere would be a trap nobody
 * recovers from - and because a month has no length, so `1mo` would have to
 * pick one and be wrong eleven times a year.
 *
 * `y` IS EXACTLY 365 DAYS, not a calendar year. Retention is "delete what is
 * older than this many nanoseconds", which is arithmetic and not a calendar
 * operation: there is no date to be relative to, so a leap day has nothing to
 * attach to. It is the same 365 days Prometheus and Go's duration parser
 * mean, and the POD says so rather than leaving somebody to discover that
 * seven years is 2,555 days and not 2,557. */
static po_u64 po_dur_unit(const char *p, size_t n) {
    if (n == 2 && p[0] == 'n' && p[1] == 's') return 1;
    if (n == 2 && p[0] == 'u' && p[1] == 's') return 1000;
    if (n == 2 && p[0] == 'm' && p[1] == 's') return 1000000;
    if (n == 1 && p[0] == 's') return 1000000000ULL;
    if (n == 1 && p[0] == 'm') return 60ULL * 1000000000ULL;
    if (n == 1 && p[0] == 'h') return 3600ULL * 1000000000ULL;
    if (n == 1 && p[0] == 'd') return 86400ULL * 1000000000ULL;
    if (n == 1 && p[0] == 'w') return 7ULL * 86400ULL * 1000000000ULL;
    if (n == 1 && p[0] == 'y') return 365ULL * 86400ULL * 1000000000ULL;
    return 0;
}

static void po_lex_init(po_lex *l, const char *src, size_t len) {
    memset(l, 0, sizeof(*l));
    l->src = src;
    l->len = len;
}

static void po_lex_next(po_lex *l) {
    if (l->failed) return;

    while (l->pos < l->len) {
        char c = l->src[l->pos];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') { l->pos++; continue; }
        if (c == '#') {              /* a comment to end of line */
            while (l->pos < l->len && l->src[l->pos] != '\n') l->pos++;
            continue;
        }
        break;
    }

    memset(&l->cur, 0, sizeof(l->cur));
    l->cur.off = l->pos;
    l->cur.p   = l->src + l->pos;

    if (l->pos >= l->len) { l->cur.kind = PO_T_EOF; return; }

    {
        char c = l->src[l->pos];

        switch (c) {
            case '|': l->pos++; l->cur.kind = PO_T_PIPE;   l->cur.len = 1; return;
            case '(': l->pos++; l->cur.kind = PO_T_LPAREN; l->cur.len = 1; return;
            case ')': l->pos++; l->cur.kind = PO_T_RPAREN; l->cur.len = 1; return;
            case '{': l->pos++; l->cur.kind = PO_T_LBRACE; l->cur.len = 1; return;
            case '}': l->pos++; l->cur.kind = PO_T_RBRACE; l->cur.len = 1; return;
            case ',': l->pos++; l->cur.kind = PO_T_COMMA;  l->cur.len = 1; return;
            default: break;
        }

        /* operators */
        if (c == '=' || c == '!' || c == '<' || c == '>') {
            char d = (l->pos + 1 < l->len) ? l->src[l->pos + 1] : '\0';
            l->cur.kind = PO_T_OP;
            if      (c == '=' && d == '~') { l->cur.op = PO_OP_MATCH;  l->pos += 2; l->cur.len = 2; }
            else if (c == '!' && d == '~') { l->cur.op = PO_OP_NMATCH; l->pos += 2; l->cur.len = 2; }
            else if (c == '!' && d == '=') { l->cur.op = PO_OP_NE;     l->pos += 2; l->cur.len = 2; }
            else if (c == '<' && d == '=') { l->cur.op = PO_OP_LE;     l->pos += 2; l->cur.len = 2; }
            else if (c == '>' && d == '=') { l->cur.op = PO_OP_GE;     l->pos += 2; l->cur.len = 2; }
            else if (c == '=' && d == '=') { l->cur.op = PO_OP_EQ;     l->pos += 2; l->cur.len = 2; }
            else if (c == '=') { l->cur.op = PO_OP_EQ; l->pos++; l->cur.len = 1; }
            else if (c == '<') { l->cur.op = PO_OP_LT; l->pos++; l->cur.len = 1; }
            else if (c == '>') { l->cur.op = PO_OP_GT; l->pos++; l->cur.len = 1; }
            else { po_lex_fail(l, l->pos, "'!' must be followed by '=' or '~'"); return; }
            return;
        }

        /* strings */
        if (c == '"' || c == '\'') {
            char q = c;
            size_t start;
            l->pos++;
            start = l->pos;
            while (l->pos < l->len && l->src[l->pos] != q) {
                if (l->src[l->pos] == '\\' && l->pos + 1 < l->len) l->pos++;
                l->pos++;
            }
            if (l->pos >= l->len) {
                po_lex_fail(l, l->cur.off, "unterminated string");
                return;
            }
            l->cur.kind = PO_T_STRING;
            l->cur.p    = l->src + start;
            l->cur.len  = l->pos - start;
            l->pos++;                 /* the closing quote */
            return;
        }

        /* numbers and durations */
        if (po_is_digit(c)) {
            size_t start = l->pos;
            int seen_dot = 0;
            po_u64 ival = 0;
            int overflow = 0;

            while (l->pos < l->len &&
                   (po_is_digit(l->src[l->pos]) ||
                    (l->src[l->pos] == '.' && !seen_dot
                     && l->pos + 1 < l->len && po_is_digit(l->src[l->pos + 1])))) {
                if (l->src[l->pos] == '.') seen_dot = 1;
                else if (!seen_dot) {
                    po_u64 d = (po_u64)(l->src[l->pos] - '0');
                    if (ival > (PO_U64_MAX - d) / 10) overflow = 1;
                    else ival = ival * 10 + d;
                }
                l->pos++;
            }

            /* a unit suffix makes it a duration */
            {
                size_t us = l->pos;
                while (l->pos < l->len && l->src[l->pos] >= 'a'
                       && l->src[l->pos] <= 'z') l->pos++;
                if (l->pos > us) {
                    po_u64 unit = po_dur_unit(l->src + us, l->pos - us);
                    if (!unit) {
                        po_lex_fail(l, us,
                            "unknown duration unit "
                            "(use ns, us, ms, s, m, h, d, w, y)");
                        return;
                    }
                    if (seen_dot) {
                        /* 1.5s is meaningful and exact enough at nanosecond
                         * scale via the double, but only because the unit is
                         * large; the integer path is preferred everywhere. */
                        double v = 0, frac = 0.1;
                        size_t k;
                        int after = 0;
                        for (k = start; k < us; k++) {
                            if (l->src[k] == '.') { after = 1; continue; }
                            if (!after) v = v * 10 + (l->src[k] - '0');
                            else { v += (l->src[k] - '0') * frac; frac /= 10; }
                        }
                        l->cur.dur = (po_u64)(v * (double)unit);
                    }
                    else {
                        if (overflow || (unit && ival > PO_U64_MAX / unit)) {
                            po_lex_fail(l, start, "duration out of range");
                            return;
                        }
                        l->cur.dur = ival * unit;
                    }
                    l->cur.kind = PO_T_DURATION;
                    l->cur.len  = l->pos - start;
                    return;
                }
            }

            l->cur.kind   = PO_T_NUMBER;
            l->cur.len    = l->pos - start;
            l->cur.is_int = !seen_dot && !overflow;
            l->cur.inum   = ival;
            {   /* the NV form, for comparisons against a metric value */
                double v = 0, frac = 0.1;
                size_t k; int after = 0;
                for (k = start; k < l->pos; k++) {
                    if (l->src[k] == '.') { after = 1; continue; }
                    if (!after) v = v * 10 + (l->src[k] - '0');
                    else { v += (l->src[k] - '0') * frac; frac /= 10; }
                }
                l->cur.num = v;
            }
            return;
        }

        /* identifiers */
        if (po_is_ident_start(c)) {
            size_t start = l->pos;
            while (l->pos < l->len && po_is_ident(l->src[l->pos])) l->pos++;
            l->cur.kind = PO_T_IDENT;
            l->cur.p    = l->src + start;
            l->cur.len  = l->pos - start;
            return;
        }

        po_lex_fail(l, l->pos, "unexpected character");
    }
}

static int po_tok_is(const po_tok *t, const char *word) {
    size_t n = strlen(word);
    return t->kind == PO_T_IDENT && t->len == n && memcmp(t->p, word, n) == 0;
}

#endif /* PO_LEX_H */
