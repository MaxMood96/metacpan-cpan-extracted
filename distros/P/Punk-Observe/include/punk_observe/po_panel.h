/* po_panel.h - a dashboard panel, which is an OQL string with a title.
 *
 * A panel is stored in the metadata database, not in a segment: it is edited,
 * and segments are immutable. What lives here is the part that must be true
 * before it is stored.
 *
 * PANEL JSON IS UNTRUSTED. It arrives from a form, it renders into HTML, and
 * its query string is parsed. So the query is VALIDATED AT SAVE TIME by the
 * same parser that will execute it - which means a broken dashboard is a form
 * error the author sees, not a run-time failure a reader meets at three in
 * the morning.
 *
 * ORDER IS A NUMBER AND LAYOUT IS A COLUMN COUNT, and the absence of a drag
 * grid is deliberate. A drag grid is several hundred lines of JavaScript, a
 * collision algorithm, a mobile story and a persistence format, in exchange
 * for an arrangement most people set once. A form with a number in it does
 * the same job, works on a phone, and is accessible without any work.
 */
#ifndef PO_PANEL_H
#define PO_PANEL_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_query.h"
#include "punk_observe/po_parse.h"

#define PO_PANEL_TITLE_MAX 128
#define PO_PANEL_COLS_MAX  6

/* Visualisation hints. A hint the renderer does not know falls back to a
 * table, which shows the data rather than nothing. */
#define PO_VIZ_LINE  0
#define PO_VIZ_AREA  1
#define PO_VIZ_BAR   2
#define PO_VIZ_STAT  3
#define PO_VIZ_TABLE 4

static int po_viz_from(const char *s, size_t n) {
    if (n == 4 && memcmp(s, "line", 4) == 0) return PO_VIZ_LINE;
    if (n == 4 && memcmp(s, "area", 4) == 0) return PO_VIZ_AREA;
    if (n == 3 && memcmp(s, "bar",  3) == 0) return PO_VIZ_BAR;
    if (n == 4 && memcmp(s, "stat", 4) == 0) return PO_VIZ_STAT;
    return PO_VIZ_TABLE;
}

static const char *po_viz_name(int v) {
    switch (v) {
        case PO_VIZ_LINE:  return "line";
        case PO_VIZ_AREA:  return "area";
        case PO_VIZ_BAR:   return "bar";
        case PO_VIZ_STAT:  return "stat";
        default:           return "table";
    }
}

#define PO_PANEL_OK        0
#define PO_PANEL_NO_QUERY  1
#define PO_PANEL_BAD_QUERY 2
#define PO_PANEL_NO_TITLE  3
#define PO_PANEL_BAD_TITLE 4

typedef struct {
    int    viz;
    int    position;
    int    cols;
    char   err[256];
} po_panel;

/* Validate one panel. `qerr` receives the parser's own message, because "that
 * query is wrong" is not a usable form error and the parser already knows
 * exactly what is wrong and where. */
static int po_panel_check(po_panel *p, const char *title, size_t tlen,
                          const char *query, size_t qlen,
                          const char *viz, size_t vlen,
                          int position, int cols) {
    po_query q;
    size_t i;

    memset(p, 0, sizeof(*p));
    p->viz      = po_viz_from(viz ? viz : "", vlen);
    p->position = position < 0 ? 0 : position;
    p->cols     = (cols < 1) ? 1 : (cols > PO_PANEL_COLS_MAX
                                    ? PO_PANEL_COLS_MAX : cols);

    if (!title || !tlen) {
        memcpy(p->err, "a panel needs a title", 22);
        return PO_PANEL_NO_TITLE;
    }
    if (tlen > PO_PANEL_TITLE_MAX) {
        memcpy(p->err, "that title is too long", 23);
        return PO_PANEL_BAD_TITLE;
    }
    /* Control characters in a title are refused rather than escaped. They
     * have no legitimate use here, and a title is displayed in a dozen places
     * of which only some are HTML. */
    for (i = 0; i < tlen; i++) {
        unsigned char c = (unsigned char)title[i];
        if (c < 0x20 || c == 0x7f) {
            memcpy(p->err, "a title cannot contain control characters", 42);
            return PO_PANEL_BAD_TITLE;
        }
    }

    if (!query || !qlen) {
        memcpy(p->err, "a panel needs a query", 22);
        return PO_PANEL_NO_QUERY;
    }

    /* THE SAME PARSER THAT WILL EXECUTE IT. A panel validated by a different
     * rule than the one that runs it is a panel that can be saved and cannot
     * be shown. */
    if (!po_parse(&q, query, qlen)) {
        size_t n = strlen(q.err);
        if (n >= sizeof(p->err)) n = sizeof(p->err) - 1;
        memcpy(p->err, q.err, n);
        p->err[n] = '\0';
        return PO_PANEL_BAD_QUERY;
    }
    po_query_free(&q);
    return PO_PANEL_OK;
}

#endif /* PO_PANEL_H */
