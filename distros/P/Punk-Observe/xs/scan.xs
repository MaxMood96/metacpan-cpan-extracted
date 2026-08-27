MODULE = Punk::Observe   PACKAGE = Punk::Observe::Scan   PREFIX = posc_

# What a query pushes down: the time range it proves, the term the bloom can
# probe, and the first equality a directory can answer.
void
posc_pushdown(SV *query)
    PPCODE:
        {
            po_query    q;
            po_plan     plan;
            po_pushdown pd;
            STRLEN      qlen;
            const char *qp = SvPV(query, qlen);
            HV         *r  = newHV();

            if (!po_parse(&q, qp, (size_t)qlen)) {
                hv_stores(r, "ok", newSViv(0));
                hv_stores(r, "error", newSVpv(q.err, 0));
                mXPUSHs(newRV_noinc((SV *)r));
                XSRETURN(1);
            }
            if (!po_plan_build(&plan, &q, NULL)) {
                hv_stores(r, "ok", newSViv(0));
                hv_stores(r, "error", newSVpv(plan.err, 0));
                po_query_free(&q);
                mXPUSHs(newRV_noinc((SV *)r));
                XSRETURN(1);
            }
            po_pushdown_build(&pd, &plan);

            hv_stores(r, "ok",      newSViv(1));
            hv_stores(r, "from",    po_u64_to_sv(pd.from));
            hv_stores(r, "to",      po_u64_to_sv(pd.to));
            hv_stores(r, "bounded", newSViv(pd.time_bounded));
            hv_stores(r, "empty",   newSViv(po_pushdown_empty(&pd)));
            hv_stores(r, "search",  pd.search_len
                      ? newSVpvn(pd.search, pd.search_len) : newSVpvs(""));
            hv_stores(r, "eq_field", pd.have_eq
                      ? newSVpvn(pd.eq_field, pd.eq_field_len) : newSVpvs(""));
            hv_stores(r, "eq_value", pd.have_eq
                      ? newSVpvn(pd.eq_val, pd.eq_val_len) : newSVpvs(""));
            hv_stores(r, "min_duration", pd.have_min_dur
                      ? po_u64_to_sv(pd.min_dur) : newSViv(0));
            po_query_free(&q);
            mXPUSHs(newRV_noinc((SV *)r));
        }

# Prune a real segment with a real query, and report what was NOT read.
void
posc_prune(SV *path, SV *query, SV *opts)
    PPCODE:
        {
            po_query    q;
            po_plan     plan;
            po_pushdown pd;
            po_result   res;
            po_seg_r    s;
            po_prune_stats st;
            STRLEN      plen, qlen;
            const char *pp = SvPV(path, plen);
            const char *qp = SvPV(query, qlen);
            HV         *r  = newHV();
            HV         *o  = NULL;
            int         have_stream = 0;
            po_u64      stream = 0;
            int         nm = 0, nl = 0, nt = 0, wanted;

            if (SvROK(opts) && SvTYPE(SvRV(opts)) == SVt_PVHV) {
                SV **f;
                o = (HV *)SvRV(opts);
                if ((f = hv_fetchs(o, "stream", 0)) && SvOK(*f)) {
                    have_stream = 1;
                    (void)po_sv_to_u64(aTHX_ *f, &stream);
                }
            }

            if (!po_parse(&q, qp, (size_t)qlen)) {
                hv_stores(r, "ok", newSViv(0));
                hv_stores(r, "error", newSVpv(q.err, 0));
                mXPUSHs(newRV_noinc((SV *)r));
                XSRETURN(1);
            }
            if (!po_plan_build(&plan, &q, NULL)) {
                hv_stores(r, "ok", newSViv(0));
                hv_stores(r, "error", newSVpv(plan.err, 0));
                po_query_free(&q);
                mXPUSHs(newRV_noinc((SV *)r));
                XSRETURN(1);
            }
            po_pushdown_build(&pd, &plan);
            po_result_init(&res);
            memset(&st, 0, sizeof(st));

            if (!po_seg_open(&s, pp)) {
                hv_stores(r, "ok", newSViv(0));
                hv_stores(r, "error", newSVpvs("cannot open segment"));
                po_query_free(&q);
                mXPUSHs(newRV_noinc((SV *)r));
                XSRETURN(1);
            }

            wanted = po_scan_segment_wanted(&s, &pd, &res);
            if (wanted) {
                po_mchunk_ref  mc[256];
                po_lblock_ref  lb[256];
                const po_tsummary *ts[256];
                nm = po_scan_metric_chunks(&s, &pd, mc, 256, &res);
                nl = po_scan_log_blocks(&s, &pd, have_stream, stream,
                                        lb, 256, &res, &st);
                nt = po_scan_trace_summaries(&s, &pd, ts, 256, &res);
            }

            hv_stores(r, "ok",             newSViv(1));
            hv_stores(r, "segment_wanted", newSViv(wanted));
            hv_stores(r, "blocks",         po_u64_to_sv(res.blocks));
            hv_stores(r, "blocks_skipped", po_u64_to_sv(res.blocks_skipped));
            hv_stores(r, "metric_chunks",  newSViv(nm));
            hv_stores(r, "log_blocks",     newSViv(nl));
            hv_stores(r, "traces",         newSViv(nt));
            hv_stores(r, "considered",     newSVuv(st.considered));
            hv_stores(r, "skipped_stream", newSVuv(st.skipped_stream));
            hv_stores(r, "skipped_time",   newSVuv(st.skipped_time));
            hv_stores(r, "skipped_bloom",  newSVuv(st.skipped_bloom));

            po_seg_close(&s);
            po_result_free(&res);
            po_query_free(&q);
            mXPUSHs(newRV_noinc((SV *)r));
        }
