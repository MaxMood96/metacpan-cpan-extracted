MODULE = Punk::Observe   PACKAGE = Punk::Observe::SVG   PREFIX = posv_

# --- the formatter, which is the point of po_svg.h --------------------------

SV *
posv_fmt(double v)
    CODE:
        {
            char b[32];
            size_t n = po_fmt(v, b);
            RETVAL = newSVpvn(b, n);
        }
    OUTPUT:
        RETVAL

SV *
posv_esc_attr(SV *in)
    CODE:
        {
            STRLEN len;
            const char *p;
            char out[PO_SVG_MAX];
            size_t n;
            p = SvPV(in, len);
            n = po_esc_attr(p, (size_t)len, out, sizeof(out));
            RETVAL = newSVpvn(out, n);
        }
    OUTPUT:
        RETVAL

# --- axes -------------------------------------------------------------------

void
posv_axis(double min, double max, int want)
    PPCODE:
        {
            po_axis a;
            HV *res = newHV();
            AV *ticks = newAV();
            int i;
            po_axis_make(&a, min, max, want);
            for (i = 0; i < a.n; i++) {
                char b[32];
                size_t n = po_fmt(a.tick[i], b);
                av_push(ticks, newSVpvn(b, n));
            }
            hv_stores(res, "ticks", newRV_noinc((SV *)ticks));
            hv_stores(res, "lo",    newSVnv((NV)a.lo));
            hv_stores(res, "hi",    newSVnv((NV)a.hi));
            hv_stores(res, "step",  newSVnv((NV)a.step));
            hv_stores(res, "n",     newSViv(a.n));
            mXPUSHs(newRV_noinc((SV *)res));
        }

# --- a line path ------------------------------------------------------------

SV *
posv_line(SV *xs, SV *ys, double w, double h)
    CODE:
        {
            AV *ax, *ay;
            SSize_t n, i;
            double *x, *y, x0 = 0, x1 = 0, y0 = 0, y1 = 0;
            po_svg s;

            if (!SvROK(xs) || !SvROK(ys)) croak("arrayrefs required");
            ax = (AV *)SvRV(xs); ay = (AV *)SvRV(ys);
            n = av_len(ax) + 1;
            Newxz(x, n ? n : 1, double);
            Newxz(y, n ? n : 1, double);
            for (i = 0; i < n; i++) {
                SV **a = av_fetch(ax, i, 0);
                SV **b = av_fetch(ay, i, 0);
                x[i] = a ? SvNV(*a) : 0;
                y[i] = b ? SvNV(*b) : 0;
                if (i == 0 || x[i] < x0) x0 = x[i];
                if (i == 0 || x[i] > x1) x1 = x[i];
                if (i == 0 || y[i] < y0) y0 = y[i];
                if (i == 0 || y[i] > y1) y1 = y[i];
            }
            if (!po_svg_init(&s, 256)) { Safefree(x); Safefree(y); croak("oom"); }
            po_svg_line(&s, x, y, (int)n, x0, x1, y0, y1, w, h);
            RETVAL = newSVpvn(s.b, s.n);
            po_svg_free(&s);
            Safefree(x); Safefree(y);
        }
    OUTPUT:
        RETVAL

MODULE = Punk::Observe   PACKAGE = Punk::Observe::Map   PREFIX = pomap_

# Lay a service graph out. Edges are (caller, callee, count, errors).
void
pomap_layout(SV *edges)
    PPCODE:
        {
            po_sgraph g;
            po_map m;
            AV *av;
            SSize_t i, n;
            AV *nodes = newAV();
            AV *backs = newAV();

            if (!SvROK(edges)) croak("arrayref required");
            av = (AV *)SvRV(edges);
            n = av_len(av) + 1;
            if (!po_sgraph_init(&g)) croak("oom");

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *h; SV **f;
                po_edge *ed;
                uint32_t caller = PO_SVC_UNKNOWN, callee = 0;
                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                if ((f = hv_fetchs(h, "caller", 0)) && SvOK(*f)) {
                    STRLEN l; const char *p = SvPV(*f, l);
                    if (!(l == 1 && p[0] == '*')) caller = (uint32_t)SvUV(*f);
                }
                if ((f = hv_fetchs(h, "callee", 0))) callee = (uint32_t)SvUV(*f);
                ed = po_sgraph_find(&g, caller, callee);
                if (!ed) { po_sgraph_free(&g); croak("oom"); }
                if ((f = hv_fetchs(h, "count", 0)))  ed->count  += SvUV(*f);
                if ((f = hv_fetchs(h, "errors", 0))) ed->errors += SvUV(*f);
            }

            if (!po_map_layout(&m, &g)) { po_sgraph_free(&g); croak("layout"); }

            for (i = 0; i < m.n; i++) {
                HV *h = newHV();
                hv_stores(h, "service", m.node[i].service == PO_SVC_UNKNOWN
                          ? newSVpvs("*") : newSVuv((UV)m.node[i].service));
                hv_stores(h, "layer", newSViv(m.node[i].layer));
                hv_stores(h, "slot",  newSViv(m.node[i].slot));
                hv_stores(h, "in",    po_u64_to_sv(m.node[i].in_count));
                hv_stores(h, "out",   po_u64_to_sv(m.node[i].out_count));
                hv_stores(h, "errors", po_u64_to_sv(m.node[i].errors));
                av_push(nodes, newRV_noinc((SV *)h));
            }
            for (i = 0; i < (SSize_t)g.n; i++)
                if (po_map_is_back_edge(&m, g.e[i].caller, g.e[i].callee))
                    av_push(backs, newSViv((IV)i));

            {
                HV *res = newHV();
                hv_stores(res, "nodes",  newRV_noinc((SV *)nodes));
                hv_stores(res, "layers", newSViv(m.layer_count));
                hv_stores(res, "back_edges", newSViv(m.back_edges));
                hv_stores(res, "back",   newRV_noinc((SV *)backs));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_sgraph_free(&g);
        }

MODULE = Punk::Observe   PACKAGE = Punk::Observe::Flame   PREFIX = pofl_

# Build an aggregated self-time tree from spans.
void
pofl_build(SV *specs)
    PPCODE:
        {
            po_span_w w;
            po_flame fl;
            AV *out = newAV();
            uint32_t i;

            if (!po_span_w_init(&w)) croak("oom");
            if (!pot_load(aTHX_ specs, &w)) { po_span_w_free(&w); croak("bad specs"); }
            po_span_w_seal(&w);
            if (!po_flame_init(&fl)) { po_span_w_free(&w); croak("oom"); }

            {   /* one trace at a time, as the compactor does */
                uint32_t a = 0;
                while (a < w.n) {
                    uint32_t b = a + 1;
                    po_tree t;
                    while (b < w.n && w.s[b].trace_hi == w.s[a].trace_hi
                                   && w.s[b].trace_lo == w.s[a].trace_lo) b++;
                    if (po_tree_build(&t, w.s + a, b - a)) {
                        po_flame_add(&fl, w.s + a, b - a, &t);
                        po_tree_free(&t);
                    }
                    a = b;
                }
            }

            for (i = 0; i < fl.n; i++) {
                HV *h = newHV();
                hv_stores(h, "name",    newSVuv((UV)fl.f[i].name_sym));
                hv_stores(h, "service", newSVuv((UV)fl.f[i].service_sym));
                hv_stores(h, "parent",  newSViv((IV)fl.f[i].parent));
                hv_stores(h, "depth",   newSViv((IV)fl.f[i].depth));
                hv_stores(h, "total",   po_u64_to_sv(fl.f[i].total));
                hv_stores(h, "self",    po_u64_to_sv(fl.f[i].self));
                hv_stores(h, "count",   po_u64_to_sv(fl.f[i].count));
                av_push(out, newRV_noinc((SV *)h));
            }
            {
                HV *res = newHV();
                hv_stores(res, "frames", newRV_noinc((SV *)out));
                hv_stores(res, "total_self", po_u64_to_sv(po_flame_total_self(&fl)));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_flame_free(&fl);
            po_span_w_free(&w);
        }
