/* po_svg.h - charts, generated in C, emitted as inline SVG.
 *
 * Server-rendered because that puts the work where the data already is, which
 * matters when a chart is four thousand points. It also means every chart is
 * in the HTML: it prints, it survives a screenshot, and it renders with
 * scripting off.
 *
 * THE FORMATTER IS HAND-ROLLED, AND THAT IS THE POINT OF THIS FILE.
 *
 * Every coordinate here is a computed double, and the obvious way to write
 * one into a path is sprintf("%f"). In this codebase that is the single most
 * dangerous line available:
 *
 *   - A Perl-flavoured formatter (croak, warn, sv_catpvf, my_snprintf) reads
 *     an NV for %f. Passing a C double panics the quadmath smokers and reads
 *     silent garbage on x86_64.
 *   - The Windows CRT prints three-digit exponents: `1e-005`. An SVG path
 *     containing that is not a valid path, and the chart simply does not
 *     draw - on one platform, with no error.
 *   - %f also emits six decimals for every number, which triples the size of
 *     a path nobody can read anyway.
 *
 * So po_fmt below writes a fixed-point decimal itself, with no library call,
 * no exponent form possible, and two decimals. t/0092-svg.t greps the output
 * for exponent forms and fails if one appears.
 */
#ifndef PO_SVG_H
#define PO_SVG_H

#include "punk_observe/po_compat.h"

#define PO_SVG_MAX 2048

/* Write `v` with two decimals into `out` (at least 32 bytes). Returns the
 * length. No sprintf, no locale, no exponent, ever.
 *
 * Values are clamped to a range a chart can contain. A NaN or an infinity
 * reaching a coordinate is a bug upstream, but it must not produce `nan` in
 * an attribute - that kills the whole path rather than one point. */
static size_t po_fmt(double v, char *out) {
    char tmp[24];
    size_t n = 0;
    int neg = 0;
    po_u64 whole, frac;

    /* NaN is the only value not equal to itself. */
    if (!(v == v)) v = 0;
    if (v >  1e9) v =  1e9;
    if (v < -1e9) v = -1e9;

    if (v < 0) { neg = 1; v = -v; }
    whole = (po_u64)v;
    frac  = (po_u64)((v - (double)whole) * 100.0 + 0.5);
    if (frac >= 100) { whole++; frac -= 100; }

    if (neg && (whole || frac)) out[n++] = '-';
    if (whole == 0) out[n++] = '0';
    else {
        size_t t = 0;
        while (whole) { tmp[t++] = (char)('0' + (int)(whole % 10)); whole /= 10; }
        while (t) out[n++] = tmp[--t];
    }
    if (frac) {
        out[n++] = '.';
        out[n++] = (char)('0' + (int)(frac / 10));
        if (frac % 10) out[n++] = (char)('0' + (int)(frac % 10));
        /* a trailing zero is noise: 1.50 and 1.5 draw identically */
        if (out[n - 1] == '0') n--;
    }
    out[n] = '\0';
    return n;
}

/* An integer, for counts and indices. */
static size_t po_fmt_i(po_u64 v, char *out) {
    char tmp[24];
    size_t n = 0, t = 0;
    if (v == 0) { out[0] = '0'; out[1] = '\0'; return 1; }
    while (v) { tmp[t++] = (char)('0' + (int)(v % 10)); v /= 10; }
    while (t) out[n++] = tmp[--t];
    out[n] = '\0';
    return n;
}

/* ---- escaping -------------------------------------------------------------
 *
 * SVG ATTRIBUTE CONTEXT IS NOT HTML TEXT CONTEXT.
 *
 * A span name is untrusted input and it goes into both. In text, `<` and `&`
 * matter. In an attribute, the QUOTE matters most: a name containing one ends
 * the attribute early and everything after it becomes markup. Stencil
 * autoescapes for HTML; nothing autoescapes for the attribute of an element
 * this file builds by hand, so it is done here.
 */
static size_t po_esc_attr(const char *p, size_t len, char *out, size_t cap) {
    size_t n = 0, i;
    for (i = 0; i < len && n + 8 < cap; i++) {
        unsigned char c = (unsigned char)p[i];
        switch (c) {
            case '"':  memcpy(out + n, "&quot;", 6); n += 6; break;
            case '\'': memcpy(out + n, "&#39;",  5); n += 5; break;
            case '&':  memcpy(out + n, "&amp;",  5); n += 5; break;
            case '<':  memcpy(out + n, "&lt;",   4); n += 4; break;
            case '>':  memcpy(out + n, "&gt;",   4); n += 4; break;
            default:
                /* Control characters are dropped rather than escaped: they
                 * cannot appear in a valid name and a numeric entity for one
                 * is not valid XML either. */
                if (c >= 0x20 || c == '\t') out[n++] = (char)c;
                break;
        }
    }
    out[n] = '\0';
    return n;
}

/* ---- nice numbers ---------------------------------------------------------
 *
 * An axis labelled 0, 33.33, 66.67, 100 is a chart nobody can read. The
 * classic algorithm: round the range to a "nice" magnitude, then pick a step
 * from {1, 2, 5} times a power of ten.
 */
static double po_nice_num(double range, int round_it) {
    double expo, f, nf;
    if (range <= 0) return 1;
    expo = 0;
    { double r = range;
      while (r >= 10) { r /= 10; expo += 1; }
      while (r < 1)   { r *= 10; expo -= 1; }
      f = r; }
    if (round_it) nf = f < 1.5 ? 1 : f < 3 ? 2 : f < 7 ? 5 : 10;
    else          nf = f <= 1  ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10;
    { double p = 1; int i;
      if (expo > 0) for (i = 0; i < (int)expo; i++) p *= 10;
      else          for (i = 0; i < -(int)expo; i++) p /= 10;
      return nf * p; }
}

typedef struct {
    double lo, hi, step;
    double tick[16];
    int    n;
} po_axis;

/* Choose an axis covering [min, max] with about `want` ticks. */
static void po_axis_make(po_axis *a, double min, double max, int want) {
    double range, i;
    memset(a, 0, sizeof(*a));
    if (want < 2) want = 2;
    if (want > 15) want = 15;

    /* A flat series is a real case - a gauge that has not moved - and
     * range 0 would divide by zero. Give it a band around the value so the
     * line sits in the middle instead of on an edge. */
    if (!(max > min)) {
        double v = (max == max) ? max : 0;
        double pad = v != 0 ? (v < 0 ? -v : v) * 0.1 : 1;
        min = v - pad;
        max = v + pad;
    }

    range   = po_nice_num(max - min, 0);
    a->step = po_nice_num(range / (want - 1), 1);
    a->lo   = a->step * (double)(po_i64)(min / a->step - (min < 0 ? 1 : 0));
    a->hi   = a->step * (double)(po_i64)(max / a->step + (max > 0 ? 1 : 0));
    if (a->lo > min) a->lo -= a->step;
    if (a->hi < max) a->hi += a->step;

    for (i = a->lo; i <= a->hi + a->step * 0.5 && a->n < 16; i += a->step)
        a->tick[a->n++] = i;
}

/* ---- paths ---------------------------------------------------------------- */

typedef struct {
    char  *b;
    size_t n, cap;
    int    err;
} po_svg;

static int po_svg_init(po_svg *s, size_t hint) {
    memset(s, 0, sizeof(*s));
    s->cap = hint ? hint : 1024;
    s->b = (char *)malloc(s->cap);
    if (s->b) s->b[0] = '\0';
    return s->b != NULL;
}
static void po_svg_free(po_svg *s) { free(s->b); s->b = NULL; }

static void po_svg_put(po_svg *s, const char *p, size_t n) {
    if (s->err) return;
    if (s->n + n + 1 > s->cap) {
        size_t want = s->cap * 2;
        char *nb;
        while (want < s->n + n + 1) want *= 2;
        nb = (char *)realloc(s->b, want);
        if (!nb) { s->err = 1; return; }
        s->b = nb; s->cap = want;
    }
    memcpy(s->b + s->n, p, n);
    s->n += n;
    s->b[s->n] = '\0';
}
static void po_svg_s(po_svg *s, const char *p) { po_svg_put(s, p, strlen(p)); }
static void po_svg_n(po_svg *s, double v) {
    char t[32];
    size_t n = po_fmt(v, t);
    po_svg_put(s, t, n);
}

/* A polyline through the points, scaled into a viewport. Returns the path's
 * `d` attribute value. */
static void po_svg_line(po_svg *s, const double *x, const double *y, int n,
                        double x0, double x1, double y0, double y1,
                        double w, double h) {
    int i;
    double xs = (x1 > x0) ? w / (x1 - x0) : 0;
    double ys = (y1 > y0) ? h / (y1 - y0) : 0;
    for (i = 0; i < n; i++) {
        po_svg_s(s, i ? " L" : "M");
        po_svg_n(s, (x[i] - x0) * xs);
        po_svg_s(s, " ");
        /* SVG y grows downward; a chart's does not. */
        po_svg_n(s, h - (y[i] - y0) * ys);
    }
}

#endif /* PO_SVG_H */
