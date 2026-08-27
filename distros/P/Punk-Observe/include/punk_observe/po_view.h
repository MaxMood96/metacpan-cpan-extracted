/* po_view.h - the formatting every screen does once per row.
 *
 * Nine small functions, and their smallness is the point: they are called
 * once per row per column, so a page of two thousand log lines runs them ten
 * thousand times. In Perl that is ten thousand sub calls, ten thousand
 * regular expressions and a scalar allocated for each.
 *
 * A NANOSECOND TIMESTAMP IS A DECIMAL STRING, NOT A NUMBER.
 *
 * Past 2^53 a double has lost the low digits, so splitting an instant into
 * seconds and a fraction by dividing by a billion is the bug that renders two
 * lines a microsecond apart as the same time. The split is done on the digits
 * here, exactly as the Perl did it, and the seconds go to a calendar
 * conversion that is integer arithmetic throughout.
 *
 * THE CALENDAR IS COMPUTED, NOT ASKED FOR.
 *
 * `gmtime` is not thread-safe, `gmtime_r` is POSIX and absent on MSVC, and
 * `gmtime_s` is MSVC's with the arguments the other way round. Rather than
 * three spellings behind two probes, the civil date is computed from the day
 * number directly - it is a dozen lines of integer arithmetic, correct for
 * any year, and the same on every platform.
 */
#ifndef PO_VIEW_H
#define PO_VIEW_H

#include "punk_observe/po_compat.h"

/* ---- severity and span kind ----------------------------------------------
 *
 * OTLP's severity is a 24-point scale in six bands of four. The BAND is what
 * a person reads and what the stylesheet colours; the number is what sorts
 * and what a query compares. Both are kept, and this is the mapping between
 * them. */
static const char *po_severity_name(int n) {
    if (n >= 1  && n <= 4)  return "trace";
    if (n >= 5  && n <= 8)  return "debug";
    if (n >= 9  && n <= 12) return "info";
    if (n >= 13 && n <= 16) return "warn";
    if (n >= 17 && n <= 20) return "error";
    if (n >= 21 && n <= 24) return "fatal";
    return "unset";
}

/* OTLP SpanKind. 0 is UNSPECIFIED and 1 is INTERNAL, and both render as
 * internal: a span that did not say is not a different kind of span, it is a
 * span nobody labelled. */
static const char *po_span_kind_name(int k) {
    switch (k) {
        case 2: return "server";
        case 3: return "client";
        case 4: return "producer";
        case 5: return "consumer";
        default: return "internal";
    }
}

/* ---- the calendar, from a day number ------------------------------------
 *
 * Howard Hinnant's civil_from_days, which is exact for any year and needs no
 * table and no library. The era arithmetic is what makes it branch-free
 * across century leap years - the case a hand-rolled version gets wrong once
 * every hundred years and nobody notices for a while. */
static void po_civil(po_i64 days, int *y, int *m, int *d) {
    po_i64 z = days + 719468;
    po_i64 era = (z >= 0 ? z : z - 146096) / 146097;
    po_u64 doe = (po_u64)(z - era * 146097);
    po_u64 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    po_i64 yy  = (po_i64)yoe + era * 400;
    po_u64 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    po_u64 mp  = (5 * doy + 2) / 153;
    po_u64 dd  = doy - (153 * mp + 2) / 5 + 1;
    po_u64 mm  = mp + (mp < 10 ? 3 : -9);
    *y = (int)(yy + (mm <= 2 ? 1 : 0));
    *m = (int)mm;
    *d = (int)dd;
}

/* Split a decimal nanosecond string into whole seconds and the fraction.
 *
 * On the DIGITS. The seconds still have to fit a 64-bit integer to be turned
 * into a date, which they do for any year this side of the sun going out. */
static int po_ns_split(const char *ns, size_t len, po_u64 *secs, char frac[10]) {
    size_t i;
    size_t whole;

    if (!ns || !len) return 0;
    for (i = 0; i < len; i++) if (ns[i] < '0' || ns[i] > '9') return 0;

    if (len > 9) {
        whole = len - 9;
        memcpy(frac, ns + whole, 9);
    }
    else {
        whole = 0;
        /* Fewer than ten digits is a sub-second instant: pad on the LEFT, or
         * "5" nanoseconds renders as half a second. */
        memset(frac, '0', 9 - len);
        memcpy(frac + (9 - len), ns, len);
    }
    frac[9] = '\0';

    *secs = 0;
    for (i = 0; i < whole; i++) {
        if (*secs > (PO_U64_MAX - (po_u64)(ns[i] - '0')) / 10) return 0;
        *secs = *secs * 10 + (po_u64)(ns[i] - '0');
    }
    return 1;
}

/* HH:MM:SS.mmm, which is what a log line wants: the date is the same for
 * every row on the page and the milliseconds are what tell two of them
 * apart. */
static size_t po_fmt_time(const char *ns, size_t len, char *out) {
    po_u64 secs = 0;
    char frac[10];
    po_u64 sod;

    if (!po_ns_split(ns, len, &secs, frac)) { out[0] = '\0'; return 0; }
    sod = secs % 86400;
    out[0] = (char)('0' + (int)(sod / 36000));
    out[1] = (char)('0' + (int)((sod / 3600) % 10));
    out[2] = ':';
    out[3] = (char)('0' + (int)((sod % 3600) / 600));
    out[4] = (char)('0' + (int)((sod % 3600) / 60 % 10));
    out[5] = ':';
    out[6] = (char)('0' + (int)((sod % 60) / 10));
    out[7] = (char)('0' + (int)(sod % 10));
    out[8] = '.';
    out[9]  = frac[0];
    out[10] = frac[1];
    out[11] = frac[2];
    out[12] = '\0';
    return 12;
}

/* The whole instant, for a detail page where there is only one of them. */
static size_t po_fmt_date(const char *ns, size_t len, char *out) {
    po_u64 secs = 0;
    char frac[10];
    po_i64 days;
    po_u64 sod;
    int y, m, d;
    size_t n = 0;

    if (!po_ns_split(ns, len, &secs, frac)) { out[0] = '\0'; return 0; }
    days = (po_i64)(secs / 86400);
    sod  = secs % 86400;
    po_civil(days, &y, &m, &d);

    {   /* %04d-%02d-%02d %02d:%02d:%02dZ, without a formatter */
        int parts[6];
        int widths[6] = { 4, 2, 2, 2, 2, 2 };
        const char *seps = "-- ::";
        int i, j;
        parts[0] = y; parts[1] = m; parts[2] = d;
        parts[3] = (int)(sod / 3600);
        parts[4] = (int)((sod / 60) % 60);
        parts[5] = (int)(sod % 60);
        for (i = 0; i < 6; i++) {
            int v = parts[i], w = widths[i];
            for (j = w - 1; j >= 0; j--) { out[n + j] = (char)('0' + v % 10); v /= 10; }
            n += (size_t)w;
            if (i < 5) out[n++] = seps[i];
        }
        out[n++] = 'Z';
        out[n] = '\0';
    }
    return n;
}

/* A duration in the unit a person would say it in, and NEVER an exponent:
 * `3.26s`, `812ms`, `40us`. A path attribute or a table cell containing
 * `1e-05` is a cell nobody can read and, in an SVG, one that stops the chart
 * drawing at all. */
/* n / d, rounded half to even. */
static po_u64 po_div_round_even(po_u64 n, po_u64 d) {
    po_u64 q = n / d, r = n % d;
    po_u64 half = d / 2;
    if (r > half) return q + 1;
    if (r < half) return q;
    return (q & 1) ? q + 1 : q;      /* exactly half: to the even quotient */
}

static size_t po_fmt_dur(po_u64 ns, char *out) {
    po_u64 v;
    int frac_digits = 0;
    const char *unit;
    size_t n = 0;
    char tmp[24];
    size_t t = 0;

    if (!ns) { out[0] = '0'; out[1] = '\0'; return 1; }

    /* ROUND HALF TO EVEN, which is what printf's %.0f does and therefore
     * what every duration on every page has always shown. Half-up is the
     * obvious spelling and differs on exactly the .5 cases - 500ns renders
     * as 0us either way it is argued, and changing it during a port would be
     * a silent difference in output nobody asked for. */
    if (ns < 1000000ULL) {
        v = po_div_round_even(ns, 1000);
        unit = "us";
    }
    else if (ns < 1000000000ULL) {
        v = po_div_round_even(ns, 1000000);
        unit = "ms";
    }
    else {
        /* seconds to two decimals, which is where the fraction appears */
        v = po_div_round_even(ns, 10000000);      /* hundredths */
        unit = "s";
        frac_digits = 2;
    }

    if (frac_digits) {
        po_u64 whole = v / 100, cents = v % 100;
        if (!whole) tmp[t++] = '0';
        else { char w[24]; size_t k = 0;
               while (whole) { w[k++] = (char)('0' + (int)(whole % 10)); whole /= 10; }
               while (k) tmp[t++] = w[--k]; }
        tmp[t++] = '.';
        tmp[t++] = (char)('0' + (int)(cents / 10));
        tmp[t++] = (char)('0' + (int)(cents % 10));
    }
    else if (!v) tmp[t++] = '0';
    else {
        char w[24]; size_t k = 0;
        while (v) { w[k++] = (char)('0' + (int)(v % 10)); v /= 10; }
        while (k) tmp[t++] = w[--k];
    }

    memcpy(out, tmp, t); n = t;
    while (*unit) out[n++] = *unit++;
    out[n] = '\0';
    return n;
}

/* Thousands separators. A five-figure count with no commas is a number
 * people misread by an order of magnitude. */
static size_t po_fmt_count(const char *s, size_t len, char *out, size_t cap) {
    size_t i, n = 0, digits = 0;
    for (i = 0; i < len; i++) if (s[i] >= '0' && s[i] <= '9') digits++;
    if (digits != len || !len) {
        size_t k = len < cap - 1 ? len : cap - 1;
        memcpy(out, s, k); out[k] = '\0';
        return k;
    }
    for (i = 0; i < len; i++) {
        if (i && (len - i) % 3 == 0 && n + 1 < cap) out[n++] = ',';
        if (n + 1 < cap) out[n++] = s[i];
    }
    out[n] = '\0';
    return n;
}

/* Percent-encoding for a query string.
 *
 * NOT HTML escaping, which the template does afterwards, and not the same
 * job: a `+` left as a plus is a SPACE by the time the form comes back, and
 * the query that returns is not the query that was sent. */
static size_t po_url_esc(const char *s, size_t len, char *out, size_t cap) {
    static const char hex[] = "0123456789ABCDEF";
    size_t i, n = 0;
    for (i = 0; i < len; i++) {
        unsigned char c = (unsigned char)s[i];
        int safe = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
                || (c >= '0' && c <= '9')
                || c == '-' || c == '_' || c == '.' || c == '~';
        if (safe) { if (n + 1 < cap) out[n++] = (char)c; }
        else if (n + 3 < cap) {
            out[n++] = '%';
            out[n++] = hex[c >> 4];
            out[n++] = hex[c & 15];
        }
    }
    out[n] = '\0';
    return n;
}

/* A percentage of a span, clamped. Charts hand this a zero range more often
 * than anything else - one point, or a gauge that has not moved - and a
 * division by it is the whole chart gone rather than one bar. */
static double po_pct(po_u64 v, po_u64 total) {
    po_u64 p;
    if (!total) return 0;
    /* A WHOLE number, truncated, which is what this has always returned. A
     * bar is positioned in CSS percent and a fraction of one percent is
     * under a pixel on any screen - but changing the value during a port
     * would move every bar on every chart by a hair, for nothing. */
    p = 100 * v / total;
    return (double)(p > 100 ? 100 : p);
}

/* A byte count in the unit a person would say it in.
 *
 * The boundary is 1024, not 1000: this counts what a store occupies, and
 * every tool an operator would compare it against - du, ls, df - uses the
 * binary one. Being right about the SI meaning of a kilobyte and wrong about
 * the number on the next terminal is the worse answer. */
static size_t po_fmt_bytes(po_u64 n, char *out) {
    static const char *UNIT[] = { " B", " KB", " MB", " GB" };
    po_u64 div = 1;
    int u = 0;
    size_t k = 0;
    po_u64 whole, tenth;
    char tmp[24];
    size_t t = 0;

    while (u < 3 && n / div >= 1024) { div *= 1024; u++; }

    if (!u) {                       /* bytes: no fraction at all */
        po_u64 v = n;
        if (!v) tmp[t++] = '0';
        else { char w[24]; size_t z = 0;
               while (v) { w[z++] = (char)('0' + (int)(v % 10)); v /= 10; }
               while (z) tmp[t++] = w[--z]; }
        memcpy(out, tmp, t); k = t;
    }
    else {
        /* One decimal, rounded half to even like the %.1f it replaces. */
        po_u64 tenths = po_div_round_even(n * 10, div);
        whole = tenths / 10;
        tenth = tenths % 10;
        if (!whole) tmp[t++] = '0';
        else { char w[24]; size_t z = 0;
               while (whole) { w[z++] = (char)('0' + (int)(whole % 10)); whole /= 10; }
               while (z) tmp[t++] = w[--z]; }
        tmp[t++] = '.';
        tmp[t++] = (char)('0' + (int)tenth);
        memcpy(out, tmp, t); k = t;
    }
    {
        const char *up = UNIT[u];
        while (*up) out[k++] = *up++;
    }
    out[k] = '\0';
    return k;
}

/* ---- chart coordinates ----------------------------------------------------
 *
 * The x of a point, as a fraction of the window.
 *
 * THE SUBTRACTION IS ON INTEGERS. The Perl this replaces wrote
 * `($row->{t} - $t0) / ($t1 - $t0)`, which converts two nanosecond instants
 * to doubles first and loses their low digits before the difference is even
 * taken. On a 720-pixel chart the error is far under a pixel, so nothing was
 * ever visibly wrong - but it is the same mistake the rest of this
 * distribution goes out of its way to avoid, and the fix costs nothing:
 * subtract first, in the type that holds them, then divide once. */
static double po_chart_x(po_u64 t, po_u64 t0, po_u64 t1, double width) {
    po_u64 span = t1 > t0 ? t1 - t0 : 1;
    po_u64 off  = t > t0 ? t - t0 : 0;
    if (off > span) off = span;
    return (double)off / (double)span * width;
}

/* The y of a value, flipped: y grows DOWNWARD in SVG and upward on a chart. */
static double po_chart_y(double v, double lo, double hi, double height) {
    double range = hi - lo;
    if (range <= 0) range = 1;
    return height - height * (v - lo) / range;
}

/* ---- the time window ------------------------------------------------------
 *
 * THE DEFAULT IS AN HOUR AND THE CONTROL IS NOT OPTIONAL.
 *
 * A page that reads everything gets slower every day it runs, so the default
 * has to be bounded. But a bounded default with no way to widen it is a dead
 * end: what it says to somebody whose data is from this morning is "No traces
 * in this window", which reads as "there is no data" and is a different and
 * wrong answer.
 *
 * `all` is unbounded on purpose and is the only range that is. Nothing
 * downstream special-cases it - an absent bound is the store's own "no
 * limit", so the scan simply does not skip on time. */
typedef struct { const char *key; po_u64 secs; const char *label; } po_range;

static const po_range PO_RANGES[] = {
    { "15m", 900,       "last 15 minutes" },
    { "1h",  3600,      "last hour"       },
    { "6h",  21600,     "last 6 hours"    },
    { "24h", 86400,     "last 24 hours"   },
    { "7d",  604800,    "last 7 days"     },
    { "30d", 2592000,   "last 30 days"    },
    { "all", 0,         "everything"      }
};
#define PO_NRANGES (int)(sizeof(PO_RANGES) / sizeof(PO_RANGES[0]))

static const po_range *po_range_find(const char *k, size_t len) {
    int i;
    if (!k || !len) return NULL;
    for (i = 0; i < PO_NRANGES; i++) {
        size_t n = strlen(PO_RANGES[i].key);
        if (n == len && memcmp(PO_RANGES[i].key, k, n) == 0) return &PO_RANGES[i];
    }
    return NULL;
}

/* An explicit bound is only honoured when it is a plausible nanosecond
 * instant: all digits and more than nine of them. Fewer than ten digits is
 * under a second past the epoch, which is not a range anybody asked for -
 * it is a truncated or mis-parsed parameter, and honouring it would show an
 * empty page for a reason nobody could see. */
static int po_ns_plausible(const char *s, size_t len) {
    size_t i;
    if (!s || len < 10) return 0;
    for (i = 0; i < len; i++) if (s[i] < '0' || s[i] > '9') return 0;
    return 1;
}

/* THE DURATION BOX.
 *
 * A DURATION TYPED BY A PERSON, in nanoseconds, and WHICH END IT BOUNDS.
 * Returns 1 and sets *ns and *is_max when the text is a duration, 0 when it
 * is empty - which is not a filter, and not an error - and -1 when it is text
 * that was meant to be a duration and is not.
 *
 * The third case is the reason this exists. The box used to accept /\A\d+\z/
 * and drop anything else on the floor, so typing the placeholder's own words
 * back at it - "slower than 100" - removed the filter and said nothing. The
 * page showed a full unfiltered table, which is the one outcome that looks
 * like an answer. A refusal is worse than a filter and far better than a
 * silent one.
 *
 * A bare number is MILLISECONDS, because the field is named min_ms and that
 * is what it has always meant. A unit overrides it, and the units are the
 * query language's own, so `500ms` in the box and `duration > 500ms` in a
 * query cannot disagree.
 *
 * `>` and `>=` bound the SLOW end, `<` and `<=` the fast one - "faster than
 * 100ms" is a question about the same column and there is no reason one
 * direction should be askable and the other not.
 *
 * THE BOUND IS INCLUSIVE EITHER WAY. A strict bound differs from an
 * inclusive one by a single nanosecond, which is not a distinction a filter
 * box can usefully make; the query language is where an exact comparison
 * belongs, and it has one.
 */
static int po_min_duration(const char *s, size_t len, po_u64 *ns, int *is_max) {
    size_t i = 0, j, ds, de;
    po_u64 whole = 0, unit;
    po_u64 frac_num = 0, frac_den = 1;

    *ns = 0;
    *is_max = 0;
    if (!s) return 0;
    while (i < len && (s[i] == ' ' || s[i] == '\t')) i++;
    while (len > i && (s[len-1] == ' ' || s[len-1] == '\t')) len--;
    if (i >= len) return 0;

    /* The comparison, if one was typed. Which end it bounds is the whole of
     * the difference between "slower than 100ms" and "faster than 100ms", and
     * both are ordinary things to want. No operator means the slow end, which
     * is what the box has always meant on its own. */
    if (s[i] == '>' || s[i] == '<') {
        *is_max = (s[i] == '<');
        i++;
        if (i < len && s[i] == '=') i++;
    }
    while (i < len && s[i] == ' ') i++;
    if (i >= len) return -1;

    ds = i;
    while (i < len && s[i] >= '0' && s[i] <= '9') {
        /* Bounded here only so the accumulator cannot wrap; whether the
         * number is actually representable depends on the unit, and that is
         * not known until after the suffix. */
        po_u64 d = (po_u64)(s[i] - '0');
        if (whole > (~(po_u64)0 - d) / 10) return -1;
        whole = whole * 10 + d;
        i++;
    }
    de = i;
    if (de == ds) return -1;               /* no digits at all: prose */

    /* A fraction, so `1.5s` works. Capped at nine places, which is the whole
     * resolution there is. */
    if (i < len && s[i] == '.') {
        i++;
        for (j = 0; i < len && s[i] >= '0' && s[i] <= '9'; i++, j++) {
            if (j < 9) { frac_num = frac_num * 10 + (po_u64)(s[i] - '0');
                         frac_den *= 10; }
        }
        if (!j) return -1;                 /* "5." is a typo, not a duration */
    }

    while (i < len && s[i] == ' ') i++;

    if (i == len) unit = 1000000ULL;       /* bare number: milliseconds */
    else {
        unit = po_dur_unit(s + i, len - i);
        if (!unit) return -1;              /* a suffix that is not a unit */
    }

    /* `4000000000w` is a number and a unit and still not a duration. Refusing
     * it is the same decision as refusing prose: the alternative is a wrapped
     * value, which is a filter that runs and means something else. */
    if (whole > (po_u64)~(po_u64)0 / unit) return -1;

    *ns = whole * unit + (frac_num * unit) / frac_den;
    return 1;
}

#endif /* PO_VIEW_H */
