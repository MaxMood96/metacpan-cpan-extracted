MODULE = Punk::Observe   PACKAGE = Punk::Observe::Retain   PREFIX = por_

# --- the merge --------------------------------------------------------------

# Merge several sorted runs of (t, series, kind) and report the order plus how
# many duplicates were collapsed.
void
por_merge(SV *runs)
    PPCODE:
        {
            po_merge m;
            AV *av;
            SSize_t i, n;
            po_rec **bufs;
            AV *out = newAV();

            if (!SvROK(runs)) croak("arrayref required");
            av = (AV *)SvRV(runs);
            n = av_len(av) + 1;
            Newxz(bufs, n ? n : 1, po_rec *);
            po_merge_init(&m);

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                AV *inner;
                SSize_t j, cnt;
                if (!e || !SvROK(*e)) continue;
                inner = (AV *)SvRV(*e);
                cnt = av_len(inner) + 1;
                Newxz(bufs[i], cnt ? cnt : 1, po_rec);
                for (j = 0; j < cnt; j++) {
                    SV **r = av_fetch(inner, j, 0);
                    HV *h; SV **f;
                    po_u64 v = 0;
                    if (!r || !SvROK(*r)) continue;
                    h = (HV *)SvRV(*r);
                    po_rec_zero(&bufs[i][j]);
                    if ((f = hv_fetchs(h, "t", 0)) && po_sv_to_u64(aTHX_ *f, &v))
                        bufs[i][j].t_unix_nano = v;
                    if ((f = hv_fetchs(h, "series", 0)) && po_sv_to_u64(aTHX_ *f, &v))
                        bufs[i][j].series = v;
                    if ((f = hv_fetchs(h, "kind", 0)))
                        bufs[i][j].kind = (uint8_t)SvUV(*f);
                }
                po_merge_add_run(&m, bufs[i], (size_t)cnt);
            }

            {
                const po_rec *r;
                while ((r = po_merge_next(&m))) {
                    HV *h = newHV();
                    hv_stores(h, "t",      po_u64_to_sv(r->t_unix_nano));
                    hv_stores(h, "series", po_u64_to_sv(r->series));
                    av_push(out, newRV_noinc((SV *)h));
                }
            }
            {
                HV *res = newHV();
                hv_stores(res, "records",    newRV_noinc((SV *)out));
                hv_stores(res, "emitted",    po_u64_to_sv(m.emitted));
                hv_stores(res, "duplicates", po_u64_to_sv(m.duplicates));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            for (i = 0; i < n; i++) Safefree(bufs[i]);
            Safefree(bufs);
        }

# --- rollups ----------------------------------------------------------------

# Fold raw points into a 5m tier, promote to 1h, and answer aggregates from
# each. Everything a test needs in one call.
void
por_rollup(SV *points, SV *agg)
    PPCODE:
        {
            po_rollup t5, t1h;
            AV *av;
            SSize_t i, n;
            int a = (int)SvIV(agg);
            double v5 = 0, v1 = 0;
            int ok5, ok1;

            if (!SvROK(points)) croak("arrayref required");
            av = (AV *)SvRV(points);
            n = av_len(av) + 1;

            if (!po_rollup_init(&t5, PO_TIER_5M)) croak("oom");
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *h; SV **f;
                po_u64 t = 0;
                double val = 0;
                int reset = 0;
                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                if ((f = hv_fetchs(h, "t", 0)))     (void)po_sv_to_u64(aTHX_ *f, &t);
                if ((f = hv_fetchs(h, "v", 0)))     val = SvNV(*f);
                if ((f = hv_fetchs(h, "reset", 0))) reset = (int)SvIV(*f);
                po_rollup_add(&t5, t, val, reset);
            }
            if (!po_rollup_promote(&t5, &t1h, PO_TIER_1H)) {
                po_rollup_free(&t5); croak("promote");
            }

            ok5 = po_rollup_agg(&t5,  a, &v5);
            ok1 = po_rollup_agg(&t1h, a, &v1);

            {
                HV *res = newHV();
                AV *b5 = newAV();
                uint32_t k;
                for (k = 0; k < t5.n; k++) {
                    HV *h = newHV();
                    hv_stores(h, "t",     po_u64_to_sv(t5.p[k].t));
                    hv_stores(h, "count", po_u64_to_sv(t5.p[k].count));
                    hv_stores(h, "sum",   newSVnv((NV)t5.p[k].sum));
                    hv_stores(h, "min",   newSVnv((NV)t5.p[k].min));
                    hv_stores(h, "max",   newSVnv((NV)t5.p[k].max));
                    hv_stores(h, "last",  newSVnv((NV)t5.p[k].last));
                    hv_stores(h, "resets", newSViv(t5.p[k].resets));
                    av_push(b5, newRV_noinc((SV *)h));
                }
                hv_stores(res, "buckets_5m", newRV_noinc((SV *)b5));
                hv_stores(res, "n_5m",  newSVuv((UV)t5.n));
                hv_stores(res, "n_1h",  newSVuv((UV)t1h.n));
                hv_stores(res, "ok_5m", newSViv(ok5));
                hv_stores(res, "ok_1h", newSViv(ok1));
                if (ok5) hv_stores(res, "value_5m", newSVnv((NV)v5));
                if (ok1) hv_stores(res, "value_1h", newSVnv((NV)v1));
                if (!ok5) hv_stores(res, "refusal", newSVpv(po_rollup_refusal(a), 0));
                hv_stores(res, "resets_5m", newSViv(po_rollup_resets(&t5)));
                hv_stores(res, "resets_1h", newSViv(po_rollup_resets(&t1h)));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_rollup_free(&t5);
            po_rollup_free(&t1h);
        }

# --- retention --------------------------------------------------------------

void
por_sweep(SV *paths, SV *cutoff)
    PPCODE:
        {
            po_retain r;
            AV *av;
            SSize_t i, n;
            po_u64 cut = 0;
            uint32_t marked;

            (void)po_sv_to_u64(aTHX_ cutoff, &cut);
            if (!SvROK(paths)) croak("arrayref required");
            av = (AV *)SvRV(paths);
            n = av_len(av) + 1;
            if (!po_retain_init(&r)) croak("oom");

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                if (e) po_retain_add(&r, SvPV_nolen(*e));
            }
            marked = po_retain_mark(&r, cut);
            po_retain_sweep(&r);

            {
                HV *res = newHV();
                hv_stores(res, "considered", newSVuv((UV)r.n));
                hv_stores(res, "marked",     newSVuv((UV)marked));
                hv_stores(res, "unlinked",   newSVuv((UV)r.unlinked));
                hv_stores(res, "kept",       newSVuv((UV)r.kept));
                hv_stores(res, "bytes_freed", po_u64_to_sv(r.bytes_freed));
                /* MUST be zero. ftruncate on a mapped segment is SIGBUS. */
                hv_stores(res, "truncate_calls", newSVuv((UV)r.truncate_calls));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_retain_free(&r);
        }

# Open a segment, keep the mapping, and report whether it still reads
# correctly after its name is unlinked underneath.
void
por_read_through_unlink(SV *path)
    PPCODE:
        {
            po_seg_r s;
            STRLEN plen;
            const char *p = SvPV(path, plen);
            HV *res = newHV();
            po_u64 before = 0, after = 0;
            size_t i;

            if (!po_seg_open(&s, p)) {
                hv_stores(res, "opened", newSViv(0));
                mXPUSHs(newRV_noinc((SV *)res));
                XSRETURN(1);
            }
            hv_stores(res, "opened", newSViv(1));

            for (i = 0; i < s.n; i++) before += s.rec[i].t_unix_nano;

            /* Delete the NAME while the mapping is held. */
            hv_stores(res, "unlinked", newSViv(unlink(p) == 0 ? 1 : 0));

            /* And read every record again, through the same mapping. On POSIX
             * this is defined and correct; with ftruncate it would be SIGBUS. */
            for (i = 0; i < s.n; i++) after += s.rec[i].t_unix_nano;

            hv_stores(res, "records", po_u64_to_sv((po_u64)s.n));
            hv_stores(res, "sum_before", po_u64_to_sv(before));
            hv_stores(res, "sum_after",  po_u64_to_sv(after));
            hv_stores(res, "same", newSViv(before == after ? 1 : 0));
            po_seg_close(&s);
            mXPUSHs(newRV_noinc((SV *)res));
        }

# --- generations ------------------------------------------------------------

void
por_generations(SV *ops)
    PPCODE:
        {
            po_gen_table t;
            AV *av;
            SSize_t i, n;
            AV *busy = newAV();

            memset(&t, 0, sizeof(t));
            if (!SvROK(ops)) croak("arrayref required");
            av = (AV *)SvRV(ops);
            n = av_len(av) + 1;
            for (i = 0; i + 1 < n; i += 2) {
                SV **op = av_fetch(av, i, 0);
                SV **g  = av_fetch(av, i + 1, 0);
                po_u64 gen = 0;
                STRLEN ol;
                const char *o;
                if (!op || !g) break;
                o = SvPV(*op, ol);
                (void)po_sv_to_u64(aTHX_ *g, &gen);
                if      (ol == 7 && memcmp(o, "acquire", 7) == 0) po_gen_acquire(&t, gen);
                else if (ol == 7 && memcmp(o, "release", 7) == 0) po_gen_release(&t, gen);
                else if (ol == 4 && memcmp(o, "busy", 4) == 0)
                    av_push(busy, newSViv(po_gen_busy(&t, gen)));
            }
            mXPUSHs(newRV_noinc((SV *)busy));
        }

int
por_block_removable(SV *segments, SV *expired_all)
    CODE:
        RETVAL = po_block_removable((uint32_t)SvUV(segments), (int)SvIV(expired_all));
    OUTPUT:
        RETVAL
