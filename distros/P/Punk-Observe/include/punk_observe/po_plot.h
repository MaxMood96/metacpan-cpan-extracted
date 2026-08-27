/* po_plot.h - the arithmetic behind a figure.
 *
 * The figures themselves are written in xs/plot.xs, because they need the
 * query result and that arrives as Perl data. What is here is everything that
 * does not: the bucket ladder, the axis conversion, the colour roles and the
 * severity bands. Testable without a store and without an interpreter.
 */
#ifndef PO_PLOT_H
#define PO_PLOT_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_nsarith.h"

/* Milliseconds since the epoch, for a chart axis.
 *
 * Milliseconds fit a double with room to spare - 1.8e12 against a 9e15
 * ceiling - so an axis is exact to the millisecond, which is finer than any
 * screen can resolve. What is NOT done is arithmetic on the nanoseconds
 * first: dividing by a million before the conversion rounds the value in the
 * digits a chart is drawn from. So the last six digits are DROPPED, as
 * characters, and what is left is converted once.
 *
 * Past 2^53 the answer stops being exact, which is a year 287396 problem.
 * Returned as a po_u64 so the caller decides how to cross to Perl. */
static po_u64 po_plot_ms(const char *ns, size_t len) {
    char buf[32];
    size_t n = 0, i;
    po_u64 v = 0;

    if (!ns) return 0;
    for (i = 0; i < len && n < sizeof(buf); i++)
        if (ns[i] >= '0' && ns[i] <= '9') buf[n++] = ns[i];
    if (n <= 6) return 0;
    n -= 6;
    for (i = 0; i < n; i++) v = v * 10 + (po_u64)(buf[i] - '0');
    return v;
}

/* Whole seconds between two instants, as the ladder wants them. Zero for
 * anything that does not parse, which makes the caller fall back to its
 * default rather than dividing by a width it invented. */
static po_u64 po_plot_span_seconds(const char *from, size_t flen,
                                   const char *to, size_t tlen) {
    po_u64 a = 0, b = 0;
    int ok = 1;
    size_t i;

    if (!from || !to) return 0;
    for (i = 0; i < flen; i++) {
        if (from[i] < '0' || from[i] > '9') { ok = 0; break; }
        a = a * 10 + (po_u64)(from[i] - '0');
    }
    for (i = 0; ok && i < tlen; i++) {
        if (to[i] < '0' || to[i] > '9') { ok = 0; break; }
        b = b * 10 + (po_u64)(to[i] - '0');
    }
    if (!ok || !flen || !tlen) return 0;
    if (b <= a) return 0;
    return (b - a) / 1000000000ULL;
}

/* The bucket ladder. Widths a person recognises rather than whatever falls
 * out of dividing the window: "every 37 seconds" is a correct answer and an
 * unreadable axis. */
typedef struct { po_u64 secs; const char *name; } po_plot_step;

static const po_plot_step PO_PLOT_LADDER[] = {
    { 1,     "1s"  }, { 5,     "5s"  }, { 10,    "10s" }, { 30,    "30s" },
    { 60,    "1m"  }, { 300,   "5m"  }, { 600,   "10m" }, { 1800,  "30m" },
    { 3600,  "1h"  }, { 10800, "3h"  }, { 21600, "6h"  }, { 43200, "12h" },
    { 86400, "1d"  }
};
#define PO_PLOT_NLADDER (sizeof(PO_PLOT_LADDER) / sizeof(PO_PLOT_LADDER[0]))

/* Aim for roughly eighty bars: enough to show a shape, few enough that each
 * is wide enough to see and to hit with a pointer. */
static const char *po_plot_bucket_for(const char *from, size_t flen,
                                      const char *to, size_t tlen) {
    po_u64 secs = po_plot_span_seconds(from, flen, to, tlen);
    size_t i;
    double want;

    if (!secs) return "1m";
    want = (double)secs / 80.0;
    for (i = 0; i < PO_PLOT_NLADDER; i++)
        if ((double)PO_PLOT_LADDER[i].secs >= want) return PO_PLOT_LADDER[i].name;
    return PO_PLOT_LADDER[PO_PLOT_NLADDER - 1].name;
}

/* COLOUR IS NAMED BY ROLE, NEVER BY VALUE.
 *
 * "series:2" is resolved against the stylesheet's custom properties in the
 * browser, at draw time. A figure carrying a hex would be a figure that is
 * wrong in one of the two themes, and the server has no idea which theme the
 * reader is in - nor whether they are about to change it. */
static const char *po_plot_role(int i) {
    static const char *const R[8] = {
        "series:0", "series:1", "series:2", "series:3",
        "series:4", "series:5", "series:6", "series:7"
    };
    return R[((i % 8) + 8) % 8];
}

/* OTLP's twenty-four point severity scale, in the six bands it is defined in.
 *
 * Writes into `out` and returns its length, because two of the answers are
 * not constants: a severity outside the scale is reported AS ITSELF rather
 * than folded into a band, and something that is not a number at all is
 * `unlabelled`. Both exist so that a row with an unexpected severity still
 * appears on the screen somebody opened to find it - a bar silently dropped
 * because its band was unrecognised is the one they were looking for.
 *
 * `out` needs 32 bytes. */
static size_t po_plot_severity_name(const char *s, size_t len, char *out) {
    po_u64 n = 0;
    size_t i;
    const char *name = NULL;

    if (!s || !len) { memcpy(out, "unlabelled", 10); return 10; }
    for (i = 0; i < len; i++) {
        if (s[i] < '0' || s[i] > '9') { memcpy(out, "unlabelled", 10); return 10; }
        n = n * 10 + (po_u64)(s[i] - '0');
        if (n > 1000000) break;          /* not a severity; still not a crash */
    }

    if      (n >= 1  && n <= 4)  name = "trace";
    else if (n >= 5  && n <= 8)  name = "debug";
    else if (n >= 9  && n <= 12) name = "info";
    else if (n >= 13 && n <= 16) name = "warn";
    else if (n >= 17 && n <= 20) name = "error";
    else if (n >= 21 && n <= 24) name = "fatal";

    if (name) { size_t l = strlen(name); memcpy(out, name, l); return l; }
    {
        size_t o = 9;
        memcpy(out, "severity ", 9);
        if (len > 20) len = 20;
        memcpy(out + o, s, len);
        return o + len;
    }
}

/* The six band names, in the order a stacked chart wants them: least severe
 * at the bottom, so the eye lands on the top of the stack. */
static const char *const PO_PLOT_BANDS[6] = {
    "trace", "debug", "info", "warn", "error", "fatal"
};

#endif /* PO_PLOT_H */
