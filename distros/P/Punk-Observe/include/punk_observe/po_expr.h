/* po_expr.h - evaluating a compiled predicate against a row.
 *
 * The AST from phase 8 is walked once here per row. That is deliberate: the
 * tree is tiny (a handful of nodes), it is already in one bump chunk, and a
 * bytecode pass over it would be a second representation to keep correct for
 * no measurable gain at this size. What matters for speed is what the
 * comparisons DO, and they compare resolved values rather than parsing
 * anything per row.
 *
 * THREE THINGS THAT LOOK LIKE DETAILS AND ARE NOT.
 *
 * 1. A comparison against a MISSING field is FALSE, not zero. `duration > 0`
 *    must not match a log line that has no duration. Treating absent as zero
 *    silently widens every numeric filter.
 * 2. `!=` against a missing field is also FALSE, not true. Both directions of
 *    a comparison on something that is not there are false; anything else
 *    makes `not (a = 1)` and `a != 1` differ on rows lacking `a`.
 * 3. Regex is NOT a regex engine here. `=~` supports an anchored prefix, an
 *    anchored suffix and a bare substring, which is what real usage is; a
 *    pattern needing more is refused at plan time rather than silently
 *    treated as a literal.
 */
#ifndef PO_EXPR_H
#define PO_EXPR_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_query.h"
#include "punk_observe/po_row.h"

/* Is this a pattern the matcher supports? Returns 0 if not, so the planner
 * can refuse it with a message rather than the executor quietly matching
 * something else. */
static int po_pattern_ok(const char *p, size_t n) {
    size_t i;
    for (i = 0; i < n; i++) {
        char c = p[i];
        if (c == '^' && i == 0) continue;
        if (c == '$' && i == n - 1) continue;
        if (c == '.' || c == '*' || c == '+' || c == '?' || c == '[' ||
            c == ']' || c == '(' || c == ')' || c == '|' || c == '\\' ||
            c == '{' || c == '}') return 0;
    }
    return 1;
}

static int po_match(const char *hay, size_t hn, const char *pat, size_t pn) {
    int anchor_start = 0, anchor_end = 0;
    if (pn && pat[0] == '^')      { anchor_start = 1; pat++; pn--; }
    if (pn && pat[pn - 1] == '$') { anchor_end = 1; pn--; }
    if (pn > hn) return 0;
    if (anchor_start && anchor_end) return pn == hn && memcmp(hay, pat, pn) == 0;
    if (anchor_start) return memcmp(hay, pat, pn) == 0;
    if (anchor_end)   return memcmp(hay + hn - pn, pat, pn) == 0;
    {
        size_t i;
        if (pn == 0) return 1;
        for (i = 0; i + pn <= hn; i++)
            if (memcmp(hay + i, pat, pn) == 0) return 1;
        return 0;
    }
}

static int po_cmp_num(double a, int op, double b) {
    switch (op) {
        case PO_OP_EQ: return a == b;
        case PO_OP_NE: return a != b;
        case PO_OP_LT: return a <  b;
        case PO_OP_LE: return a <= b;
        case PO_OP_GT: return a >  b;
        case PO_OP_GE: return a >= b;
        default: return 0;
    }
}

static int po_cmp_str(const char *a, size_t an, int op,
                      const char *b, size_t bn) {
    int c;
    size_t m = an < bn ? an : bn;
    switch (op) {
        case PO_OP_MATCH:  return po_match(a, an, b, bn);
        case PO_OP_NMATCH: return !po_match(a, an, b, bn);
        default: break;
    }
    c = m ? memcmp(a, b, m) : 0;
    if (c == 0) c = an == bn ? 0 : (an < bn ? -1 : 1);
    switch (op) {
        case PO_OP_EQ: return c == 0;
        case PO_OP_NE: return c != 0;
        case PO_OP_LT: return c <  0;
        case PO_OP_LE: return c <= 0;
        case PO_OP_GT: return c >  0;
        case PO_OP_GE: return c >= 0;
        default: return 0;
    }
}

static int po_eval(const po_expr *e, const po_row *r) {
    if (!e) return 1;
    switch (e->kind) {
        case PO_E_AND: return po_eval(e->a, r) && po_eval(e->b, r);
        case PO_E_OR:  return po_eval(e->a, r) || po_eval(e->b, r);
        case PO_E_NOT: return !po_eval(e->a, r);
        case PO_E_CMP: break;
        default: return 0;
    }

    /* A duration or severity literal is numeric by construction. */
    if (e->vkind == PO_V_DURATION || e->vkind == PO_V_SEVERITY
        || e->vkind == PO_V_NUMBER) {
        double lhs;
        double rhs = (e->vkind == PO_V_NUMBER) ? e->nval : (double)e->uval;
        if (!po_row_num(r, e->field, e->field_len, &lhs)) return 0;  /* absent */
        return po_cmp_num(lhs, e->op, rhs);
    }

    {
        size_t hn;
        const char *hay = po_row_str(r, e->field, e->field_len, &hn);
        if (!hay) return 0;                                   /* absent */
        return po_cmp_str(hay, hn, e->op, e->sval, e->sval_len);
    }
}

/* Walk an expression looking for a pattern the matcher cannot honour, so the
 * planner refuses it rather than the executor guessing. */
static const po_expr *po_expr_bad_pattern(const po_expr *e) {
    const po_expr *r;
    if (!e) return NULL;
    if (e->kind == PO_E_CMP) {
        if ((e->op == PO_OP_MATCH || e->op == PO_OP_NMATCH)
            && e->vkind == PO_V_STRING
            && !po_pattern_ok(e->sval, e->sval_len)) return e;
        return NULL;
    }
    if ((r = po_expr_bad_pattern(e->a))) return r;
    return po_expr_bad_pattern(e->b);
}

/* Does this expression constrain the time column? The planner uses it to
 * decide which segments to open, and a query with no time bound at all is the
 * one most likely to be refused. */
static int po_expr_time_bounded(const po_expr *e) {
    if (!e) return 0;
    if (e->kind == PO_E_CMP)
        return (e->field_len == 1 && e->field[0] == 't')
            || (e->field_len == 4 && memcmp(e->field, "time", 4) == 0);
    if (e->kind == PO_E_AND)
        return po_expr_time_bounded(e->a) || po_expr_time_bounded(e->b);
    /* An OR does not BOUND anything: `t > x or service = "y"` still admits
     * every row outside the range. Only a conjunction narrows. */
    return 0;
}

/* Does it constrain anything selective at all? */
static int po_expr_selective(const po_expr *e) {
    if (!e) return 0;
    if (e->kind == PO_E_CMP) return e->op == PO_OP_EQ;
    if (e->kind == PO_E_AND)
        return po_expr_selective(e->a) || po_expr_selective(e->b);
    return 0;
}

#endif /* PO_EXPR_H */
