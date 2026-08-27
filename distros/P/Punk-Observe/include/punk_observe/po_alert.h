/* po_alert.h - rule evaluation, and the two states everybody forgets.
 *
 * A rule is an OQL string executed on the same path the dashboard uses, so
 * an alert cannot fire on a different answer than the graph shows. That part
 * is phases 8 and 9. This file is what happens to the ANSWER.
 *
 * STATE IS PER SERIES.
 *
 * A rule grouped `by service` produces many series and each carries its own
 * state. One state per rule is the bug that makes an alert resolve because a
 * DIFFERENT service recovered, and it is easy to write because a rule feels
 * like one thing.
 *
 * THE TWO THAT GET MISSED, AND WHY EACH IS DANGEROUS.
 *
 *   A VANISHED SERIES MUST NOT STAY FIRING. A pod is deleted, its series
 *   stops being reported, and the naive implementation leaves it red for
 *   ever. A permanently red dashboard is how alerting loses its audience,
 *   and once it has, the real alert is not read either.
 *
 *   AN EVALUATION ERROR IS NOT "OK". A rule whose query fails - a store
 *   error, a budget refusal, a bad threshold - must go to `error` and
 *   notify, not report healthy. This one is most likely to be written by
 *   accident, because the natural code path treats "no rows" and "no answer"
 *   identically, and the result is a system that reports green because it
 *   could not look.
 *
 * So the evaluation input carries a STATUS as well as rows, and this file
 * refuses to collapse the two.
 */
#ifndef PO_ALERT_H
#define PO_ALERT_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_time.h"

#define PO_AL_OK      0
#define PO_AL_PENDING 1
#define PO_AL_FIRING  2
#define PO_AL_STALE   3
#define PO_AL_ERROR   4

/* What an evaluation produced. NOT a boolean: see the header comment. */
#define PO_EVAL_OK   0   /* the query ran; the rows are what matched */
#define PO_EVAL_FAIL 1   /* the query did not run, or was refused */

/* Comparison operators, spelled the same way the query language does. */
#define PO_AL_GT 1
#define PO_AL_GE 2
#define PO_AL_LT 3
#define PO_AL_LE 4
#define PO_AL_EQ 5
#define PO_AL_NE 6

#define PO_AL_KEY_MAX 128
#define PO_AL_MAX_SERIES 1024

/* What came out of a transition, for the router to deliver. */
#define PO_NOTE_FIRING   1
#define PO_NOTE_RESOLVED 2
#define PO_NOTE_VANISHED 3   /* resolved because the series stopped existing */
#define PO_NOTE_ERROR    4

typedef struct {
    int    op;
    double threshold;
    po_u64 for_ns;      /* how long the condition must hold CONTINUOUSLY */
    po_u64 every_ns;    /* how often this rule is evaluated */
} po_al_rule;

typedef struct {
    char   key[PO_AL_KEY_MAX];
    size_t key_len;
    int    state;
    po_u64 since;        /* when the condition began holding */
    po_u64 fired_at;     /* when it entered firing; part of the dedupe key */
    po_u64 last_seen;    /* the last evaluation that carried this series */
    double last_value;
    int    notified_error;  /* an error notifies ONCE, not every tick */
} po_al_series;

typedef struct {
    char   key[PO_AL_KEY_MAX];
    size_t key_len;
    int    kind;
    int    from, to;
    po_u64 at;
    po_u64 fired_at;
    double value;
} po_al_note;

typedef struct {
    po_al_series s[PO_AL_MAX_SERIES];
    uint32_t     n;
    po_al_note   note[PO_AL_MAX_SERIES];
    uint32_t     nnote;
} po_al_state;

/* One row of an evaluation result. */
typedef struct {
    const char *key; size_t key_len;
    double      value;
} po_al_row;

static void po_al_init(po_al_state *st) { memset(st, 0, sizeof(*st)); }

static int po_al_cmp(double v, int op, double t) {
    switch (op) {
        case PO_AL_GT: return v >  t;
        case PO_AL_GE: return v >= t;
        case PO_AL_LT: return v <  t;
        case PO_AL_LE: return v <= t;
        case PO_AL_EQ: return v == t;
        case PO_AL_NE: return v != t;
        default:       return 0;
    }
}

static po_al_series *po_al_find(po_al_state *st, const char *k, size_t klen,
                                int create) {
    uint32_t i;
    if (klen > PO_AL_KEY_MAX) klen = PO_AL_KEY_MAX;
    for (i = 0; i < st->n; i++)
        if (st->s[i].key_len == klen &&
            (klen == 0 || memcmp(st->s[i].key, k, klen) == 0)) return &st->s[i];
    if (!create || st->n >= PO_AL_MAX_SERIES) return NULL;
    memset(&st->s[st->n], 0, sizeof(st->s[0]));
    if (klen) memcpy(st->s[st->n].key, k, klen);
    st->s[st->n].key_len = klen;
    st->s[st->n].state   = PO_AL_OK;
    return &st->s[st->n++];
}

static void po_al_emit(po_al_state *st, const po_al_series *s, int kind,
                       int from, int to, po_u64 at, double value) {
    po_al_note *n;
    if (st->nnote >= PO_AL_MAX_SERIES) return;
    n = &st->note[st->nnote++];
    memset(n, 0, sizeof(*n));
    memcpy(n->key, s->key, s->key_len);
    n->key_len  = s->key_len;
    n->kind     = kind;
    n->from     = from;
    n->to       = to;
    n->at       = at;
    n->fired_at = s->fired_at;
    n->value    = value;
}

/* One evaluation.
 *
 * `status` is PO_EVAL_OK or PO_EVAL_FAIL, and the difference is the whole
 * point: a result with NO ROWS means every known series is absent, which is
 * `stale`. A FAILED evaluation means nothing was learned about any of them,
 * which is `error`. Collapsing the two is how an alerting system reports
 * green because it could not look.
 *
 * Notes accumulate in `st->note`; the caller drains them. */
static void po_al_step(po_al_state *st, const po_al_rule *r,
                       int status, const po_al_row *rows, uint32_t nrows) {
    po_u64 now = po_now_ns();
    uint32_t i;

    st->nnote = 0;

    if (status == PO_EVAL_FAIL) {
        /* Every series the rule knows about goes to error, and each notifies
         * ONCE. A rule that pages every tick while a store is down is a rule
         * that gets silenced, which is the same as not having it. */
        for (i = 0; i < st->n; i++) {
            po_al_series *s = &st->s[i];
            int from = s->state;
            if (s->state != PO_AL_ERROR) {
                s->state = PO_AL_ERROR;
                s->since = now;
            }
            if (!s->notified_error) {
                s->notified_error = 1;
                po_al_emit(st, s, PO_NOTE_ERROR, from, PO_AL_ERROR, now,
                           s->last_value);
            }
        }
        /* A rule with no series yet still has to be able to report that it
         * cannot evaluate, so a synthetic entry carries it. */
        if (st->n == 0) {
            po_al_series *s = po_al_find(st, "", 0, 1);
            if (s && !s->notified_error) {
                s->state = PO_AL_ERROR;
                s->since = now;
                s->notified_error = 1;
                po_al_emit(st, s, PO_NOTE_ERROR, PO_AL_OK, PO_AL_ERROR, now, 0);
            }
        }
        return;
    }

    /* Present series first. */
    for (i = 0; i < nrows; i++) {
        po_al_series *s = po_al_find(st, rows[i].key, rows[i].key_len, 1);
        int cond, from;
        if (!s) continue;
        cond = po_al_cmp(rows[i].value, r->op, r->threshold);
        from = s->state;
        s->last_seen  = now;
        s->last_value = rows[i].value;

        /* A recovered evaluation clears the once-only error latch, so the
         * NEXT failure notifies again rather than being swallowed. */
        s->notified_error = 0;

        if (s->state == PO_AL_ERROR || s->state == PO_AL_STALE) {
            /* Back from the dead. Re-enter the machine from ok so the `for`
             * window is measured afresh rather than from a stale `since`. */
            s->state = PO_AL_OK;
            s->since = 0;
            from = s->state;
        }

        switch (s->state) {
            case PO_AL_OK:
                if (cond) { s->state = PO_AL_PENDING; s->since = now; }
                break;

            case PO_AL_PENDING:
                if (!cond) {
                    /* THE TRANSITION THAT SENDS NOTHING, and the entire
                     * purpose of `for`. Notifying here produces exactly the
                     * flapping the setting exists to prevent. */
                    s->state = PO_AL_OK;
                    s->since = 0;
                }
                else if (now - s->since >= r->for_ns) {
                    s->state    = PO_AL_FIRING;
                    s->fired_at = now;
                    po_al_emit(st, s, PO_NOTE_FIRING, from, PO_AL_FIRING, now,
                               rows[i].value);
                }
                break;

            case PO_AL_FIRING:
                if (!cond) {
                    s->state = PO_AL_OK;
                    s->since = 0;
                    po_al_emit(st, s, PO_NOTE_RESOLVED, from, PO_AL_OK, now,
                               rows[i].value);
                    s->fired_at = 0;
                }
                break;

            default: break;
        }
    }

    /* Then the ones that were NOT in the result.
     *
     * Absent is not false. A series that stops being reported goes stale, and
     * leaves firing when it does - the alternative is a dashboard that stays
     * red for a pod that was deleted last Tuesday. */
    for (i = 0; i < st->n; i++) {
        po_al_series *s = &st->s[i];
        uint32_t j;
        int present = 0;
        for (j = 0; j < nrows; j++) {
            size_t kl = rows[j].key_len > PO_AL_KEY_MAX
                        ? PO_AL_KEY_MAX : rows[j].key_len;
            if (kl == s->key_len &&
                (kl == 0 || memcmp(rows[j].key, s->key, kl) == 0)) {
                present = 1; break;
            }
        }
        if (present) continue;

        if (s->state != PO_AL_STALE && s->state != PO_AL_OK) {
            s->state = PO_AL_STALE;
            if (!s->since) s->since = now;
            continue;
        }
        if (s->state == PO_AL_STALE) {
            /* Two evaluation intervals of silence is the bound. It is a
             * multiple of `every` rather than a constant, so a rule that runs
             * hourly is not declared stale after a minute. */
            po_u64 quiet = now > s->last_seen ? now - s->last_seen : 0;
            if (quiet >= 2 * r->every_ns) {
                int from = s->state;
                int was_firing = s->fired_at != 0;
                s->state = PO_AL_OK;
                s->since = 0;
                if (was_firing) {
                    /* A firing alert that simply stopped existing still owes
                     * the reader a resolution, and one that says WHY: this is
                     * not the same event as the condition clearing. */
                    po_al_emit(st, s, PO_NOTE_VANISHED, from, PO_AL_OK, now,
                               s->last_value);
                    s->fired_at = 0;
                }
            }
        }
    }
}

/* A firing series must go stale the moment it is missing, which the loop
 * above does. This is the question a UI asks. */
static int po_al_state_of(const po_al_state *st, const char *k, size_t klen) {
    uint32_t i;
    if (klen > PO_AL_KEY_MAX) klen = PO_AL_KEY_MAX;
    for (i = 0; i < st->n; i++)
        if (st->s[i].key_len == klen &&
            (klen == 0 || memcmp(st->s[i].key, k, klen) == 0))
            return st->s[i].state;
    return -1;
}

static const char *po_al_state_name(int s) {
    switch (s) {
        case PO_AL_OK:      return "ok";
        case PO_AL_PENDING: return "pending";
        case PO_AL_FIRING:  return "firing";
        case PO_AL_STALE:   return "stale";
        case PO_AL_ERROR:   return "error";
        default:            return "unknown";
    }
}

#endif /* PO_ALERT_H */
