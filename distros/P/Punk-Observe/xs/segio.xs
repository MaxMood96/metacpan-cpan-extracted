MODULE = Punk::Observe   PACKAGE = Punk::Observe::SegIO   PREFIX = psio_

# Write ONE segment carrying all three signals, then reopen it and read them
# all back. This is the join phases 5, 6 and 7 each deferred: their structures
# reach a disk here.
SV *
psio_write_all(SV *path, SV *spec)
    CODE:
        {
            po_seg_w w;
            HV *sp;
            SV **f;
            uint8_t ulid[16];
            int i, ok = 1;

            if (!SvROK(spec) || SvTYPE(SvRV(spec)) != SVt_PVHV)
                croak("spec must be a hashref");
            sp = (HV *)SvRV(spec);

            if (!po_seg_w_init(&w, PO_SIG_MIXED, 0, "acme", 4)) croak("oom");

            /* one record so the segment has a time span */
            {
                po_rec r;
                po_rec_zero(&r);
                r.kind = PO_SPAN;
                r.t_unix_nano = 1000;
                po_seg_w_add(&w, &r, "seed", 4, "l", 1, NULL);
            }

            /* --- metrics --- */
            if ((f = hv_fetchs(sp, "metrics", 0)) && SvROK(*f)) {
                AV *av = (AV *)SvRV(*f);
                SSize_t n = av_len(av) + 1, k;
                po_chunk_hdr *hdrs;
                char **streams;
                po_u64 *series;
                po_chunk_w *cw;
                char *blob; size_t blen;

                Newxz(hdrs, n ? n : 1, po_chunk_hdr);
                Newxz(streams, n ? n : 1, char *);
                Newxz(series, n ? n : 1, po_u64);
                Newxz(cw, n ? n : 1, po_chunk_w);

                for (k = 0; k < n; k++) {
                    SV **e = av_fetch(av, k, 0);
                    HV *h; SV **g;
                    AV *pts;
                    SSize_t j, np;
                    if (!e || !SvROK(*e)) continue;
                    h = (HV *)SvRV(*e);
                    if ((g = hv_fetchs(h, "series", 0)))
                        (void)po_sv_to_u64(aTHX_ *g, &series[k]);
                    po_chunk_w_init(&cw[k], 0, 0);
                    if ((g = hv_fetchs(h, "points", 0)) && SvROK(*g)) {
                        pts = (AV *)SvRV(*g);
                        np = av_len(pts) + 1;
                        for (j = 0; j + 1 < np; j += 2) {
                            SV **t = av_fetch(pts, j, 0);
                            SV **v = av_fetch(pts, j + 1, 0);
                            po_u64 tt = 0;
                            if (!t || !v) break;
                            (void)po_sv_to_u64(aTHX_ *t, &tt);
                            po_chunk_add(&cw[k], tt, po_d2b(SvNV(*v)));
                        }
                    }
                    hdrs[k] = cw[k].h;
                    streams[k] = (char *)cw[k].g.bw.buf;
                    if (hdrs[k].count)
                        po_seg_w_span(&w, hdrs[k].t_first, hdrs[k].t_last);
                }
                blob = po_metric_serialise(hdrs, (const char *const *)streams,
                                           series, (uint32_t)n, &blen);
                if (blob) po_seg_w_region(&w, PO_RGN_MCHUNKS, blob, blen, 1);
                else ok = 0;
                for (k = 0; k < n; k++) po_chunk_w_free(&cw[k]);
                Safefree(hdrs); Safefree(streams); Safefree(series); Safefree(cw);
            }

            /* --- logs --- */
            if (ok && (f = hv_fetchs(sp, "logs", 0)) && SvROK(*f)) {
                AV *av = (AV *)SvRV(*f);
                SSize_t n = av_len(av) + 1, k;
                po_block_w *bw;
                po_block_hdr *hdrs;
                char **comps;
                unsigned char **blooms;
                char *blob; size_t blen;

                Newxz(bw, n ? n : 1, po_block_w);
                Newxz(hdrs, n ? n : 1, po_block_hdr);
                Newxz(comps, n ? n : 1, char *);
                Newxz(blooms, n ? n : 1, unsigned char *);

                for (k = 0; k < n; k++) {
                    SV **e = av_fetch(av, k, 0);
                    AV *lines;
                    SSize_t j, nl;
                    size_t clen = 0;
                    po_u64 t0 = 1000, stream = (po_u64)(k + 1);
                    if (!e || !SvROK(*e)) continue;
                    /* Either a plain arrayref of lines, or a hashref carrying
                     * a start time and a stream: pruning by TIME cannot be
                     * tested against blocks that all share one. */
                    if (SvTYPE(SvRV(*e)) == SVt_PVHV) {
                        HV *lh = (HV *)SvRV(*e);
                        SV **g;
                        if ((g = hv_fetchs(lh, "t0", 0))) (void)po_sv_to_u64(aTHX_ *g, &t0);
                        if ((g = hv_fetchs(lh, "stream", 0))) (void)po_sv_to_u64(aTHX_ *g, &stream);
                        g = hv_fetchs(lh, "lines", 0);
                        if (!g || !SvROK(*g)) continue;
                        lines = (AV *)SvRV(*g);
                    }
                    else lines = (AV *)SvRV(*e);
                    nl = av_len(lines) + 1;
                    po_block_w_init(&bw[k], stream);
                    for (j = 0; j < nl; j++) {
                        SV **l = av_fetch(lines, j, 0);
                        STRLEN bl;
                        const char *body;
                        if (!l) continue;
                        body = SvPV(*l, bl);
                        po_block_add(&bw[k], t0 + (po_u64)j * 10, 9,
                                     body, (size_t)bl, 0, 0, 0);
                    }
                    if (!po_block_seal(&bw[k], &comps[k], &clen)) { ok = 0; break; }
                    hdrs[k]  = bw[k].h;
                    blooms[k] = bw[k].bloom.bits;
                    if (hdrs[k].lines)
                        po_seg_w_span(&w, hdrs[k].t_min, hdrs[k].t_max);
                }
                if (ok) {
                    blob = po_log_serialise(hdrs, (const char *const *)comps,
                                            (const unsigned char *const *)blooms,
                                            (uint32_t)n, &blen);
                    if (blob) po_seg_w_region(&w, PO_RGN_LOGBLOCKS, blob, blen, 1);
                    else ok = 0;
                }
                for (k = 0; k < n; k++) { free(comps[k]); po_block_w_free(&bw[k]); }
                Safefree(bw); Safefree(hdrs); Safefree(comps); Safefree(blooms);
            }

            /* --- spans --- */
            if (ok && (f = hv_fetchs(sp, "spans", 0)) && SvROK(*f)) {
                po_span_w sw;
                AV *av = (AV *)SvRV(*f);
                SSize_t n = av_len(av) + 1, k;
                char *blob; size_t blen;

                if (!po_span_w_init(&sw)) croak("oom");
                for (k = 0; k < n; k++) {
                    SV **e = av_fetch(av, k, 0);
                    HV *h; SV **g;
                    po_span s;
                    po_u64 endv = 0;
                    if (!e || !SvROK(*e)) continue;
                    h = (HV *)SvRV(*e);
                    memset(&s, 0, sizeof(s));
                    if ((g = hv_fetchs(h, "trace_hi", 0))) (void)po_sv_to_u64(aTHX_ *g, &s.trace_hi);
                    if ((g = hv_fetchs(h, "trace_lo", 0))) (void)po_sv_to_u64(aTHX_ *g, &s.trace_lo);
                    if ((g = hv_fetchs(h, "span_id", 0)))  (void)po_sv_to_u64(aTHX_ *g, &s.span_id);
                    if ((g = hv_fetchs(h, "parent", 0)))   (void)po_sv_to_u64(aTHX_ *g, &s.parent_span_id);
                    if ((g = hv_fetchs(h, "start", 0)))    (void)po_sv_to_u64(aTHX_ *g, &s.start_ns);
                    if ((g = hv_fetchs(h, "end", 0)))      (void)po_sv_to_u64(aTHX_ *g, &endv);
                    if ((g = hv_fetchs(h, "service", 0)))  s.service_sym = (uint32_t)SvUV(*g);
                    if ((g = hv_fetchs(h, "status", 0)))   s.status = (uint8_t)SvUV(*g);
                    s.dur_ns = endv >= s.start_ns ? endv - s.start_ns : 0;
                    po_seg_w_span(&w, s.start_ns, s.start_ns + s.dur_ns);
                    po_span_add(&sw, &s);
                }
                po_span_w_seal(&sw);
                blob = po_span_serialise(sw.s, (uint32_t)sw.n, &blen);
                if (blob) po_seg_w_region(&w, PO_RGN_SPANS, blob, blen, 1);
                else ok = 0;

                if (ok) {
                    po_tsum_set sums;
                    if (po_tsum_init(&sums)
                        && po_tsum_build(&sums, sw.s, (uint32_t)sw.n)) {
                        char *tb; size_t tl;
                        tb = po_tsum_serialise(sums.t, sums.n, &tl);
                        if (tb) po_seg_w_region(&w, PO_RGN_TRACESUM, tb, tl, 1);
                    }
                    po_tsum_free(&sums);
                }
                po_span_w_free(&sw);
            }

            for (i = 0; i < 16; i++) ulid[i] = (uint8_t)(i * 5 + 1);
            if (ok) ok = po_seg_write(&w, SvPV_nolen(path), ulid);
            po_seg_w_free(&w);
            RETVAL = newSViv(ok ? 1 : 0);
        }
    OUTPUT:
        RETVAL

# Reopen and read every signal back out of the mapping.
void
psio_read_all(SV *path)
    PPCODE:
        {
            po_seg_r s;
            HV *res;
            const char *p;
            size_t len;

            if (!po_seg_open(&s, SvPV_nolen(path))) {
                mXPUSHs(&PL_sv_undef);
                XSRETURN(1);
            }
            res = newHV();
            hv_stores(res, "regions", newSViv(s.nrgn));

            /* --- metrics --- */
            if ((p = po_seg_region_ptr(&s, PO_RGN_MCHUNKS, &len))) {
                po_mchunk_ref refs[64];
                int n = po_metric_open(p, len, refs, 64);
                AV *out = newAV();
                int k;
                for (k = 0; k < n; k++) {
                    HV *h = newHV();
                    po_chunk_r rd;
                    po_u64 t, bits;
                    AV *pts = newAV();
                    hv_stores(h, "series", po_u64_to_sv(refs[k].series));
                    hv_stores(h, "count",  newSVuv((UV)refs[k].h.count));
                    po_chunk_r_init(&rd, &refs[k].h, refs[k].bits);
                    while (po_chunk_next(&rd, &t, &bits)) {
                        av_push(pts, po_u64_to_sv(t));
                        av_push(pts, newSVnv((NV)po_b2d(bits)));
                    }
                    hv_stores(h, "points", newRV_noinc((SV *)pts));
                    av_push(out, newRV_noinc((SV *)h));
                }
                hv_stores(res, "metrics", newRV_noinc((SV *)out));
                hv_stores(res, "metrics_ok", newSViv(n >= 0));
            }

            /* --- logs --- */
            if ((p = po_seg_region_ptr(&s, PO_RGN_LOGBLOCKS, &len))) {
                po_lblock_ref refs[64];
                int n = po_log_open(p, len, refs, 64);
                AV *out = newAV();
                int k;
                for (k = 0; k < n; k++) {
                    char *raw = NULL;
                    AV *lines = newAV();
                    if (po_block_inflate(&refs[k].h, refs[k].comp,
                                         refs[k].h.comp_len, &raw)) {
                        po_line_r r; po_line ln;
                        po_line_r_init(&r, &refs[k].h, raw);
                        while (po_line_next(&r, &ln))
                            av_push(lines, newSVpvn(ln.body, ln.body_len));
                        free(raw);
                    }
                    av_push(out, newRV_noinc((SV *)lines));
                }
                hv_stores(res, "logs", newRV_noinc((SV *)out));
                hv_stores(res, "logs_ok", newSViv(n >= 0));
            }

            /* --- spans, read straight out of the mapping --- */
            if ((p = po_seg_region_ptr(&s, PO_RGN_SPANS, &len))) {
                uint32_t n = 0;
                const po_span *sp = po_span_open(p, len, &n);
                AV *out = newAV();
                uint32_t k;
                for (k = 0; sp && k < n; k++) {
                    HV *h = newHV();
                    hv_stores(h, "trace_hi", po_u64_to_sv(sp[k].trace_hi));
                    hv_stores(h, "trace_lo", po_u64_to_sv(sp[k].trace_lo));
                    hv_stores(h, "span_id",  po_u64_to_sv(sp[k].span_id));
                    hv_stores(h, "start",    po_u64_to_sv(sp[k].start_ns));
                    hv_stores(h, "duration", po_u64_to_sv(sp[k].dur_ns));
                    hv_stores(h, "service",  newSVuv((UV)sp[k].service_sym));
                    av_push(out, newRV_noinc((SV *)h));
                }
                hv_stores(res, "spans", newRV_noinc((SV *)out));
                hv_stores(res, "spans_ok", newSViv(sp ? 1 : 0));
            }

            /* --- trace summaries --- */
            if ((p = po_seg_region_ptr(&s, PO_RGN_TRACESUM, &len))) {
                uint32_t n = 0;
                const po_tsummary *t = po_tsum_open(p, len, &n);
                AV *out = newAV();
                uint32_t k;
                for (k = 0; t && k < n; k++) {
                    HV *h = newHV();
                    hv_stores(h, "trace_hi", po_u64_to_sv(t[k].trace_hi));
                    hv_stores(h, "duration", po_u64_to_sv(t[k].dur_ns));
                    hv_stores(h, "spans",    newSVuv((UV)t[k].spans));
                    av_push(out, newRV_noinc((SV *)h));
                }
                hv_stores(res, "summaries", newRV_noinc((SV *)out));
            }

            po_seg_close(&s);
            mXPUSHs(newRV_noinc((SV *)res));
        }
