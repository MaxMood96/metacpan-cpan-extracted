MODULE = Punk::Observe   PACKAGE = Punk::Observe::Metric   PREFIX = pom_

# --- the bit stream ---------------------------------------------------------

# Round-trip a list of (width, value) pairs. The most testable code in the
# project, so it is exposed and tested exhaustively rather than implicitly.
void
pom_bits_roundtrip(SV *pairs)
    PPCODE:
        {
            po_bw w;
            AV *av;
            SSize_t i, n;
            AV *out = newAV();

            if (!SvROK(pairs) || SvTYPE(SvRV(pairs)) != SVt_PVAV)
                croak("pairs must be an arrayref");
            av = (AV *)SvRV(pairs);
            n = av_len(av) + 1;
            if (!po_bw_init(&w, 32)) croak("oom");

            for (i = 0; i < n; i += 2) {
                SV **wid = av_fetch(av, i, 0);
                SV **val = av_fetch(av, i + 1, 0);
                po_u64 v = 0;
                if (!wid || !val) break;
                (void)po_sv_to_u64(aTHX_ *val, &v);
                po_bw_put(&w, v, (int)SvIV(*wid));
            }
            {
                po_br r;
                po_br_init(&r, w.buf, w.nbits);
                for (i = 0; i < n; i += 2) {
                    SV **wid = av_fetch(av, i, 0);
                    if (!wid) break;
                    av_push(out, po_u64_to_sv(po_br_get(&r, (int)SvIV(*wid))));
                }
                {
                    HV *res = newHV();
                    hv_stores(res, "values", newRV_noinc((SV *)out));
                    hv_stores(res, "bits",   newSVuv((UV)w.nbits));
                    hv_stores(res, "err",    newSViv(r.err));
                    mXPUSHs(newRV_noinc((SV *)res));
                }
            }
            po_bw_free(&w);
        }

# Sign extension, isolated. A 12-bit -2047 read back as 2049 is one missing
# sign extension, and the symptom is a point in the wrong place on a chart.
SV *
pom_sext(SV *v, SV *bits)
    CODE:
        {
            po_u64 u = 0;
            po_i64 s;
            (void)po_sv_to_u64(aTHX_ v, &u);
            s = po_sext(u, (int)SvIV(bits));
            RETVAL = newSViv((IV)s);
        }
    OUTPUT:
        RETVAL

# --- gorilla ----------------------------------------------------------------

# Encode a series of (timestamp, value-bit-pattern) and decode it back.
# Values cross as BIT PATTERNS so NaN payloads, the infinities and negative
# zero survive the Perl boundary as exactly what they are.
void
pom_gorilla_roundtrip(SV *ts, SV *vals)
    PPCODE:
        {
            po_gor_w w;
            AV *at, *av;
            SSize_t i, n;
            AV *ot = newAV(), *ov = newAV();

            if (!SvROK(ts) || !SvROK(vals)) croak("arrayrefs required");
            at = (AV *)SvRV(ts); av = (AV *)SvRV(vals);
            n = av_len(at) + 1;
            if (!po_gor_w_init(&w)) croak("oom");

            for (i = 0; i < n; i++) {
                SV **t = av_fetch(at, i, 0);
                SV **v = av_fetch(av, i, 0);
                po_u64 tt = 0, vv = 0;
                if (!t || !v) break;
                (void)po_sv_to_u64(aTHX_ *t, &tt);
                (void)po_sv_to_u64(aTHX_ *v, &vv);
                po_gor_put(&w, tt, vv);
            }

            {
                po_gor_r r;
                po_u64 t2, v2;
                po_gor_r_init(&r, w.bw.buf, w.bw.nbits, w.n);
                while (po_gor_next(&r, &t2, &v2)) {
                    av_push(ot, po_u64_to_sv(t2));
                    av_push(ov, po_u64_to_sv(v2));
                }
                {
                    HV *res = newHV();
                    hv_stores(res, "t",      newRV_noinc((SV *)ot));
                    hv_stores(res, "v",      newRV_noinc((SV *)ov));
                    hv_stores(res, "bits",   newSVuv((UV)w.bw.nbits));
                    hv_stores(res, "bytes",  newSVuv((UV)po_bw_bytes(&w.bw)));
                    hv_stores(res, "points", newSVuv((UV)w.n));
                    hv_stores(res, "err",    newSViv(r.br.err));
                    mXPUSHs(newRV_noinc((SV *)res));
                }
            }
            po_gor_w_free(&w);
        }

# A double's bit pattern and back, so a test can speak in doubles where that
# is clearer and in bits where it must be exact.
SV *
pom_d2b(double d)
    CODE:
        RETVAL = po_u64_to_sv(po_d2b(d));
    OUTPUT:
        RETVAL

double
pom_b2d(SV *b)
    CODE:
        {
            po_u64 v = 0;
            (void)po_sv_to_u64(aTHX_ b, &v);
            RETVAL = po_b2d(v);
        }
    OUTPUT:
        RETVAL

# --- chunks -----------------------------------------------------------------

void
pom_chunk(SV *ts, SV *vals, SV *is_int, SV *flags)
    PPCODE:
        {
            po_chunk_w c;
            AV *at, *av;
            SSize_t i, n;
            AV *ot = newAV(), *ov = newAV();

            if (!SvROK(ts) || !SvROK(vals)) croak("arrayrefs required");
            at = (AV *)SvRV(ts); av = (AV *)SvRV(vals);
            n = av_len(at) + 1;
            if (!po_chunk_w_init(&c, (int)SvIV(is_int), (uint16_t)SvUV(flags)))
                croak("oom");

            for (i = 0; i < n; i++) {
                SV **t = av_fetch(at, i, 0);
                SV **v = av_fetch(av, i, 0);
                po_u64 tt = 0, vv = 0;
                if (!t || !v) break;
                (void)po_sv_to_u64(aTHX_ *t, &tt);
                (void)po_sv_to_u64(aTHX_ *v, &vv);
                if (po_chunk_full(&c, tt)) break;
                po_chunk_add(&c, tt, vv);
            }

            {
                po_chunk_r rd;
                po_u64 t2, v2;
                po_chunk_r_init(&rd, &c.h, c.g.bw.buf);
                while (po_chunk_next(&rd, &t2, &v2)) {
                    av_push(ot, po_u64_to_sv(t2));
                    av_push(ov, po_u64_to_sv(v2));
                }
                {
                    HV *res = newHV();
                    hv_stores(res, "t", newRV_noinc((SV *)ot));
                    hv_stores(res, "v", newRV_noinc((SV *)ov));
                    hv_stores(res, "count",   newSVuv((UV)c.h.count));
                    hv_stores(res, "bytes",   newSVuv((UV)po_bw_bytes(&c.g.bw)));
                    hv_stores(res, "flags",   newSVuv((UV)c.h.flags));
                    hv_stores(res, "resets",  newSViv(c.resets));
                    hv_stores(res, "t_first", po_u64_to_sv(c.h.t_first));
                    hv_stores(res, "t_last",  po_u64_to_sv(c.h.t_last));
                    mXPUSHs(newRV_noinc((SV *)res));
                }
            }
            po_chunk_w_free(&c);
        }

# --- exemplars --------------------------------------------------------------

void
pom_exemplars(SV *specs)
    PPCODE:
        {
            po_exemplars x;
            AV *av;
            SSize_t i, n;
            AV *out = newAV();
            int refused = 0;

            if (!SvROK(specs)) croak("arrayref required");
            av = (AV *)SvRV(specs);
            n = av_len(av) + 1;
            if (!po_exemplars_init(&x)) croak("oom");

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *h; SV **f;
                po_exemplar ex;
                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                memset(&ex, 0, sizeof(ex));
                if ((f = hv_fetchs(h, "t", 0)))        (void)po_sv_to_u64(aTHX_ *f, &ex.t);
                if ((f = hv_fetchs(h, "value", 0)))    (void)po_sv_to_u64(aTHX_ *f, &ex.value_bits);
                if ((f = hv_fetchs(h, "trace_hi", 0))) (void)po_sv_to_u64(aTHX_ *f, &ex.trace_hi);
                if ((f = hv_fetchs(h, "trace_lo", 0))) (void)po_sv_to_u64(aTHX_ *f, &ex.trace_lo);
                if ((f = hv_fetchs(h, "span_id", 0)))  (void)po_sv_to_u64(aTHX_ *f, &ex.span_id);
                if (!po_exemplar_add(&x, &ex)) refused++;
            }
            {
                uint32_t k;
                for (k = 0; k < x.n; k++) {
                    HV *h = newHV();
                    hv_stores(h, "t",        po_u64_to_sv(x.e[k].t));
                    hv_stores(h, "trace_hi", po_u64_to_sv(x.e[k].trace_hi));
                    hv_stores(h, "trace_lo", po_u64_to_sv(x.e[k].trace_lo));
                    hv_stores(h, "span_id",  po_u64_to_sv(x.e[k].span_id));
                    av_push(out, newRV_noinc((SV *)h));
                }
            }
            {
                HV *res = newHV();
                hv_stores(res, "kept",    newRV_noinc((SV *)out));
                hv_stores(res, "refused", newSViv(refused));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_exemplars_free(&x);
        }

# --- postings ---------------------------------------------------------------

void
pom_postings(SV *lists)
    PPCODE:
        {
            AV *av;
            SSize_t nl, li;
            char **enc;
            size_t *elen;
            AV *sizes = newAV();

            if (!SvROK(lists)) croak("arrayref required");
            av = (AV *)SvRV(lists);
            nl = av_len(av) + 1;
            if (nl < 1) croak("need at least one list");

            Newxz(enc, nl, char *);
            Newxz(elen, nl, size_t);

            for (li = 0; li < nl; li++) {
                SV **e = av_fetch(av, li, 0);
                AV *inner;
                SSize_t i, n;
                po_postings p;
                if (!e || !SvROK(*e)) continue;
                inner = (AV *)SvRV(*e);
                n = av_len(inner) + 1;
                if (!po_postings_init(&p)) croak("oom");
                for (i = 0; i < n; i++) {
                    SV **v = av_fetch(inner, i, 0);
                    if (v) po_postings_add(&p, (uint32_t)SvUV(*v));
                }
                po_postings_finish(&p);
                elen[li] = po_postings_encode(&p, &enc[li]);
                av_push(sizes, newSVuv((UV)elen[li]));
                po_postings_free(&p);
            }

            {
                HV *res = newHV();
                AV *members = newAV();
                po_post_r r;
                uint32_t id;
                if (po_post_open(&r, enc[0], elen[0]))
                    while (po_post_next(&r, &id)) av_push(members, newSVuv((UV)id));
                hv_stores(res, "first", newRV_noinc((SV *)members));
                hv_stores(res, "sizes", newRV_noinc((SV *)sizes));

                if (nl >= 2) {
                    uint32_t *out;
                    uint32_t got;
                    AV *inter = newAV();
                    uint32_t k;
                    Newx(out, 100000, uint32_t);
                    got = po_post_intersect(enc[0], elen[0], enc[1], elen[1],
                                            out, 100000);
                    for (k = 0; k < got && k < 100000; k++)
                        av_push(inter, newSVuv((UV)out[k]));
                    hv_stores(res, "intersection", newRV_noinc((SV *)inter));
                    Safefree(out);
                }
                mXPUSHs(newRV_noinc((SV *)res));
            }
            for (li = 0; li < nl; li++) free(enc[li]);
            Safefree(enc);
            Safefree(elen);
        }
