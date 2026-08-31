MODULE = Punk::Observe   PACKAGE = Punk::Observe::Plot   PREFIX = popl_

# Milliseconds since the epoch, for a chart axis.
#
# The last six digits are DROPPED as characters rather than divided away:
# dividing a nanosecond instant by a million in Perl rounds it BEFORE the
# division, and the error lands in the digits a chart is drawn from.
SV *
popl_ms(SV *ns)
    CODE:
    {
        STRLEN len = 0;
        const char *p = SvOK(ns) ? SvPV(ns, len) : NULL;
        po_u64 v = po_plot_ms(p, (size_t)len);
        /* An IV where it fits, as perl's own numification gave, so the JSON
         * says 1787000000000 rather than 1.787e+12. */
        RETVAL = (v <= (po_u64)IV_MAX) ? newSViv((IV)v) : newSVnv((NV)v);
    }
    OUTPUT:
        RETVAL

# The bucket width for a window, off a ladder of widths a person recognises.
SV *
popl_bucket_for(SV *from, SV *to)
    CODE:
    {
        STRLEN fl = 0, tl = 0;
        const char *fp = SvOK(from) ? SvPV(from, fl) : NULL;
        const char *tp = SvOK(to)   ? SvPV(to,   tl) : NULL;
        RETVAL = newSVpv(po_plot_bucket_for(fp, (size_t)fl, tp, (size_t)tl), 0);
    }
    OUTPUT:
        RETVAL

SV *
popl__span_seconds(SV *from, SV *to)
    CODE:
    {
        STRLEN fl = 0, tl = 0;
        const char *fp = SvOK(from) ? SvPV(from, fl) : NULL;
        const char *tp = SvOK(to)   ? SvPV(to,   tl) : NULL;
        RETVAL = po_u64_to_sv(po_plot_span_seconds(fp, (size_t)fl, tp, (size_t)tl));
    }
    OUTPUT:
        RETVAL

SV *
popl__role(int i)
    CODE:
        RETVAL = newSVpv(po_plot_role(i), 0);
    OUTPUT:
        RETVAL

SV *
popl__severity_name(SV *n)
    CODE:
    {
        STRLEN len = 0;
        const char *p = SvOK(n) ? SvPV(n, len) : NULL;
        char buf[64];
        size_t bn = po_plot_severity_name(p, (size_t)len, buf);
        RETVAL = newSVpvn(buf, bn);
    }
    OUTPUT:
        RETVAL

# The x and y arrays for one series, with the holes filled.
#
# A HOLE IS NOT A GAP IN A LINE. A bucket with nothing in it is a real answer
# for a count - nought arrivals - and an UNDEFINED one for a percentile, which
# is why the caller says which it has rather than this guessing.
void
popl__fill_gaps(SV *points, SV *width, SV *zero_fill, SV *from = &PL_sv_undef, SV *to = &PL_sv_undef)
    PPCODE:
    {
        AV *px = newAV(), *py = newAV();
        AV *pts = NULL;
        SSize_t i, n = 0;
        po_u64 step = 0;
        int zf = SvTRUE(zero_fill);
        int bounded;

        if (SvROK(points) && SvTYPE(SvRV(points)) == SVt_PVAV)
            pts = (AV *)SvRV(points);
        n = pts ? av_len(pts) + 1 : 0;
        if (!n) {
            EXTEND(SP, 2);
            mPUSHs(newRV_noinc((SV *)px));
            mPUSHs(newRV_noinc((SV *)py));
            XSRETURN(2);
        }

        if (SvOK(width)) {
            STRLEN wl;
            const char *wp = SvPV(width, wl);
            step = po_plot_ms(wp, (size_t)wl);
        }
        bounded = zf && step && SvOK(from) && SvOK(to);

        /* The instant of a point, as milliseconds. */
#define POPL_PT_MS(ix, out) do {                                              \
            SV **e_ = av_fetch(pts, (ix), 0);                                 \
            SV **t_ = (e_ && SvROK(*e_) && SvTYPE(SvRV(*e_)) == SVt_PVAV)     \
                        ? av_fetch((AV *)SvRV(*e_), 0, 0) : NULL;             \
            STRLEN tl_ = 0;                                                   \
            const char *tp_ = (t_ && SvOK(*t_)) ? SvPV(*t_, tl_) : "";        \
            (out) = po_plot_ms(tp_, (size_t)tl_);                             \
        } while (0)

        /* THE EDGES OF THE WINDOW, not only the holes between the points.
         *
         * A window whose data all lands in ONE bucket gives a series of one
         * point, and a one-point line is a moveto with nothing after it: the
         * panel drew an empty box. Worse, plotly had no range to work with
         * and auto-scaled the time axis to that single instant, so a chart
         * titled "the last hour" showed a millisecond either side of it. */
        if (bounded) {
            STRLEN fl;
            const char *fp = SvPV(from, fl);
            po_u64 lo = po_plot_ms(fp, (size_t)fl), first;
            SSize_t k = 0;
            POPL_PT_MS(0, first);
            {
                po_u64 t = first;
                while (t >= lo + step && k < 200) { t -= step; k++; }
                for (; k > 0; k--) {
                    av_push(px, po_u64_to_sv(first - (po_u64)k * step));
                    av_push(py, newSViv(0));
                }
            }
        }

        {
            po_u64 prev = 0;
            int have_prev = 0;
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(pts, i, 0);
                AV *row;
                SV **val;
                po_u64 t;

                if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVAV) continue;
                row = (AV *)SvRV(*e);
                POPL_PT_MS(i, t);

                if (have_prev && step) {
                    /* How many whole buckets were skipped. Done on the
                     * millisecond form, which is exact for any gap a chart
                     * can show and avoids big-integer arithmetic for
                     * something only used to count holes. */
                    po_u64 gap = t > prev ? (t - prev) / step : 0;
                    po_u64 k;
                    if (gap) gap--;
                    if (gap > 200) gap = 200;  /* a hole is a hole */
                    for (k = 1; k <= gap; k++) {
                        av_push(px, po_u64_to_sv(prev + k * step));
                        av_push(py, zf ? newSViv(0) : newSV(0));
                    }
                }

                val = av_fetch(row, 1, 0);
                av_push(px, po_u64_to_sv(t));
                av_push(py, povw_num(aTHX_ val ? *val : NULL));
                prev = t;
                have_prev = 1;
            }

            if (bounded && have_prev) {
                STRLEN tl;
                const char *tp = SvPV(to, tl);
                po_u64 hi = po_plot_ms(tp, (size_t)tl);
                po_u64 t = prev + step;
                int k = 0;
                for (; t <= hi && k < 200; t += step, k++) {
                    av_push(px, po_u64_to_sv(t));
                    av_push(py, newSViv(0));
                }
            }
        }
#undef POPL_PT_MS

        EXTEND(SP, 2);
        mPUSHs(newRV_noinc((SV *)px));
        mPUSHs(newRV_noinc((SV *)py));
        XSRETURN(2);
    }

# AN ABSENT KEY AND A NULL ONE ARE NOT THE SAME THING.
#
# A figure that does not want the shared date axis says so with undef, which
# reads as "drop this". Passed through it encodes as JSON `null`, and a
# plotting library handed `xaxis: null` does not fall back to its default - it
# fails, and the panel renders empty with nothing in the markup to show why.
#
# So an undef layout entry is REMOVED rather than serialised. A gauge has no
# axes, and the way to have no axes is to not mention them.
SV *
popl__fig(...)
    CODE:
    {
        HV *out = newHV();
        HV *layout = newHV();
        AV *data = NULL;
        IV i;
        HV *xaxis = newHV();

        /* The base every figure starts from. */
        hv_stores(layout, "hovermode", newSVpvs("x unified"));
        hv_stores(xaxis, "type", newSVpvs("date"));
        hv_stores(layout, "xaxis", newRV_noinc((SV *)xaxis));

        for (i = 0; i + 1 < items; i += 2) {
            const char *k = SvPV_nolen(ST(i));
            SV *v = ST(i + 1);
            if (strEQ(k, "data")) {
                if (SvROK(v) && SvTYPE(SvRV(v)) == SVt_PVAV)
                    data = (AV *)SvRV(v);
            }
            else if (strEQ(k, "layout")
                     && SvROK(v) && SvTYPE(SvRV(v)) == SVt_PVHV) {
                HV *l = (HV *)SvRV(v);
                HE *he;
                hv_iterinit(l);
                while ((he = hv_iternext(l))) {
                    STRLEN kl;
                    char *kp = hv_iterkey(he, (I32 *)&kl);
                    SV *val = hv_iterval(l, he);
                    if (!SvOK(val)) { (void)hv_delete(layout, kp, (I32)kl, G_DISCARD); }
                    else (void)hv_store(layout, kp, (I32)kl, newSVsv(val), 0);
                }
            }
        }

        hv_stores(out, "data",
                  data ? newRV_inc((SV *)data) : newRV_noinc((SV *)newAV()));
        hv_stores(out, "layout", newRV_noinc((SV *)layout));
        RETVAL = newRV_noinc((SV *)out);
    }
    OUTPUT:
        RETVAL

# A LOG AXIS CANNOT DRAW A ZERO, and a chart that silently drops the buckets
# that saw nothing is a chart claiming the quiet periods did not happen.
int
popl__log_is_safe(SV *data)
    CODE:
    {
        AV *d = NULL;
        SSize_t i, n;
        RETVAL = 1;
        if (SvROK(data) && SvTYPE(SvRV(data)) == SVt_PVAV)
            d = (AV *)SvRV(data);
        n = d ? av_len(d) + 1 : 0;
        for (i = 0; i < n && RETVAL; i++) {
            SV **e = av_fetch(d, i, 0);
            SV **y;
            AV *ys;
            SSize_t j, m;
            if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
            y = hv_fetchs((HV *)SvRV(*e), "y", 0);
            if (!y || !SvROK(*y) || SvTYPE(SvRV(*y)) != SVt_PVAV) continue;
            ys = (AV *)SvRV(*y);
            m = av_len(ys) + 1;
            for (j = 0; j < m; j++) {
                SV **v = av_fetch(ys, j, 0);
                if (v && SvOK(*v) && SvNV(*v) <= 0) { RETVAL = 0; break; }
            }
        }
    }
    OUTPUT:
        RETVAL

# One line per series, over time.
SV *
popl_timeseries(SV *res, ...)
    CODE:
    {
        AV *data = newAV();
        HV *r = NULL;
        SV **f;
        SV *width = &PL_sv_undef;
        SV *zero_fill = &PL_sv_undef, *fill = NULL, *unit = NULL, *name = NULL;
        SV *kind = NULL;
        int is_bar = 0, is_area = 0;
        int want_log = 0;
        IV a;
        SSize_t i, n = 0;
        AV *series = NULL;

        for (a = 1; a + 1 < items; a += 2) {
            const char *k = SvPV_nolen(ST(a));
            if      (strEQ(k, "zero_fill")) zero_fill = ST(a + 1);
            else if (strEQ(k, "fill"))      fill = SvOK(ST(a + 1)) ? ST(a + 1) : NULL;
            else if (strEQ(k, "unit"))      unit = ST(a + 1);
            else if (strEQ(k, "name"))      name = ST(a + 1);
            else if (strEQ(k, "log"))       want_log = SvTRUE(ST(a + 1));
            /* WHICH SHAPE THE SAME NUMBERS TAKE. A line, the same line with
             * the area under it filled, or a bar per bucket - one builder,
             * because they differ in two attributes and duplicating three
             * hundred lines to change two is how they come to disagree about
             * the axis, the hover or the gaps. */
            else if (strEQ(k, "kind"))      kind = ST(a + 1);
        }

        if (kind && SvOK(kind)) {
            const char *kp = SvPV_nolen(kind);
            is_bar  = strEQ(kp, "bar");
            is_area = strEQ(kp, "area");
        }
        /* `area` IS a filled, stacked line, which is what `fill` already
         * meant. Saying it twice would let a caller ask for an area chart
         * that is not filled. */
        if (is_area && !fill) fill = sv_2mortal(newSVpvs("tozeroy"));

        if (SvROK(res) && SvTYPE(SvRV(res)) == SVt_PVHV) r = (HV *)SvRV(res);
        if (r) {
            f = hv_fetchs(r, "bucket_ns", 0);
            if (f) width = *f;
            f = hv_fetchs(r, "series", 0);
            if (f && SvROK(*f) && SvTYPE(SvRV(*f)) == SVt_PVAV)
                series = (AV *)SvRV(*f);
        }
        n = series ? av_len(series) + 1 : 0;

        for (i = 0; i < n; i++) {
            SV **e = av_fetch(series, i, 0);
            HV *s, *trace, *line;
            SV **key, **pts;
            SV *xs = NULL, *ys = NULL;
            int got;

            if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
            s = (HV *)SvRV(*e);
            pts = hv_fetchs(s, "points", 0);

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(pts ? newSVsv(*pts) : newRV_noinc((SV *)newAV())));
            XPUSHs(sv_2mortal(newSVsv(width)));
            XPUSHs(sv_2mortal(newSVsv(zero_fill)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::_fill_gaps", G_LIST);
            SPAGAIN;
            if (got >= 2) { ys = SvREFCNT_inc(POPs); xs = SvREFCNT_inc(POPs); }
            else { xs = newRV_noinc((SV *)newAV()); ys = newRV_noinc((SV *)newAV()); }
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;

            trace = newHV();
            if (is_bar) {
                /* A bar has no `mode`; plotly ignores one and a reader
                 * grepping the figure should not find a contradiction. */
                hv_stores(trace, "type", newSVpvs("bar"));
            }
            else {
                hv_stores(trace, "type", newSVpvs("scatter"));
                hv_stores(trace, "mode", newSVpvs("lines"));
            }
            key = hv_fetchs(s, "key", 0);
            hv_stores(trace, "name",
                      (key && SvOK(*key) && SvCUR(*key)) ? newSVsv(*key)
                      : (name && SvOK(name)) ? newSVsv(name) : newSVpvs("value"));
            hv_stores(trace, "x", xs);
            hv_stores(trace, "y", ys);
            /* NOT connectgaps. An undefined bucket is a hole in the data and
             * joining across it draws a line through a period nothing was
             * measured in. */
            hv_stores(trace, "connectgaps", newSViv(0));
            line = newHV();
            hv_stores(line, "color", newSVpv(po_plot_role((int)i), 0));
            hv_stores(line, "width", newSViv(2));
            hv_stores(trace, "line", newRV_noinc((SV *)line));
            if (fill) {
                hv_stores(trace, "fill", newSVsv(fill));
                hv_stores(trace, "stackgroup", newSVpvs("one"));
            }
            av_push(data, newRV_noinc((SV *)trace));
        }

        {
            HV *layout = newHV(), *yaxis = newHV(), *title = newHV();
            SV *args[4];
            int got;
            int logsafe = 0;

            if (want_log) {
                ENTER; SAVETMPS; PUSHMARK(SP);
                XPUSHs(sv_2mortal(newRV_inc((SV *)data)));
                PUTBACK;
                got = call_pv("Punk::Observe::Plot::_log_is_safe", G_SCALAR);
                SPAGAIN;
                logsafe = got ? SvTRUE(POPs) : 0;
                PUTBACK;
                FREETMPS; LEAVE;
                SPAGAIN;
            }

            hv_stores(title, "text",
                      (unit && SvOK(unit)) ? newSVsv(unit) : newSVpvs(""));
            hv_stores(yaxis, "title", newRV_noinc((SV *)title));
            hv_stores(yaxis, "rangemode", newSVpvs("tozero"));
            if (want_log && logsafe) hv_stores(yaxis, "type", newSVpvs("log"));
            /* STACKED, NOT OVERLAID. Two series of bars drawn on top of each
             * other hide one of them completely, and the reader cannot tell
             * that is what happened. */
            if (is_bar) hv_stores(layout, "barmode", newSVpvs("stack"));
            hv_stores(layout, "yaxis", newRV_noinc((SV *)yaxis));
            /* One series needs no legend: the heading already names it. */
            hv_stores(layout, "showlegend",
                      newRV_noinc(newSViv(av_len(data) > 0 ? 1 : 0)));

            args[0] = sv_2mortal(newSVpvs("data"));
            args[1] = sv_2mortal(newRV_inc((SV *)data));
            args[2] = sv_2mortal(newSVpvs("layout"));
            args[3] = sv_2mortal(newRV_noinc((SV *)layout));

            ENTER; SAVETMPS; PUSHMARK(SP);
            { int k; for (k = 0; k < 4; k++) XPUSHs(args[k]); }
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::_fig", G_SCALAR);
            SPAGAIN;
            RETVAL = got ? SvREFCNT_inc(POPs) : newRV_noinc((SV *)newHV());
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
        }
        SvREFCNT_dec((SV *)data);
    }
    OUTPUT:
        RETVAL

# A number for a table cell.
SV *
popl__num(SV *v)
    CODE:
    {
        double d;
        char buf[64];
        int n;

        /* ONE EXIT. An XSRETURN inside a CODE: block returns before xsubpp
         * pushes RETVAL, so the caller gets whatever was on the stack - which
         * is the argument. */
        if (!SvOK(v)) RETVAL = newSVpvs("");
        else {
            d = (double)SvNV(v);
            /* Whole numbers print whole, however large - counts are the
             * common case here and "951" is the answer, not "951.000". */
            if (d == (double)(po_i64)d && (d < 1e15 && d > -1e15))
                RETVAL = newSVpvf("%.0" NVff, (NV)d);
            else {
                n = my_snprintf(buf, sizeof(buf),
                                ((d < 1 && d > -1) ? "%.6f" : "%.3f"), d);
                if (n < 0) n = 0;
                if ((size_t)n >= sizeof(buf)) n = (int)sizeof(buf) - 1;
                /* A trailing run of zeroes, then a bare point. `%.6f` of 0.5
                 * is 0.500000 and the cell wants 0.5. */
                while (n > 0 && buf[n - 1] == '0') n--;
                if (n > 0 && buf[n - 1] == '.') n--;
                RETVAL = newSVpvn(buf, (STRLEN)n);
            }
        }
    }
    OUTPUT:
        RETVAL

# A figure as JSON, for a <script> tag.
#
# `</` IS ESCAPED, and that is not decoration: an HTML parser ends a <script>
# element at the first `</` whatever the JSON around it says, so a log line
# containing `</script>` would close the tag and put the rest of the figure
# into the document as markup. Done in one pass here rather than as a global
# regex over what can be a multi-megabyte string.
SV *
popl_encode(SV *fig)
    CODE:
    {
        SV *json = NULL;
        int n;

        if (!SvROK(fig)) { RETVAL = newSVpvs(""); goto done; }

        ENTER; SAVETMPS; PUSHMARK(SP);
        XPUSHs(fig);
        PUTBACK;
        n = call_pv("File::Raw::JSON::file_json_encode", G_SCALAR | G_EVAL);
        SPAGAIN;
        json = n ? SvREFCNT_inc(POPs) : NULL;
        PUTBACK;
        FREETMPS; LEAVE;
        SPAGAIN;

        if (SvTRUE(ERRSV) || !json || !SvOK(json)) {
            if (json) SvREFCNT_dec(json);
            RETVAL = newSVpvs("");
            goto done;
        }

        {
            STRLEN len;
            const char *p = SvPV(json, len);
            const char *end = p + len;
            const char *run = p;
            SV *out = newSVpvn("", 0);
            /* Grown once: the escape adds one byte per occurrence and there
             * are usually none at all. */
            (void)SvGROW(out, len + 1);
            while (p < end) {
                if (*p == '<' && p + 1 < end && p[1] == '/') {
                    sv_catpvn(out, run, (STRLEN)(p - run + 1));
                    sv_catpvs(out, "\\/");
                    p += 2;
                    run = p;
                    continue;
                }
                p++;
            }
            if (run < end) sv_catpvn(out, run, (STRLEN)(end - run));
            if (SvUTF8(json)) SvUTF8_on(out);
            SvREFCNT_dec(json);
            RETVAL = out;
        }
    done: ;
    }
    OUTPUT:
        RETVAL

# ONE BAR PER GROUP, HORIZONTAL. An aggregate with no time dimension has no
# shape over time, and drawing it as a line would be a chart claiming one.
SV *
popl_bars(SV *groups, ...)
    CODE:
    {
        AV *xs = newAV(), *ys = newAV();
        AV *g = NULL;
        HV *trace = newHV(), *marker = newHV(), *layout = newHV();
        HV *xaxis = newHV(), *yaxis = newHV(), *title = newHV(), *margin = newHV();
        AV *data = newAV();
        SV *unit = NULL;
        SSize_t i, n;
        IV a;
        int got;

        for (a = 1; a + 1 < items; a += 2)
            if (strEQ(SvPV_nolen(ST(a)), "unit")) unit = ST(a + 1);

        if (SvROK(groups) && SvTYPE(SvRV(groups)) == SVt_PVAV)
            g = (AV *)SvRV(groups);
        n = g ? av_len(g) + 1 : 0;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(g, i, 0);
            HV *h;
            SV **k, **v;
            if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
            h = (HV *)SvRV(*e);
            k = hv_fetchs(h, "key", 0);
            /* A group whose key is empty is still a group. `(none)` names it
             * rather than leaving a blank row nobody can click. */
            av_push(ys, (k && SvOK(*k) && SvCUR(*k)) ? newSVsv(*k)
                                                     : newSVpvs("(none)"));
            v = hv_fetchs(h, "value", 0);
            av_push(xs, povw_num(aTHX_ v ? *v : NULL));
        }

        hv_stores(marker, "color", newSVpv(po_plot_role(0), 0));
        hv_stores(trace, "type", newSVpvs("bar"));
        hv_stores(trace, "orientation", newSVpvs("h"));
        hv_stores(trace, "x", newRV_noinc((SV *)xs));
        hv_stores(trace, "y", newRV_noinc((SV *)ys));
        hv_stores(trace, "marker", newRV_noinc((SV *)marker));
        av_push(data, newRV_noinc((SV *)trace));

        hv_stores(title, "text", (unit && SvOK(unit)) ? newSVsv(unit)
                                                      : newSVpvs(""));
        hv_stores(xaxis, "title", newRV_noinc((SV *)title));
        hv_stores(xaxis, "type", newSVpvs("linear"));
        /* Reversed, so the largest group is at the TOP. A bar chart read from
         * the bottom is a bar chart read wrongly. */
        hv_stores(yaxis, "automargin", newRV_noinc(newSViv(1)));
        hv_stores(yaxis, "autorange", newSVpvs("reversed"));
        hv_stores(margin, "l", newSViv(140));
        hv_stores(layout, "xaxis", newRV_noinc((SV *)xaxis));
        hv_stores(layout, "yaxis", newRV_noinc((SV *)yaxis));
        hv_stores(layout, "showlegend", newRV_noinc(newSViv(0)));
        hv_stores(layout, "margin", newRV_noinc((SV *)margin));

        ENTER; SAVETMPS; PUSHMARK(SP);
        XPUSHs(sv_2mortal(newSVpvs("data")));
        XPUSHs(sv_2mortal(newRV_noinc((SV *)data)));
        XPUSHs(sv_2mortal(newSVpvs("layout")));
        XPUSHs(sv_2mortal(newRV_noinc((SV *)layout)));
        PUTBACK;
        got = call_pv("Punk::Observe::Plot::_fig", G_SCALAR);
        SPAGAIN;
        RETVAL = got ? SvREFCNT_inc(POPs) : newRV_noinc((SV *)newHV());
        PUTBACK;
        FREETMPS; LEAVE;
        SPAGAIN;
    }
    OUTPUT:
        RETVAL

# One number against a budget.
#
# NO DIAL WITHOUT A MAXIMUM. A gauge with no ceiling is a number in a circle,
# and the circle claims a bound that is not there.
SV *
popl_gauge(...)
    CODE:
    {
        double value = 0, max = 0, frac;
        SV *title = NULL;
        HV *trace = newHV(), *layout = newHV(), *margin = newHV();
        HV *tt = newHV(), *number = newHV(), *font = newHV();
        HV *g = newHV(), *axis = newHV(), *bar = newHV();
        AV *range = newAV(), *data = newAV();
        IV a;
        int got;

        for (a = 0; a + 1 < items; a += 2) {
            const char *k = SvPV_nolen(ST(a));
            if      (strEQ(k, "value")) value = SvOK(ST(a+1)) ? (double)SvNV(ST(a+1)) : 0;
            else if (strEQ(k, "max"))   max   = SvOK(ST(a+1)) ? (double)SvNV(ST(a+1)) : 0;
            else if (strEQ(k, "title")) title = ST(a + 1);
        }
        if (!(max > 0)) {
            SvREFCNT_dec((SV *)trace); SvREFCNT_dec((SV *)layout);
            SvREFCNT_dec((SV *)margin); SvREFCNT_dec((SV *)tt);
            SvREFCNT_dec((SV *)number); SvREFCNT_dec((SV *)font);
            SvREFCNT_dec((SV *)g); SvREFCNT_dec((SV *)axis);
            SvREFCNT_dec((SV *)bar); SvREFCNT_dec((SV *)range);
            SvREFCNT_dec((SV *)data);
            XSRETURN_UNDEF;
        }
        frac = value / max;

        av_push(range, newSViv(0));
        av_push(range, newSVnv((NV)max));
        hv_stores(axis, "range", newRV_noinc((SV *)range));
        /* The bar changes colour as it approaches the limit, because the
         * number that matters is how close it is, not what it is. */
        hv_stores(bar, "color", newSVpv(frac >= 0.9 ? "sev:error"
                                      : frac >= 0.7 ? "sev:warn"
                                      : po_plot_role(2), 0));
        hv_stores(g, "axis", newRV_noinc((SV *)axis));
        hv_stores(g, "bar", newRV_noinc((SV *)bar));
        hv_stores(g, "borderwidth", newSViv(0));

        hv_stores(font, "size", newSViv(20));
        hv_stores(number, "font", newRV_noinc((SV *)font));
        hv_stores(tt, "text", (title && SvOK(title)) ? newSVsv(title)
                                                     : newSVpvs(""));
        hv_stores(trace, "type", newSVpvs("indicator"));
        hv_stores(trace, "mode", newSVpvs("gauge+number"));
        hv_stores(trace, "value", newSVnv((NV)value));
        hv_stores(trace, "title", newRV_noinc((SV *)tt));
        hv_stores(trace, "number", newRV_noinc((SV *)number));
        hv_stores(trace, "gauge", newRV_noinc((SV *)g));
        av_push(data, newRV_noinc((SV *)trace));

        hv_stores(margin, "l", newSViv(24));
        hv_stores(margin, "r", newSViv(24));
        hv_stores(margin, "t", newSViv(32));
        hv_stores(margin, "b", newSViv(8));
        hv_stores(layout, "margin", newRV_noinc((SV *)margin));
        hv_stores(layout, "height", newSViv(160));
        /* A gauge has NO AXES, and the way to have none is to not mention
         * them: `xaxis: null` is not a default, it is a failure. _fig drops
         * an undef rather than serialising it. */
        hv_stores(layout, "xaxis", newSV(0));
        hv_stores(layout, "yaxis", newSV(0));

        ENTER; SAVETMPS; PUSHMARK(SP);
        XPUSHs(sv_2mortal(newSVpvs("data")));
        XPUSHs(sv_2mortal(newRV_noinc((SV *)data)));
        XPUSHs(sv_2mortal(newSVpvs("layout")));
        XPUSHs(sv_2mortal(newRV_noinc((SV *)layout)));
        PUTBACK;
        got = call_pv("Punk::Observe::Plot::_fig", G_SCALAR);
        SPAGAIN;
        RETVAL = got ? SvREFCNT_inc(POPs) : newRV_noinc((SV *)newHV());
        PUTBACK;
        FREETMPS; LEAVE;
        SPAGAIN;
    }
    OUTPUT:
        RETVAL

# Log volume, stacked by severity band.
SV *
popl_severity_bars(SV *res, ...)
    CODE:
    {
        AV *data = newAV();
        HV *r = NULL;
        SV **f;
        SV *width = &PL_sv_undef;
        SV *unit = NULL;
        AV *series = NULL;
        SSize_t i, n = 0;
        IV a;
        int band, got, role = 0;

        for (a = 1; a + 1 < items; a += 2)
            if (strEQ(SvPV_nolen(ST(a)), "unit")) unit = ST(a + 1);

        if (SvROK(res) && SvTYPE(SvRV(res)) == SVt_PVHV) r = (HV *)SvRV(res);
        if (r) {
            f = hv_fetchs(r, "bucket_ns", 0);
            if (f) width = *f;
            f = hv_fetchs(r, "series", 0);
            if (f && SvROK(*f) && SvTYPE(SvRV(*f)) == SVt_PVAV)
                series = (AV *)SvRV(*f);
        }
        n = series ? av_len(series) + 1 : 0;

        /* The x and y arrays for one series, through the one implementation
         * of gap filling. */
#define POPL_GAPS(sv_pts, xs_out, ys_out) do {                                \
            int g_;                                                           \
            ENTER; SAVETMPS; PUSHMARK(SP);                                    \
            XPUSHs(sv_2mortal((sv_pts) ? newSVsv(sv_pts)                      \
                                       : newRV_noinc((SV *)newAV())));        \
            XPUSHs(sv_2mortal(newSVsv(width)));                               \
            XPUSHs(sv_2mortal(newSViv(1)));                                   \
            PUTBACK;                                                          \
            g_ = call_pv("Punk::Observe::Plot::_fill_gaps", G_LIST);          \
            SPAGAIN;                                                          \
            if (g_ >= 2) { (ys_out) = SvREFCNT_inc(POPs);                     \
                           (xs_out) = SvREFCNT_inc(POPs); }                   \
            else { (xs_out) = newRV_noinc((SV *)newAV());                     \
                   (ys_out) = newRV_noinc((SV *)newAV()); }                   \
            PUTBACK; FREETMPS; LEAVE; SPAGAIN;                                \
        } while (0)

        /* The six bands, in the order a stack wants them: least severe at the
         * bottom, so the eye lands on the top of the stack. */
        for (band = 0; band < 6; band++) {
            const char *want = PO_PLOT_BANDS[band];
            size_t wl = strlen(want);
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(series, i, 0);
                HV *s;
                SV **key, **pts;
                SV *xs = NULL, *ys = NULL;
                HV *trace, *marker;
                STRLEN kl;
                const char *kp;
                char role_buf[32];

                if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
                s = (HV *)SvRV(*e);
                key = hv_fetchs(s, "key", 0);
                if (!key || !SvOK(*key)) continue;
                kp = SvPV(*key, kl);
                if (kl != wl || memcmp(kp, want, wl) != 0) continue;

                pts = hv_fetchs(s, "points", 0);
                POPL_GAPS(pts ? *pts : NULL, xs, ys);

                trace = newHV();
                marker = newHV();
                my_snprintf(role_buf, sizeof(role_buf), "sev:%s", want);
                hv_stores(marker, "color", newSVpv(role_buf, 0));
                hv_stores(trace, "type", newSVpvs("bar"));
                hv_stores(trace, "name", newSVpvn(want, wl));
                hv_stores(trace, "x", xs);
                hv_stores(trace, "y", ys);
                hv_stores(trace, "marker", newRV_noinc((SV *)marker));
                av_push(data, newRV_noinc((SV *)trace));
            }
        }

        /* ANYTHING WHOSE LABEL IS NOT ONE OF THE SIX STILL HAS TO APPEAR. A
         * row dropped because its severity was unexpected is a row the
         * operator cannot see, on the screen they opened to find it. */
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(series, i, 0);
            HV *s, *trace, *marker;
            SV **key, **pts;
            SV *xs = NULL, *ys = NULL;
            STRLEN kl = 0;
            const char *kp = "";
            int known = 0;

            if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
            s = (HV *)SvRV(*e);
            key = hv_fetchs(s, "key", 0);
            if (key && SvOK(*key)) kp = SvPV(*key, kl);
            for (band = 0; band < 6; band++) {
                size_t wl = strlen(PO_PLOT_BANDS[band]);
                if (kl == wl && memcmp(kp, PO_PLOT_BANDS[band], wl) == 0)
                    { known = 1; break; }
            }
            if (known) continue;

            pts = hv_fetchs(s, "points", 0);
            POPL_GAPS(pts ? *pts : NULL, xs, ys);

            trace = newHV();
            marker = newHV();
            hv_stores(marker, "color", newSVpv(po_plot_role(role++), 0));
            hv_stores(trace, "type", newSVpvs("bar"));
            hv_stores(trace, "name", kl ? newSVpvn(kp, kl)
                                        : newSVpvs("unlabelled"));
            hv_stores(trace, "x", xs);
            hv_stores(trace, "y", ys);
            hv_stores(trace, "marker", newRV_noinc((SV *)marker));
            av_push(data, newRV_noinc((SV *)trace));
        }
#undef POPL_GAPS

        {
            HV *layout = newHV(), *yaxis = newHV(), *title = newHV();
            hv_stores(title, "text", (unit && SvOK(unit)) ? newSVsv(unit)
                                                          : newSVpvs("lines"));
            hv_stores(yaxis, "title", newRV_noinc((SV *)title));
            hv_stores(yaxis, "rangemode", newSVpvs("tozero"));
            hv_stores(layout, "barmode", newSVpvs("stack"));
            hv_stores(layout, "bargap", newSVnv(0.05));
            hv_stores(layout, "yaxis", newRV_noinc((SV *)yaxis));
            hv_stores(layout, "showlegend", newRV_noinc(newSViv(1)));

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpvs("data")));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)data)));
            XPUSHs(sv_2mortal(newSVpvs("layout")));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)layout)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::_fig", G_SCALAR);
            SPAGAIN;
            RETVAL = got ? SvREFCNT_inc(POPs) : newRV_noinc((SV *)newHV());
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
        }
    }
    OUTPUT:
        RETVAL

# WHERE THE SLOW ONES CLUSTER, which a table of the fifty slowest cannot show.
SV *
popl_latency_scatter(SV *traces, ...)
    CODE:
    {
        AV *data = newAV();
        AV *tr = NULL;
        SSize_t i, n;
        int pass, got;

        if (SvROK(traces) && SvTYPE(SvRV(traces)) == SVt_PVAV)
            tr = (AV *)SvRV(traces);
        n = tr ? av_len(tr) + 1 : 0;

        /* Two passes, ok then error, so the failing points are drawn on top
         * of the healthy ones rather than under them. */
        for (pass = 0; pass < 2; pass++) {
            AV *xs = newAV(), *ys = newAV(), *cd = newAV();
            HV *trace, *marker;
            int any = 0;

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(tr, i, 0);
                HV *t;
                SV **x, **d, **id, **er;
                int bad;

                if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
                t = (HV *)SvRV(*e);
                er = hv_fetchs(t, "errors", 0);
                bad = (er && SvTRUE(*er)) ? 1 : 0;
                if (bad != pass) continue;

                x = hv_fetchs(t, "t", 0);
                {
                    STRLEN xl = 0;
                    const char *xp = (x && SvOK(*x)) ? SvPV(*x, xl) : "";
                    av_push(xs, po_u64_to_sv(po_plot_ms(xp, (size_t)xl)));
                }
                /* MILLISECONDS, because a latency axis labelled in
                 * nanoseconds is a column of digits nobody can compare at a
                 * glance. Three digits are dropped as characters and the rest
                 * divided, so the value survives a nanosecond duration that a
                 * double could not carry whole. */
                d = hv_fetchs(t, "duration", 0);
                {
                    STRLEN dl = 0;
                    const char *dp = (d && SvOK(*d)) ? SvPV(*d, dl) : "";
                    po_u64 us = 0;
                    size_t k;
                    if (dl > 3) for (k = 0; k + 3 < dl; k++) {
                        if (dp[k] < '0' || dp[k] > '9') { us = 0; break; }
                        us = us * 10 + (po_u64)(dp[k] - '0');
                    }
                    av_push(ys, newSVnv((NV)((double)us / 1000.0)));
                }
                id = hv_fetchs(t, "id", 0);
                av_push(cd, id ? newSVsv(*id) : newSVpvs(""));
                any = 1;
            }

            if (!any) {
                SvREFCNT_dec((SV *)xs); SvREFCNT_dec((SV *)ys);
                SvREFCNT_dec((SV *)cd);
                continue;
            }

            trace = newHV();
            marker = newHV();
            hv_stores(marker, "color", newSVpv(pass ? "sev:error"
                                                    : po_plot_role(0), 0));
            hv_stores(marker, "size", newSViv(6));
            hv_stores(marker, "opacity", newSVnv(0.75));
            hv_stores(trace, "type", newSVpvs("scattergl"));
            hv_stores(trace, "mode", newSVpvs("markers"));
            hv_stores(trace, "name", pass ? newSVpvs("error") : newSVpvs("ok"));
            hv_stores(trace, "x", newRV_noinc((SV *)xs));
            hv_stores(trace, "y", newRV_noinc((SV *)ys));
            hv_stores(trace, "customdata", newRV_noinc((SV *)cd));
            hv_stores(trace, "marker", newRV_noinc((SV *)marker));
            /* The trace id in the hover, which is what plot.js turns into the
             * click: a spike and the trace that caused it are meant to be one
             * gesture apart. */
            hv_stores(trace, "hovertemplate",
                      newSVpvs("%{y:.1f} ms<extra>%{customdata}</extra>"));
            av_push(data, newRV_noinc((SV *)trace));
        }

        {
            HV *layout = newHV(), *yaxis = newHV(), *title = newHV();
            hv_stores(title, "text", newSVpvs("ms"));
            hv_stores(yaxis, "title", newRV_noinc((SV *)title));
            hv_stores(yaxis, "rangemode", newSVpvs("tozero"));
            hv_stores(layout, "yaxis", newRV_noinc((SV *)yaxis));
            hv_stores(layout, "showlegend",
                      newRV_noinc(newSViv(av_len(data) > 0 ? 1 : 0)));
            hv_stores(layout, "hovermode", newSVpvs("closest"));

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpvs("data")));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)data)));
            XPUSHs(sv_2mortal(newSVpvs("layout")));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)layout)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::_fig", G_SCALAR);
            SPAGAIN;
            RETVAL = got ? SvREFCNT_inc(POPs) : newRV_noinc((SV *)newHV());
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
        }
    }
    OUTPUT:
        RETVAL

# HOW MUCH, beside what-calls-what.
#
# Edge width carries volume on the map, which works for two edges and not for
# eight: a four-pixel stroke against a six-pixel one does not read as three to
# two. A flow diagram makes the volume the geometry rather than a hint at it.
SV *
popl_service_flow(SV *edges, ...)
    CODE:
    {
        AV *e = NULL;
        SSize_t i, n;
        AV *label = newAV(), *src = newAV(), *dst = newAV();
        AV *val = newAV(), *col = newAV(), *lab = newAV();
        HV *idx = newHV();
        IV a;
        IV height = 320;
        int got;

        for (a = 1; a + 1 < items; a += 2)
            if (strEQ(SvPV_nolen(ST(a)), "height") && SvTRUE(ST(a + 1)))
                height = SvIV(ST(a + 1));

        if (SvROK(edges) && SvTYPE(SvRV(edges)) == SVt_PVAV)
            e = (AV *)SvRV(edges);
        n = e ? av_len(e) + 1 : 0;

        /* Sankey addresses nodes by INDEX, so the labels are collected first
         * and the links refer to positions in that list. */
#define POPL_NODE(sv, out) do {                                               \
            const char *np_ = "internet";                                     \
            STRLEN nl_ = 8;                                                   \
            SV **slot_;                                                       \
            if ((sv) && SvOK(*(sv))) {                                        \
                STRLEN l_; const char *p_ = SvPV(*(sv), l_);                  \
                if (!(l_ == 1 && *p_ == '*')) { np_ = p_; nl_ = l_; }         \
            }                                                                 \
            slot_ = hv_fetch(idx, np_, (I32)nl_, 0);                          \
            if (slot_) (out) = SvIV(*slot_);                                  \
            else {                                                            \
                (out) = av_len(label) + 1;                                    \
                av_push(label, newSVpvn(np_, nl_));                           \
                (void)hv_store(idx, np_, (I32)nl_, newSViv(out), 0);          \
            }                                                                 \
        } while (0)

        for (i = 0; i < n; i++) {
            SV **el = av_fetch(e, i, 0);
            HV *h;
            SV **back, **cnt, **er;
            po_u64 count = 0;
            IV s_i, d_i;

            if (!el || !SvROK(*el) || SvTYPE(SvRV(*el)) != SVt_PVHV) continue;
            h = (HV *)SvRV(*el);

            /* A BACK EDGE IS DROPPED, NOT DRAWN. A Sankey lays nodes out left
             * to right by following the flow; an edge that returns has no
             * position in that order and the layout either loops forever or
             * draws nonsense. The map beside this one shows them dashed,
             * which is where a cycle belongs. */
            back = hv_fetchs(h, "back", 0);
            if (back && SvTRUE(*back)) continue;

            cnt = hv_fetchs(h, "count", 0);
            if (cnt) (void)po_sv_to_u64(aTHX_ *cnt, &count);
            if (!count) continue;

            POPL_NODE(hv_fetchs(h, "caller", 0), s_i);
            POPL_NODE(hv_fetchs(h, "callee", 0), d_i);
            av_push(src, newSViv(s_i));
            av_push(dst, newSViv(d_i));
            av_push(val, po_u64_to_sv(count));

            /* A failing edge is coloured by its FAILURE, because the question
             * asked of this diagram during an incident is which flow is red. */
            er = hv_fetchs(h, "errors", 0);
            av_push(col, (er && SvTRUE(*er)) ? newSVpvs("sev:error")
                                             : newSVpvs("series:0"));
            {
                SV *l = po_u64_to_sv(count);
                sv_catpvs(l, " calls");
                if (er && SvTRUE(*er)) {
                    sv_catpvs(l, ", ");
                    sv_catsv(l, *er);
                    sv_catpvs(l, " in error");
                }
                av_push(lab, l);
            }
        }
#undef POPL_NODE

        if (av_len(src) < 0) {
            SvREFCNT_dec((SV *)label); SvREFCNT_dec((SV *)src);
            SvREFCNT_dec((SV *)dst);   SvREFCNT_dec((SV *)val);
            SvREFCNT_dec((SV *)col);   SvREFCNT_dec((SV *)lab);
            SvREFCNT_dec((SV *)idx);
            XSRETURN_UNDEF;
        }

        {
            HV *trace = newHV(), *node = newHV(), *link = newHV(), *line = newHV();
            HV *layout = newHV();
            AV *data = newAV();

            hv_stores(line, "color", newSVpvs("line"));
            hv_stores(line, "width", newSViv(1));
            hv_stores(node, "label", newRV_noinc((SV *)label));
            hv_stores(node, "pad", newSViv(14));
            hv_stores(node, "thickness", newSViv(14));
            hv_stores(node, "color", newSVpvs("series:2"));
            hv_stores(node, "line", newRV_noinc((SV *)line));

            hv_stores(link, "source", newRV_noinc((SV *)src));
            hv_stores(link, "target", newRV_noinc((SV *)dst));
            hv_stores(link, "value", newRV_noinc((SV *)val));
            hv_stores(link, "color", newRV_noinc((SV *)col));
            hv_stores(link, "label", newRV_noinc((SV *)lab));

            hv_stores(trace, "type", newSVpvs("sankey"));
            hv_stores(trace, "orientation", newSVpvs("h"));
            hv_stores(trace, "node", newRV_noinc((SV *)node));
            hv_stores(trace, "link", newRV_noinc((SV *)link));
            av_push(data, newRV_noinc((SV *)trace));

            /* A Sankey has NO AXES, and the shared date x-axis would draw
             * one. _fig drops an undef rather than serialising a null. */
            hv_stores(layout, "xaxis", newSV(0));
            hv_stores(layout, "yaxis", newSV(0));
            hv_stores(layout, "hovermode", newSVpvs("closest"));
            hv_stores(layout, "showlegend", newRV_noinc(newSViv(0)));
            hv_stores(layout, "height", newSViv(height));

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpvs("data")));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)data)));
            XPUSHs(sv_2mortal(newSVpvs("layout")));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)layout)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::_fig", G_SCALAR);
            SPAGAIN;
            RETVAL = got ? SvREFCNT_inc(POPs) : newRV_noinc((SV *)newHV());
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
        }
        SvREFCNT_dec((SV *)idx);
    }
    OUTPUT:
        RETVAL

# Transitions into bands.
#
# ONE BAND RUNS TO THE NEXT TRANSITION of the same series, not to a fixed
# width. The interval is the whole information content: two bands of equal
# width would say a four-minute outage and a five-hour one were the same
# event.
SV *
popl_alert_timeline(SV *events, ...)
    CODE:
    {
        AV *ev = NULL;
        SV *to = NULL;
        IV a;
        SSize_t i, n, nseries = 0;
        HV *by = newHV();
        HV *seen = newHV();
        AV *data = newAV();
        AV *names = newAV();
        SV *end = NULL;
        int got;

        for (a = 1; a + 1 < items; a += 2)
            if (strEQ(SvPV_nolen(ST(a)), "to")) to = ST(a + 1);

        /* The seam's whole answer is accepted as well as its events list, so
         * a caller in C hands over one scalar rather than digging a key out
         * first. */
        if (SvROK(events) && SvTYPE(SvRV(events)) == SVt_PVHV) {
            HV *h = (HV *)SvRV(events);
            SV **t = hv_fetchs(h, "to", 0);
            SV **e = hv_fetchs(h, "events", 0);
            if (t && SvOK(*t)) to = *t;
            if (e && SvROK(*e) && SvTYPE(SvRV(*e)) == SVt_PVAV)
                ev = (AV *)SvRV(*e);
        }
        else if (SvROK(events) && SvTYPE(SvRV(events)) == SVt_PVAV)
            ev = (AV *)SvRV(events);

        n = ev ? av_len(ev) + 1 : 0;
        if (!n) goto nothing;

        for (i = 0; i < n; i++) {
            SV **e = av_fetch(ev, i, 0);
            HV *h;
            SV **s, **at;
            STRLEN sl;
            const char *sp;
            SV **slot;

            if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
            h = (HV *)SvRV(*e);
            s  = hv_fetchs(h, "series", 0);
            at = hv_fetchs(h, "at", 0);
            if (!s || !SvOK(*s) || !at || !SvOK(*at)) continue;
            sp = SvPV(*s, sl);
            slot = hv_fetch(by, sp, (I32)sl, 1);
            if (!slot) continue;
            if (!SvROK(*slot)) {
                sv_setsv(*slot, sv_2mortal(newRV_noinc((SV *)newAV())));
                av_push(names, newSVpvn(sp, sl));
                nseries++;
            }
            av_push((AV *)SvRV(*slot), SvREFCNT_inc(*e));
        }
        if (!nseries) goto nothing;

        /* THE RIGHT EDGE IS NOW, and that is not a fallback - it is what the
         * last band means. A state that has not been left yet is still in
         * force, so its band runs to the present moment; ending it at the
         * last transition would draw an ongoing incident as an instant that
         * finished when it started. */
        if (to && SvOK(to)) end = newSVsv(to);
        else {
            ENTER; SAVETMPS; PUSHMARK(SP);
            PUTBACK;
            got = call_pv("Punk::Observe::now_ns", G_SCALAR);
            SPAGAIN;
            end = got ? newSVsv(POPs) : newSVpvs("0");
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
        }

        /* The series in name order, so two renders of the same history put
         * the rows in the same places. */
        sortsv(AvARRAY(names), (SSize_t)(av_len(names) + 1), Perl_sv_cmp);

        for (i = 0; i <= av_len(names); i++) {
            SV **nm = av_fetch(names, i, 0);
            STRLEN sl;
            const char *sp;
            SV **slot;
            AV *list;
            SSize_t j, cnt;

            if (!nm) continue;
            sp = SvPV(*nm, sl);
            slot = hv_fetch(by, sp, (I32)sl, 0);
            if (!slot || !SvROK(*slot)) continue;
            list = (AV *)SvRV(*slot);
            cnt = av_len(list) + 1;

            /* By instant. Compared as decimal STRINGS by width then value:
             * a nanosecond instant past 2^53 does not survive being made a
             * number, and two transitions a microsecond apart would then sort
             * as equal. */
            {
                SV **arr = AvARRAY(list);
                SSize_t x;
                for (x = 1; x < cnt; x++) {
                    SV *k = arr[x];
                    SV **ka = hv_fetchs((HV *)SvRV(k), "at", 0);
                    STRLEN kl = 0;
                    const char *kp = (ka && SvOK(*ka)) ? SvPV(*ka, kl) : "";
                    SSize_t y;
                    for (y = x - 1; y >= 0; y--) {
                        SV **ja = hv_fetchs((HV *)SvRV(arr[y]), "at", 0);
                        STRLEN jl = 0;
                        const char *jp = (ja && SvOK(*ja)) ? SvPV(*ja, jl) : "";
                        if (po_ns_cmp_str(jp, (size_t)jl, kp, (size_t)kl, NULL) <= 0)
                            break;
                        arr[y + 1] = arr[y];
                    }
                    arr[y + 1] = k;
                }
            }

            for (j = 0; j < cnt; j++) {
                SV **e = av_fetch(list, j, 0);
                HV *h, *trace, *marker;
                SV **st, **at;
                const char *state = "ok";
                STRLEN stl = 2;
                po_u64 start_ms, stop_ms;
                double width;
                AV *base = newAV(), *xs = newAV(), *ys = newAV();
                SV *hov;
                SV **fs;

                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                st = hv_fetchs(h, "to", 0);
                if (st && SvOK(*st) && SvCUR(*st)) state = SvPV(*st, stl);
                at = hv_fetchs(h, "at", 0);

                {
                    STRLEN al = 0;
                    const char *ap = (at && SvOK(*at)) ? SvPV(*at, al) : "";
                    start_ms = po_plot_ms(ap, (size_t)al);
                }
                {
                    SV *stop = NULL;
                    STRLEN pl = 0;
                    const char *pp;
                    if (j + 1 < cnt) {
                        SV **nx = av_fetch(list, j + 1, 0);
                        SV **na = (nx && SvROK(*nx))
                                    ? hv_fetchs((HV *)SvRV(*nx), "at", 0) : NULL;
                        stop = (na && SvOK(*na)) ? *na : NULL;
                    }
                    else stop = end;
                    if (!stop || !SvOK(stop)) {
                        SvREFCNT_dec((SV *)base); SvREFCNT_dec((SV *)xs);
                        SvREFCNT_dec((SV *)ys);
                        continue;
                    }
                    pp = SvPV(stop, pl);
                    stop_ms = po_plot_ms(pp, (size_t)pl);
                }

                width = (double)stop_ms - (double)start_ms;
                /* A transition and the next in the same millisecond would be
                 * a bar of zero width, which draws as nothing at all - so it
                 * gets the minimum that is still visible. */
                if (width < 1) width = 1;

                av_push(base, po_u64_to_sv(start_ms));
                av_push(xs, povw_num(aTHX_ sv_2mortal(newSVnv((NV)width))));
                av_push(ys, newSVpvn(sp, sl));

                trace = newHV();
                marker = newHV();
                /* `up` and `down` are HEALTH's words, and they are here so
                 * that page can use its own vocabulary rather than borrow an
                 * alert's: a legend reading "firing" over a service-uptime
                 * band would be describing a rule that does not exist. Same
                 * two colours, because the reading is the same one. */
                hv_stores(marker, "color",
                          newSVpv(strEQ(state, "ok")      ? "ok"
                                : strEQ(state, "up")      ? "ok"
                                : strEQ(state, "pending") ? "warn"
                                : strEQ(state, "firing")  ? "err"
                                : strEQ(state, "down")    ? "err"
                                : strEQ(state, "stale")   ? "muted"
                                : strEQ(state, "error")   ? "warn"
                                :                           "muted", 0));
                hv_stores(trace, "type", newSVpvs("bar"));
                hv_stores(trace, "orientation", newSVpvs("h"));
                hv_stores(trace, "base", newRV_noinc((SV *)base));
                hv_stores(trace, "x", newRV_noinc((SV *)xs));
                hv_stores(trace, "y", newRV_noinc((SV *)ys));
                hv_stores(trace, "name", newSVpvn(state, stl));
                /* ONE LEGEND ENTRY PER STATE rather than per band, or a rule
                 * that flapped twelve times gets twelve identical rows. */
                fs = hv_fetch(seen, state, (I32)stl, 1);
                hv_stores(trace, "showlegend",
                          newRV_noinc(newSViv((fs && SvTRUE(*fs)) ? 0 : 1)));
                if (fs) sv_setiv(*fs, 1);
                hv_stores(trace, "legendgroup", newSVpvn(state, stl));
                hv_stores(trace, "marker", newRV_noinc((SV *)marker));
                hov = newSVpvn(sp, sl);
                sv_catpvs(hov, ": ");
                sv_catpvn(hov, state, stl);
                sv_catpvs(hov, "<extra></extra>");
                hv_stores(trace, "hovertemplate", hov);
                av_push(data, newRV_noinc((SV *)trace));
            }
        }

        if (av_len(data) < 0) goto nothing;

        {
            HV *layout = newHV(), *xaxis = newHV(), *yaxis = newHV();
            hv_stores(xaxis, "type", newSVpvs("date"));
            hv_stores(yaxis, "automargin", newRV_noinc(newSViv(1)));
            hv_stores(yaxis, "type", newSVpvs("category"));
            /* Overlay, not stack: the bands of one series are consecutive in
             * time, and stacking would add their widths together. */
            hv_stores(layout, "barmode", newSVpvs("overlay"));
            hv_stores(layout, "xaxis", newRV_noinc((SV *)xaxis));
            hv_stores(layout, "yaxis", newRV_noinc((SV *)yaxis));
            hv_stores(layout, "height", newSViv(120 + 22 * (IV)nseries));
            hv_stores(layout, "showlegend", newRV_noinc(newSViv(1)));

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpvs("data")));
            XPUSHs(sv_2mortal(newRV_inc((SV *)data)));
            XPUSHs(sv_2mortal(newSVpvs("layout")));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)layout)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::_fig", G_SCALAR);
            SPAGAIN;
            RETVAL = got ? SvREFCNT_inc(POPs) : newRV_noinc((SV *)newHV());
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
        }
        goto cleanup;

        /* NO TRANSITIONS MEANS NO CHART, not an empty one. An empty panel
         * reads as "nothing has happened", which is a different and unearned
         * claim. */
    nothing:
        RETVAL = &PL_sv_undef;
        SvREFCNT_inc(RETVAL);
    cleanup:
        if (end) SvREFCNT_dec(end);
        SvREFCNT_dec((SV *)by);
        SvREFCNT_dec((SV *)seen);
        SvREFCNT_dec((SV *)names);
        SvREFCNT_dec((SV *)data);
    }
    OUTPUT:
        RETVAL

SV *
popl_timeline_figure(SV *events)
    CODE:
    {
        SV *fig = NULL, *enc = NULL;
        int got;

        ENTER; SAVETMPS; PUSHMARK(SP);
        XPUSHs(events);
        PUTBACK;
        got = call_pv("Punk::Observe::Plot::alert_timeline", G_SCALAR);
        SPAGAIN;
        fig = got ? SvREFCNT_inc(POPs) : NULL;
        PUTBACK;
        FREETMPS; LEAVE;
        SPAGAIN;

        ENTER; SAVETMPS; PUSHMARK(SP);
        XPUSHs(sv_2mortal(fig ? newSVsv(fig) : newSV(0)));
        PUTBACK;
        got = call_pv("Punk::Observe::Plot::encode", G_SCALAR);
        SPAGAIN;
        enc = got ? SvREFCNT_inc(POPs) : newSVpvs("");
        PUTBACK;
        FREETMPS; LEAVE;
        SPAGAIN;
        if (fig) SvREFCNT_dec(fig);
        RETVAL = enc;
    }
    OUTPUT:
        RETVAL

# A store query, drawn.
#
# The width is chosen HERE rather than passed in, so that every caller of this
# gets the same ladder and two panels over the same window cannot disagree
# about how wide a bar is.
SV *
popl_volume_figure(SV *store, SV *q, SV *from, SV *to)
    CODE:
    {
        SV *f = NULL, *t = NULL, *res = NULL, *fig = NULL;
        STRLEN ql = 0;
        const char *qp = SvOK(q) ? SvPV(q, ql) : NULL;
        int got;

        RETVAL = &PL_sv_undef;
        SvREFCNT_inc(RETVAL);
        if (!SvOK(store) || !SvROK(store) || !qp || !ql) goto done;

        f = SvOK(from) ? newSVsv(from) : NULL;
        t = SvOK(to)   ? newSVsv(to)   : NULL;

        /* AN UNBOUNDED WINDOW STILL NEEDS A WIDTH.
         *
         * `all` is a real range - it is the escape hatch for data older than
         * the default - and it arrives with no endpoints at all, so there is
         * nothing to compute a width from. The span is probed with one coarse
         * bucketed pass, which is an aggregate and reads no rows out, and the
         * real width is computed from what came back.
         *
         * Two queries only on the one page that has no window. A fixed
         * default would be a day-wide bar over a thirty-second store, or a
         * refusal over a year-old one. */
        if (!f || !t) {
            SV *probe = NULL;
            SV *lo = NULL, *hi = NULL;

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(store);
            { SV *qq = newSVpvn(qp, ql);
              sv_catpvs(qq, " | bucket(1h) count");
              XPUSHs(sv_2mortal(qq)); }
            XPUSHs(sv_2mortal(newSVpvs("from")));
            XPUSHs(sv_2mortal(f ? newSVsv(f) : newSV(0)));
            XPUSHs(sv_2mortal(newSVpvs("to")));
            XPUSHs(sv_2mortal(t ? newSVsv(t) : newSV(0)));
            POVW_NO_CEILING();
            PUTBACK;
            got = call_method(povw_read_method(aTHX_ store), G_SCALAR | G_EVAL);
            SPAGAIN;
            probe = got ? SvREFCNT_inc(POPs) : NULL;
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;

            if (probe && !SvTRUE(ERRSV) && SvROK(probe)
                && SvTYPE(SvRV(probe)) == SVt_PVHV) {
                HV *ph = (HV *)SvRV(probe);
                SV **ok = hv_fetchs(ph, "ok", 0);
                SV **sh = hv_fetchs(ph, "shape", 0);
                SV **se = hv_fetchs(ph, "series", 0);
                if (ok && SvTRUE(*ok) && sh && SvOK(*sh)
                    && strEQ(SvPV_nolen(*sh), "buckets")
                    && se && SvROK(*se) && SvTYPE(SvRV(*se)) == SVt_PVAV) {
                    AV *sa = (AV *)SvRV(*se);
                    SSize_t i, n = av_len(sa) + 1;
                    for (i = 0; i < n; i++) {
                        SV **e = av_fetch(sa, i, 0);
                        SV **pts = (e && SvROK(*e))
                                     ? hv_fetchs((HV *)SvRV(*e), "points", 0) : NULL;
                        AV *pa;
                        SSize_t j, m;
                        if (!pts || !SvROK(*pts)) continue;
                        pa = (AV *)SvRV(*pts);
                        m = av_len(pa) + 1;
                        for (j = 0; j < m; j++) {
                            SV **p = av_fetch(pa, j, 0);
                            SV **at = (p && SvROK(*p))
                                        ? av_fetch((AV *)SvRV(*p), 0, 0) : NULL;
                            STRLEN al = 0, cl = 0;
                            const char *ap, *cp;
                            if (!at || !SvOK(*at)) continue;
                            ap = SvPV(*at, al);
                            if (!lo) lo = newSVsv(*at);
                            else {
                                cp = SvPV(lo, cl);
                                if (po_ns_cmp_str(ap, (size_t)al, cp,
                                                  (size_t)cl, NULL) < 0)
                                    sv_setsv(lo, *at);
                            }
                            if (!hi) hi = newSVsv(*at);
                            else {
                                cp = SvPV(hi, cl);
                                if (po_ns_cmp_str(ap, (size_t)al, cp,
                                                  (size_t)cl, NULL) > 0)
                                    sv_setsv(hi, *at);
                            }
                        }
                    }
                }
            }
            if (probe) SvREFCNT_dec(probe);
            if (!lo || !hi) {
                if (lo) SvREFCNT_dec(lo);
                if (hi) SvREFCNT_dec(hi);
                goto done;
            }
            if (f) SvREFCNT_dec(f);
            if (t) SvREFCNT_dec(t);
            f = lo;
            {
                po_u64 h = 0;
                (void)po_sv_to_u64(aTHX_ hi, &h);
                t = po_u64_to_sv(po_ns_add(h, 3600000000000ULL));
                SvREFCNT_dec(hi);
            }
        }

        {
            const char *width;
            STRLEN fl, tl;
            const char *fp = SvPV(f, fl);
            const char *tp = SvPV(t, tl);
            SV *qq;

            width = po_plot_bucket_for(fp, (size_t)fl, tp, (size_t)tl);
            qq = newSVpvn(qp, ql);
            sv_catpvs(qq, " | bucket(");
            sv_catpv(qq, width);
            sv_catpvs(qq, ") count by severity");

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(store);
            XPUSHs(sv_2mortal(qq));
            XPUSHs(sv_2mortal(newSVpvs("from"))); XPUSHs(sv_2mortal(newSVsv(f)));
            XPUSHs(sv_2mortal(newSVpvs("to")));   XPUSHs(sv_2mortal(newSVsv(t)));
            POVW_NO_CEILING();
            PUTBACK;
            got = call_method(povw_read_method(aTHX_ store), G_SCALAR | G_EVAL);
            SPAGAIN;
            res = got ? SvREFCNT_inc(POPs) : NULL;
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
        }

        if (!res || SvTRUE(ERRSV) || !SvROK(res)
            || SvTYPE(SvRV(res)) != SVt_PVHV) goto done;
        {
            HV *rh = (HV *)SvRV(res);
            SV **ok = hv_fetchs(rh, "ok", 0);
            SV **sh = hv_fetchs(rh, "shape", 0);
            SV **se = hv_fetchs(rh, "series", 0);
            AV *sa;
            SSize_t i, n;

            if (!ok || !SvTRUE(*ok)) goto done;
            if (!sh || !SvOK(*sh) || !strEQ(SvPV_nolen(*sh), "buckets")) goto done;
            if (!se || !SvROK(*se) || SvTYPE(SvRV(*se)) != SVt_PVAV) goto done;
            sa = (AV *)SvRV(*se);
            n = av_len(sa) + 1;
            if (!n) goto done;

            /* The severity arrives as the NUMBER that is stored, because that
             * is what a query compares. The ramp is keyed by name, so it is
             * named here. */
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(sa, i, 0);
                HV *s;
                SV **key;
                char buf[64];
                size_t bn;
                STRLEN kl = 0;
                const char *kp;
                if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
                s = (HV *)SvRV(*e);
                key = hv_fetchs(s, "key", 0);
                kp = (key && SvOK(*key)) ? SvPV(*key, kl) : NULL;
                bn = po_plot_severity_name(kp, (size_t)kl, buf);
                (void)hv_stores(s, "key", newSVpvn(buf, bn));
            }
        }

        ENTER; SAVETMPS; PUSHMARK(SP);
        XPUSHs(sv_2mortal(newSVsv(res)));
        XPUSHs(sv_2mortal(newSVpvs("unit")));
        XPUSHs(sv_2mortal(newSVpvs("lines")));
        PUTBACK;
        got = call_pv("Punk::Observe::Plot::severity_bars", G_SCALAR);
        SPAGAIN;
        fig = got ? SvREFCNT_inc(POPs) : NULL;
        PUTBACK;
        FREETMPS; LEAVE;
        SPAGAIN;

        if (fig) {
            SvREFCNT_dec(RETVAL);
            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVsv(fig)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::encode", G_SCALAR);
            SPAGAIN;
            RETVAL = got ? SvREFCNT_inc(POPs) : newSVpvs("");
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
            SvREFCNT_dec(fig);
        }

    done:
        if (f) SvREFCNT_dec(f);
        if (t) SvREFCNT_dec(t);
        if (res) SvREFCNT_dec(res);
    }
    OUTPUT:
        RETVAL

# A query result drawn as whatever shape it turned out to be.
#
# `explore` is one box over every signal, so it cannot know in advance what
# shape an answer will take. Dispatching on the shape in ONE place means the
# next shape is added in one place.
SV *
popl_result_figure(SV *res)
    CODE:
    {
        HV *r = NULL;
        SV **sh;
        int got;

        RETVAL = newSVpvs("");
        if (!SvROK(res) || SvTYPE(SvRV(res)) != SVt_PVHV) XSRETURN(1);
        r = (HV *)SvRV(res);
        sh = hv_fetchs(r, "shape", 0);
        if (sh && SvOK(*sh) && strEQ(SvPV_nolen(*sh), "buckets")) {
            SV *fig = NULL;
            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(res);
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::timeseries", G_SCALAR);
            SPAGAIN;
            fig = got ? SvREFCNT_inc(POPs) : NULL;
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;

            if (fig) {
                SvREFCNT_dec(RETVAL);
                ENTER; SAVETMPS; PUSHMARK(SP);
                XPUSHs(sv_2mortal(newSVsv(fig)));
                PUTBACK;
                got = call_pv("Punk::Observe::Plot::encode", G_SCALAR);
                SPAGAIN;
                RETVAL = got ? SvREFCNT_inc(POPs) : newSVpvs("");
                PUTBACK;
                FREETMPS; LEAVE;
                SPAGAIN;
                SvREFCNT_dec(fig);
            }
        }
    }
    OUTPUT:
        RETVAL

# What is arriving, which no total can say.
#
# LOGS AND SPANS, AND NOT METRICS. `metric` takes a name, so there is no query
# for "every metric point" and the overview has no basis on which to pick one
# name to stand for the rest. Counting them by choosing a name would be a
# chart whose height depended on which metric happened to be chosen, which is
# worse than a chart that says what it covers.
SV *
popl_ingest_figure(SV *store, SV *from, SV *to)
    CODE:
    {
        AV *data = newAV();
        const char *width;
        STRLEN fl = 0, tl = 0;
        const char *fp, *tp;
        int sig, got, i = 0;
        static const char *const SRC[2][2] = {
            { "log",   "logs"  },
            { "spans", "spans" }
        };

        RETVAL = &PL_sv_undef;
        SvREFCNT_inc(RETVAL);
        if (!SvOK(store) || !SvROK(store)) goto done;

        fp = SvOK(from) ? SvPV(from, fl) : "";
        tp = SvOK(to)   ? SvPV(to,   tl) : "";
        width = po_plot_bucket_for(fp, (size_t)fl, tp, (size_t)tl);

        for (sig = 0; sig < 2; sig++) {
            SV *res = NULL;
            SV *xs = NULL, *ys = NULL;
            HV *trace, *line;
            HV *rh;
            SV **ok, **sh, **se, **bn;
            AV *sa;
            SV **first, **pts;

            {
                SV *q = newSVpv(SRC[sig][0], 0);
                sv_catpvs(q, " | bucket(");
                sv_catpv(q, width);
                sv_catpvs(q, ") count");
                ENTER; SAVETMPS; PUSHMARK(SP);
                XPUSHs(store);
                XPUSHs(sv_2mortal(q));
                XPUSHs(sv_2mortal(newSVpvs("from"))); XPUSHs(sv_2mortal(newSVsv(from)));
                XPUSHs(sv_2mortal(newSVpvs("to")));   XPUSHs(sv_2mortal(newSVsv(to)));
                POVW_NO_CEILING();
                PUTBACK;
                got = call_method(povw_read_method(aTHX_ store),
                                  G_SCALAR | G_EVAL);
                SPAGAIN;
                res = got ? SvREFCNT_inc(POPs) : NULL;
                PUTBACK;
                FREETMPS; LEAVE;
                SPAGAIN;
            }
            if (!res || SvTRUE(ERRSV) || !SvROK(res)
                || SvTYPE(SvRV(res)) != SVt_PVHV) { if (res) SvREFCNT_dec(res); continue; }
            rh = (HV *)SvRV(res);
            ok = hv_fetchs(rh, "ok", 0);
            sh = hv_fetchs(rh, "shape", 0);
            se = hv_fetchs(rh, "series", 0);
            bn = hv_fetchs(rh, "bucket_ns", 0);
            if (!ok || !SvTRUE(*ok)
                || !sh || !SvOK(*sh) || !strEQ(SvPV_nolen(*sh), "buckets")
                || !se || !SvROK(*se) || SvTYPE(SvRV(*se)) != SVt_PVAV) {
                SvREFCNT_dec(res); continue;
            }
            /* A SIGNAL THAT RECEIVED NOTHING IS DRAWN AS ZERO, NOT DROPPED.
             *
             * The answer succeeded and says none arrived, which is a fact
             * about the window and belongs on the chart. Omitting the trace
             * takes its name out of the legend too, so a reader sees a chart
             * that has only ever had one line on it - and "no spans arrived
             * in this window" becomes indistinguishable from "the span count
             * was lost", which is how it gets reported.
             *
             * It is the same reasoning the zero-fill below already applies
             * to a single empty BUCKET, carried to the case where every
             * bucket is empty. A failed query still skips: that one has not
             * established anything about the window. */
            sa = (AV *)SvRV(*se);
            first = av_fetch(sa, 0, 0);
            pts = (first && SvROK(*first) && SvTYPE(SvRV(*first)) == SVt_PVHV)
                ? hv_fetchs((HV *)SvRV(*first), "points", 0) : NULL;
            if (!pts || !SvROK(*pts) || SvTYPE(SvRV(*pts)) != SVt_PVAV)
                pts = NULL;

            /* Zero-filled and bounded to the WINDOW: these are counts, a
             * bucket with nothing in it did genuinely receive nothing, and a
             * window whose traffic all lands in one bucket must still draw
             * the window rather than a millisecond around that bucket. */
            if (!pts) {
                /* Flat zero across the window. Two points rather than a
                 * zero-fill: with no bucket width reported there is nothing
                 * to step by, and a line from one edge to the other says
                 * exactly what happened. */
                AV *zx = newAV(), *zy = newAV();
                av_push(zx, po_u64_to_sv(po_plot_ms(fp, (size_t)fl)));
                av_push(zx, po_u64_to_sv(po_plot_ms(tp, (size_t)tl)));
                av_push(zy, newSViv(0));
                av_push(zy, newSViv(0));
                xs = newRV_noinc((SV *)zx);
                ys = newRV_noinc((SV *)zy);
            }
            else {
            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVsv(*pts)));
            XPUSHs(sv_2mortal(bn ? newSVsv(*bn) : newSV(0)));
            XPUSHs(sv_2mortal(newSViv(1)));
            XPUSHs(sv_2mortal(newSVsv(from)));
            XPUSHs(sv_2mortal(newSVsv(to)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::_fill_gaps", G_LIST);
            SPAGAIN;
            if (got >= 2) { ys = SvREFCNT_inc(POPs); xs = SvREFCNT_inc(POPs); }
            else { xs = newRV_noinc((SV *)newAV()); ys = newRV_noinc((SV *)newAV()); }
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
            }
            SvREFCNT_dec(res);

            trace = newHV();
            line = newHV();
            hv_stores(line, "color", newSVpv(po_plot_role(i), 0));
            hv_stores(line, "width", newSViv(1));
            hv_stores(trace, "type", newSVpvs("scatter"));
            hv_stores(trace, "mode", newSVpvs("lines"));
            hv_stores(trace, "name", newSVpv(SRC[sig][1], 0));
            hv_stores(trace, "x", xs);
            hv_stores(trace, "y", ys);
            hv_stores(trace, "stackgroup", newSVpvs("one"));
            hv_stores(trace, "fill", newSVpvs("tonexty"));
            hv_stores(trace, "line", newRV_noinc((SV *)line));
            av_push(data, newRV_noinc((SV *)trace));
            i++;
        }

        if (av_len(data) < 0) goto done;

        {
            HV *layout = newHV(), *yaxis = newHV(), *title = newHV();
            HV *xaxis = newHV(), *margin = newHV();
            AV *range = newAV();
            SV *fig = NULL;

            hv_stores(title, "text", newSVpvs("records"));
            hv_stores(yaxis, "title", newRV_noinc((SV *)title));
            hv_stores(yaxis, "rangemode", newSVpvs("tozero"));
            /* THE AXIS IS THE WINDOW THAT WAS ASKED FOR, not the extent of
             * what came back. Left to plotly, a quiet hour with one busy
             * bucket in it auto-scales to that bucket - and the panel then
             * says "the last hour" above a chart showing a millisecond. */
            av_push(range, po_u64_to_sv(po_plot_ms(fp, (size_t)fl)));
            av_push(range, po_u64_to_sv(po_plot_ms(tp, (size_t)tl)));
            hv_stores(xaxis, "type", newSVpvs("date"));
            hv_stores(xaxis, "range", newRV_noinc((SV *)range));
            hv_stores(margin, "l", newSViv(48));
            hv_stores(margin, "r", newSViv(12));
            hv_stores(margin, "t", newSViv(8));
            hv_stores(margin, "b", newSViv(28));
            hv_stores(layout, "yaxis", newRV_noinc((SV *)yaxis));
            hv_stores(layout, "xaxis", newRV_noinc((SV *)xaxis));
            hv_stores(layout, "height", newSViv(200));
            hv_stores(layout, "margin", newRV_noinc((SV *)margin));
            hv_stores(layout, "showlegend", newRV_noinc(newSViv(1)));

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpvs("data")));
            XPUSHs(sv_2mortal(newRV_inc((SV *)data)));
            XPUSHs(sv_2mortal(newSVpvs("layout")));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)layout)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::_fig", G_SCALAR);
            SPAGAIN;
            fig = got ? SvREFCNT_inc(POPs) : NULL;
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;

            if (fig) {
                SvREFCNT_dec(RETVAL);
                ENTER; SAVETMPS; PUSHMARK(SP);
                XPUSHs(sv_2mortal(newSVsv(fig)));
                PUTBACK;
                got = call_pv("Punk::Observe::Plot::encode", G_SCALAR);
                SPAGAIN;
                RETVAL = got ? SvREFCNT_inc(POPs) : newSVpvs("");
                PUTBACK;
                FREETMPS; LEAVE;
                SPAGAIN;
                SvREFCNT_dec(fig);
            }
        }

    done:
        SvREFCNT_dec((SV *)data);
    }
    OUTPUT:
        RETVAL

# The chart AND the table beneath it, from one answer.
#
# Both come from the same result rather than from two queries, so the table
# cannot disagree with the line above it about what was in the window.
void
popl_bucket_vars(SV *vars, SV *res)
    PPCODE:
    {
        HV *v, *r;
        SV **sh, **se;
        AV *sa, *rows;
        SSize_t i, n, nrows;
        int got, has_series = 0;
        /* A table nobody scrolls is a table nobody reads, and every row is
         * markup the browser has to lay out. */
        const SSize_t MAXROWS = 500;

        if (!SvROK(vars) || SvTYPE(SvRV(vars)) != SVt_PVHV) XSRETURN_EMPTY;
        if (!SvROK(res)  || SvTYPE(SvRV(res))  != SVt_PVHV) XSRETURN_EMPTY;
        v = (HV *)SvRV(vars);
        r = (HV *)SvRV(res);
        sh = hv_fetchs(r, "shape", 0);
        if (!sh || !SvOK(*sh) || !strEQ(SvPV_nolen(*sh), "buckets"))
            XSRETURN_EMPTY;

        {
            SV *fig = NULL, *enc = NULL;
            /* THE PANEL'S OWN CHART KIND. `vars` is the panel, so the viz it
             * was saved as is already here - it was simply never read, which
             * is why a panel saved as a bar drew a line. */
            SV **vz = hv_fetchs(v, "viz", 0);
            /* A `viz` MEANS THIS IS A PANEL, and a panel gets exactly the one
             * answer it asked for. The explorer has no viz and wants both:
             * the chart, and the numbers behind it under the same heading.
             * Suppressing on the explorer removed the table it exists to
             * show. */
            int has_viz = vz && SvOK(*vz) && SvCUR(*vz);
            const char *kind = has_viz ? SvPV_nolen(*vz) : "line";

            /* `stat` IS NOT A CHART, so it does not get a figure.
             *
             * One number, large, is markup - and markup needs no charting
             * library, survives scripting being off, and is the panel most
             * likely to be the one somebody glances at. Building it as a
             * one-point plotly figure would be the library drawing a label.
             *
             * The number is the LAST point of the first series: a stat over a
             * bucketed answer is "what is it now", and averaging the window
             * would answer a question nobody asked. */
            if (strEQ(kind, "stat")) {
                SV **sv2 = hv_fetchs(r, "series", 0);
                SV *val = NULL;
                if (sv2 && SvROK(*sv2) && SvTYPE(SvRV(*sv2)) == SVt_PVAV) {
                    AV *sa2 = (AV *)SvRV(*sv2);
                    SV **e0 = av_fetch(sa2, 0, 0);
                    if (e0 && SvROK(*e0) && SvTYPE(SvRV(*e0)) == SVt_PVHV) {
                        SV **pts = hv_fetchs((HV *)SvRV(*e0), "points", 0);
                        if (pts && SvROK(*pts) && SvTYPE(SvRV(*pts)) == SVt_PVAV) {
                            /* A POINT IS AN ARRAY, not a hash: the executor
                             * emits [ instant, formatted, value ] and the
                             * third element is the number. Reading it as a
                             * hash is how this shipped rendering "-" over
                             * live data while passing a test written against
                             * a shape the store never produces. */
                            AV *pa = (AV *)SvRV(*pts);
                            SSize_t last = av_len(pa);
                            if (last >= 0) {
                                SV **lp = av_fetch(pa, last, 0);
                                if (lp && SvROK(*lp)
                                    && SvTYPE(SvRV(*lp)) == SVt_PVAV) {
                                    AV *pt = (AV *)SvRV(*lp);
                                    SV **y = av_fetch(pt, 2, 0);
                                    if (y && SvOK(*y))
                                        val = newSVpvf("%.4g", (double)SvNV(*y));
                                }
                            }
                        }
                    }
                }
                hv_stores(v, "stat_value", val ? val : newSVpvs("-"));
                XSRETURN_EMPTY;
            }

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(res);
            XPUSHs(sv_2mortal(newSVpvs("kind")));
            XPUSHs(sv_2mortal(newSVpv(kind, 0)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::timeseries", G_SCALAR);
            SPAGAIN;
            fig = got ? SvREFCNT_inc(POPs) : NULL;
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;

            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(fig ? newSVsv(fig) : newSV(0)));
            PUTBACK;
            got = call_pv("Punk::Observe::Plot::encode", G_SCALAR);
            SPAGAIN;
            enc = got ? SvREFCNT_inc(POPs) : newSVpvs("");
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;
            if (fig) SvREFCNT_dec(fig);
            /* ONE ANSWER, NOT TWO.
             *
             * This used to set both halves and leave the caller to delete the
             * one it did not want - so the knowledge of what a viz means sat
             * in two files, and calling this function on its own produced a
             * panel that was a chart AND a table. The viz is right here; the
             * decision belongs here with it. */
            if (has_viz && strEQ(kind, "table")) SvREFCNT_dec(enc);
            else (void)hv_stores(v, "series_plot", enc);
        }

        rows = newAV();
        se = hv_fetchs(r, "series", 0);
        sa = (se && SvROK(*se) && SvTYPE(SvRV(*se)) == SVt_PVAV)
               ? (AV *)SvRV(*se) : NULL;
        n = sa ? av_len(sa) + 1 : 0;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(sa, i, 0);
            HV *s;
            SV **key, **pts;
            AV *pa;
            SSize_t j, m;
            STRLEN kl = 0;
            const char *kp = "";

            if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
            s = (HV *)SvRV(*e);
            key = hv_fetchs(s, "key", 0);
            if (key && SvOK(*key)) { kp = SvPV(*key, kl); if (kl) has_series = 1; }
            pts = hv_fetchs(s, "points", 0);
            if (!pts || !SvROK(*pts) || SvTYPE(SvRV(*pts)) != SVt_PVAV) continue;
            pa = (AV *)SvRV(*pts);
            m = av_len(pa) + 1;
            for (j = 0; j < m; j++) {
                SV **p = av_fetch(pa, j, 0);
                AV *row;
                AV *out;
                if (!p || !SvROK(*p) || SvTYPE(SvRV(*p)) != SVt_PVAV) continue;
                row = (AV *)SvRV(*p);
                out = newAV();
                { SV **t = av_fetch(row, 0, 0);
                  av_push(out, t ? newSVsv(*t) : newSV(0)); }
                av_push(out, newSVpvn(kp, kl));
                { SV **val = av_fetch(row, 1, 0);
                  av_push(out, val ? newSVsv(*val) : newSV(0)); }
                { SV **c = av_fetch(row, 2, 0);
                  av_push(out, c ? newSVsv(*c) : newSV(0)); }
                av_push(rows, newRV_noinc((SV *)out));
            }
        }

        /* By instant, DESCENDING. Compared as decimal strings - width then
         * value - because a nanosecond instant past 2^53 does not survive
         * being made a number, and two buckets a microsecond apart would then
         * sort as equal. */
        nrows = av_len(rows) + 1;
        if (nrows > 1) {
            SV **arr = AvARRAY(rows);
            SSize_t x;
            for (x = 1; x < nrows; x++) {
                SV *k = arr[x];
                SV **kt = av_fetch((AV *)SvRV(k), 0, 0);
                STRLEN kl = 0;
                const char *kp = (kt && SvOK(*kt)) ? SvPV(*kt, kl) : "";
                SSize_t y;
                for (y = x - 1; y >= 0; y--) {
                    SV **jt = av_fetch((AV *)SvRV(arr[y]), 0, 0);
                    STRLEN jl = 0;
                    const char *jp = (jt && SvOK(*jt)) ? SvPV(*jt, jl) : "";
                    if (po_ns_cmp_str(jp, (size_t)jl, kp, (size_t)kl, NULL) >= 0)
                        break;
                    arr[y + 1] = arr[y];
                }
                arr[y + 1] = k;
            }
        }

        (void)hv_stores(v, "bucket_truncated",
                        newSViv(nrows > MAXROWS ? (IV)nrows : 0));
        if (nrows > MAXROWS) nrows = MAXROWS;

        {
            AV *out = newAV();
            SSize_t x;
            for (x = 0; x < nrows; x++) {
                SV **e = av_fetch(rows, x, 0);
                AV *row;
                HV *o;
                SV **t, **k, **val, **c;
                char b[64];
                size_t bl;
                STRLEN tl = 0;
                const char *tp;

                if (!e || !SvROK(*e)) continue;
                row = (AV *)SvRV(*e);
                o = newHV();
                t = av_fetch(row, 0, 0);
                tp = (t && SvOK(*t)) ? SvPV(*t, tl) : "0";
                hv_stores(o, "t", t ? newSVsv(*t) : newSV(0));
                bl = po_fmt_time(tp, (size_t)tl, b);
                hv_stores(o, "time", newSVpvn(b, bl));
                k = av_fetch(row, 1, 0);
                hv_stores(o, "series", (k && SvOK(*k) && SvCUR(*k))
                          ? newSVsv(*k) : newSVpvs("(all)"));
                val = av_fetch(row, 2, 0);
                {
                    SV *num = NULL;
                    ENTER; SAVETMPS; PUSHMARK(SP);
                    XPUSHs(sv_2mortal(val ? newSVsv(*val) : newSV(0)));
                    PUTBACK;
                    got = call_pv("Punk::Observe::Plot::_num", G_SCALAR);
                    SPAGAIN;
                    num = got ? SvREFCNT_inc(POPs) : newSVpvs("");
                    PUTBACK;
                    FREETMPS; LEAVE;
                    SPAGAIN;
                    hv_stores(o, "value", num);
                }
                c = av_fetch(row, 3, 0);
                hv_stores(o, "count", c ? newSVsv(*c) : newSV(0));
                av_push(out, newRV_noinc((SV *)o));
            }
            {
                SV **vz3 = hv_fetchs(v, "viz", 0);
                int hv3 = vz3 && SvOK(*vz3) && SvCUR(*vz3);
                const char *k3 = hv3 ? SvPV_nolen(*vz3) : "line";
                if (!hv3 || strEQ(k3, "table"))
                    (void)hv_stores(v, "bucket_rows", newRV_noinc((SV *)out));
                else
                    SvREFCNT_dec((SV *)out);
            }
        }
        SvREFCNT_dec((SV *)rows);
        (void)hv_stores(v, "has_series", newSViv(has_series));
        XSRETURN_EMPTY;
    }
