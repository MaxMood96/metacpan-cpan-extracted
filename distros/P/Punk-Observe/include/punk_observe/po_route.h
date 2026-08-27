/* po_route.h - grouping, silences, and the outbox key.
 *
 * A DEPLOY BREAKS FORTY SERVICES AT ONCE.
 *
 * Forty firing series is one event, and delivering it as forty messages is
 * how a channel gets muted. So notifications are grouped by a configured
 * label set and held for `group_wait` before the first send: one message
 * listing forty services rather than forty messages.
 *
 * That delay is deliberate and has to be SAID. Thirty seconds of latency on a
 * page is a thing an operator needs to know in advance rather than discover
 * during an incident, so the UI states it and this file makes it a
 * configured number rather than a constant buried in a loop.
 *
 * A SILENCE SUPPRESSES NOTIFICATION AND NOT STATE.
 *
 * A silenced rule still reaches firing and still renders red; it just does
 * not page. A silence that hides the state is how an incident is forgotten -
 * somebody silences an alert to get through a deploy and the dashboard shows
 * green for the rest of the week.
 */
#ifndef PO_ROUTE_H
#define PO_ROUTE_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_time.h"
#include "punk_observe/po_alert.h"

#define PO_GROUP_MAX      64
#define PO_GROUP_MEMBERS 256
#define PO_OUTBOX_MAX    4096

/* ---- the outbox key -------------------------------------------------------
 *
 * (rule, series, fired_at). A retried send job recomputes the same key and is
 * refused, so a delivery can never happen twice however many times the job
 * runs. `fired_at` is in the key rather than a timestamp of the send, because
 * a series that resolves and fires again is a NEW notification and must not
 * be deduplicated against the old one. */
typedef struct {
    po_u64 rule;
    char   series[PO_AL_KEY_MAX];
    size_t series_len;
    po_u64 fired_at;
    int    claimed;
} po_ob_ent;

typedef struct {
    po_ob_ent e[PO_OUTBOX_MAX];
    uint32_t  n;
} po_outbox;

static void po_outbox_init(po_outbox *o) { memset(o, 0, sizeof(*o)); }

static po_ob_ent *po_outbox_find(po_outbox *o, po_u64 rule,
                                 const char *s, size_t slen, po_u64 fired) {
    uint32_t i;
    if (slen > PO_AL_KEY_MAX) slen = PO_AL_KEY_MAX;
    for (i = 0; i < o->n; i++)
        if (o->e[i].rule == rule && o->e[i].fired_at == fired
            && o->e[i].series_len == slen
            && (slen == 0 || memcmp(o->e[i].series, s, slen) == 0))
            return &o->e[i];
    return NULL;
}

/* Returns 1 when the notification was newly enqueued, 0 when the key was
 * already present. Zero is the SUCCESS case for a retry: it means the work
 * was already done, not that anything failed. */
static int po_outbox_put(po_outbox *o, po_u64 rule,
                         const char *s, size_t slen, po_u64 fired) {
    po_ob_ent *e;
    if (slen > PO_AL_KEY_MAX) slen = PO_AL_KEY_MAX;
    if (po_outbox_find(o, rule, s, slen, fired)) return 0;
    if (o->n >= PO_OUTBOX_MAX) return 0;
    e = &o->e[o->n++];
    memset(e, 0, sizeof(*e));
    e->rule = rule;
    if (slen) memcpy(e->series, s, slen);
    e->series_len = slen;
    e->fired_at   = fired;
    return 1;
}

/* Claim one unclaimed row. The database does this with FOR UPDATE SKIP
 * LOCKED; the invariant either way is that a claimed row is not claimable by
 * a second sender. */
static po_ob_ent *po_outbox_claim(po_outbox *o) {
    uint32_t i;
    for (i = 0; i < o->n; i++)
        if (!o->e[i].claimed) { o->e[i].claimed = 1; return &o->e[i]; }
    return NULL;
}

static uint32_t po_outbox_pending(const po_outbox *o) {
    uint32_t i, n = 0;
    for (i = 0; i < o->n; i++) if (!o->e[i].claimed) n++;
    return n;
}

/* ---- grouping -------------------------------------------------------------
 *
 * A group opens when its first member arrives and is DUE `group_wait` later.
 * Members joining before it is due join the same message; one arriving after
 * it has been sent opens a new group, which is what makes the forty-first
 * service a second notification rather than a lost one. */
typedef struct {
    char     key[PO_AL_KEY_MAX];
    size_t   key_len;
    char     member[PO_GROUP_MEMBERS][PO_AL_KEY_MAX];
    size_t   member_len[PO_GROUP_MEMBERS];
    uint32_t nmember;
    uint32_t overflow;    /* members past the cap, counted not dropped */
    po_u64   opened;
    po_u64   last_sent;
    int      sent;
} po_ngroup;

typedef struct {
    po_ngroup g[PO_GROUP_MAX];
    uint32_t n;
    po_u64   group_wait;
    po_u64   repeat_interval;
} po_router;

static void po_router_init(po_router *r, po_u64 wait, po_u64 repeat) {
    memset(r, 0, sizeof(*r));
    r->group_wait      = wait;
    r->repeat_interval = repeat;
}

static po_ngroup *po_group_for(po_router *r, const char *k, size_t klen) {
    uint32_t i;
    po_u64 now = po_now_ns();
    if (klen > PO_AL_KEY_MAX) klen = PO_AL_KEY_MAX;
    for (i = 0; i < r->n; i++)
        if (r->g[i].key_len == klen && !r->g[i].sent
            && (klen == 0 || memcmp(r->g[i].key, k, klen) == 0))
            return &r->g[i];
    if (r->n >= PO_GROUP_MAX) return NULL;
    memset(&r->g[r->n], 0, sizeof(r->g[0]));
    if (klen) memcpy(r->g[r->n].key, k, klen);
    r->g[r->n].key_len = klen;
    r->g[r->n].opened  = now;
    return &r->g[r->n++];
}

/* Add one firing series to its group. Silenced series are NOT added: the
 * silence suppresses the notification, and the state machine has already
 * recorded that it is firing. */
static int po_route_add(po_router *r, const char *gkey, size_t gklen,
                        const char *series, size_t slen, int silenced) {
    po_ngroup *g;
    if (silenced) return 0;
    g = po_group_for(r, gkey, gklen);
    if (!g) return 0;
    if (slen > PO_AL_KEY_MAX) slen = PO_AL_KEY_MAX;
    if (g->nmember >= PO_GROUP_MEMBERS) {
        /* Counted rather than dropped. A message saying "and 40 more" is an
         * answer; a message silently listing 256 of 296 is a lie. */
        g->overflow++;
        return 1;
    }
    if (slen) memcpy(g->member[g->nmember], series, slen);
    g->member_len[g->nmember] = slen;
    g->nmember++;
    return 1;
}

/* Is this group due to send? */
static int po_group_due(const po_router *r, const po_ngroup *g) {
    po_u64 now = po_now_ns();
    if (g->sent) {
        if (!r->repeat_interval) return 0;
        return now - g->last_sent >= r->repeat_interval;
    }
    return now - g->opened >= r->group_wait;
}

static po_ngroup *po_router_next_due(po_router *r) {
    uint32_t i;
    for (i = 0; i < r->n; i++)
        if (r->g[i].nmember && po_group_due(r, &r->g[i])) return &r->g[i];
    return NULL;
}

static void po_group_mark_sent(po_router *r, po_ngroup *g) {
    (void)r;
    g->sent      = 1;
    g->last_sent = po_now_ns();
}

/* ---- silences -------------------------------------------------------------
 *
 * A silence matches a series by exact key or by prefix, and expires. An
 * expired silence must not keep suppressing: a silence set for a deploy and
 * forgotten is how a real page goes unsent for a month. */
typedef struct {
    char   pat[PO_AL_KEY_MAX];
    size_t pat_len;
    int    prefix;
    po_u64 until;
} po_silence;

#define PO_SILENCE_MAX 128
typedef struct { po_silence s[PO_SILENCE_MAX]; uint32_t n; } po_silences;

static void po_silences_init(po_silences *s) { memset(s, 0, sizeof(*s)); }

static int po_silence_add(po_silences *sl, const char *pat, size_t len,
                          int prefix, po_u64 until) {
    po_silence *s;
    if (sl->n >= PO_SILENCE_MAX) return 0;
    if (len > PO_AL_KEY_MAX) len = PO_AL_KEY_MAX;
    s = &sl->s[sl->n++];
    memset(s, 0, sizeof(*s));
    if (len) memcpy(s->pat, pat, len);
    s->pat_len = len;
    s->prefix  = prefix;
    s->until   = until;
    return 1;
}

static int po_is_silenced(const po_silences *sl, const char *k, size_t klen) {
    po_u64 now = po_now_ns();
    uint32_t i;
    for (i = 0; i < sl->n; i++) {
        const po_silence *s = &sl->s[i];
        if (s->until && now >= s->until) continue;      /* expired */
        if (s->prefix) {
            if (klen >= s->pat_len && memcmp(k, s->pat, s->pat_len) == 0)
                return 1;
        }
        else if (klen == s->pat_len && memcmp(k, s->pat, klen) == 0) return 1;
    }
    return 0;
}

#endif /* PO_ROUTE_H */
