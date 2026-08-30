MODULE = Punk::Observe   PACKAGE = Punk::Observe::Exec   PREFIX = poe_

# Execute a query over seeded rows.
#
# Rows come from Perl here; in production the scan operator reads them from an
# mmap'd segment. Nothing above the scan changes, which is the point of the
# one-row-shape decision in phase 0.
void
poe_run(SV *query, SV *rows, SV *opts)
    PPCODE:
        {
            po_query   q;
            po_plan    plan;
            po_budget  budget;
            po_result  res;
            po_qexec   x;
            po_row    *rv = NULL;
            SV       **keep = NULL;
            IV         nrows = 0;
            STRLEN     qlen;
            const char *qp;
            HV        *o = NULL;
            po_u64     step_budget = 0, hard_max = 0;
            int        status;

            qp = SvPV(query, qlen);
            if (SvROK(opts) && SvTYPE(SvRV(opts)) == SVt_PVHV) o = (HV *)SvRV(opts);

            memset(&budget, 0, sizeof(budget));
            if (o) {
                SV **f;
                if ((f = hv_fetchs(o, "max_rows", 0)))
                    (void)po_sv_to_u64(aTHX_ *f, &budget.max_rows);
                if ((f = hv_fetchs(o, "rows_available", 0)))
                    (void)po_sv_to_u64(aTHX_ *f, &budget.rows_available);
                if ((f = hv_fetchs(o, "step", 0)))
                    (void)po_sv_to_u64(aTHX_ *f, &step_budget);
                if ((f = hv_fetchs(o, "hard_max", 0)))
                    (void)po_sv_to_u64(aTHX_ *f, &hard_max);
            }

            if (!po_parse(&q, qp, (size_t)qlen)) {
                HV *r = newHV();
                hv_stores(r, "ok", newSViv(0));
                hv_stores(r, "error", newSVpv(q.err, 0));
                hv_stores(r, "stage", newSVpvs("parse"));
                po_query_free(&q);
                mXPUSHs(newRV_noinc((SV *)r));
                XSRETURN(1);
            }

            if (!po_plan_build(&plan, &q, &budget)) {
                HV *r = newHV();
                hv_stores(r, "ok", newSViv(0));
                hv_stores(r, "error", newSVpv(plan.err, 0));
                hv_stores(r, "stage", newSVpvs("plan"));
                po_query_free(&q);
                mXPUSHs(newRV_noinc((SV *)r));
                XSRETURN(1);
            }

            nrows = poe_load_rows(aTHX_ rows, &rv, &keep);
            if (nrows < 0) { po_query_free(&q); croak("bad rows"); }

            po_result_init(&res);
            po_qexec_init(&x, &plan, rv, (po_u64)nrows, &res,
                          step_budget, hard_max);
            status = po_qexec_run(&x);

            {
                HV *r = newHV();
                HV *meta = newHV();

                /* A REFUSAL, NOT A SHORT ANSWER. A bucketed chart that simply
                 * stops has a shape somebody reads as "the service went
                 * quiet", so this reports failure and says what to change.
                 *
                 * It falls through to the shared cleanup at the end of the
                 * block rather than returning here: the data is skipped, the
                 * metadata is not, because a caller asking why it was refused
                 * wants to know how much was scanned before it was. */
                if (res.too_many_groups) {
                    hv_stores(r, "ok", newSViv(0));
                    hv_stores(r, "error", newSVpvs(
                        "that query produces more series than can be answered"
                        " - try a wider bucket, a shorter range, or fewer"
                        " fields after `by`"));
                    hv_stores(r, "stage", newSVpvs("plan"));
                }
                else {

                hv_stores(r, "ok", newSViv(status == PO_Q_DONE ? 1 : 0));
                hv_stores(r, "shape",
                    newSVpv(res.shape == PO_RES_ROWS ? "rows"
                          : res.bucket_ns ? "buckets"
                          : res.shape == PO_RES_SERIES ? "series" : "scalar", 0));

                if (res.shape == PO_RES_ROWS) {
                    AV *out = newAV();
                    uint32_t i;
                    po_u64 lim = plan.limit ? plan.limit
                               : (plan.slowest ? plan.slowest : 0);
                    uint32_t n = res.nrow;
                    if (lim && (po_u64)n > lim) n = (uint32_t)lim;
                    for (i = 0; i < n; i++) {
                        HV *h = newHV();
                        const po_row *w = &res.row[i];
                        hv_stores(h, "t", po_u64_to_sv(w->t));
                        if (w->body)
                            hv_stores(h, "body", newSVpvn(w->body, w->body_len));
                        if (w->service)
                            hv_stores(h, "service", newSVpvn(w->service, w->service_len));
                        if (w->kind == PO_LOG)
                            hv_stores(h, "severity", newSVuv((UV)w->severity));
                        if (w->kind == PO_SPAN)
                            hv_stores(h, "duration", po_u64_to_sv(w->duration));
                        if (w->kind == PO_METRIC)
                            hv_stores(h, "value", newSVnv((NV)w->value));
                        if (w->trace_hi || w->trace_lo) {
                            hv_stores(h, "trace_hi", po_u64_to_sv(w->trace_hi));
                            hv_stores(h, "trace_lo", po_u64_to_sv(w->trace_lo));
                        }
                        av_push(out, newRV_noinc((SV *)h));
                    }
                    hv_stores(r, "rows", newRV_noinc((SV *)out));
                }
                else if (res.bucket_ns) {
                    hv_stores(r, "series", po_buckets_sv(aTHX_ &res));
                    hv_stores(r, "bucket_ns", po_u64_to_sv(res.bucket_ns));
                }
                else {
                    AV *out = newAV();
                    uint32_t i;
                    for (i = 0; i < res.ng; i++) {
                        HV *h = newHV();
                        hv_stores(h, "key",   newSVpvn(res.g[i].key, res.g[i].key_len));
                        hv_stores(h, "value", newSVnv((NV)res.g[i].value));
                        hv_stores(h, "count", po_u64_to_sv(res.g[i].count));
                        av_push(out, newRV_noinc((SV *)h));
                    }
                    hv_stores(r, "groups", newRV_noinc((SV *)out));
                }

                }   /* end of the answered case */

                /* meta is NEVER optional */
                hv_stores(meta, "scanned_rows",  po_u64_to_sv(res.scanned_rows));
                hv_stores(meta, "scanned_bytes", po_u64_to_sv(res.scanned_bytes));
                hv_stores(meta, "truncated",     newSViv(res.truncated));
                hv_stores(meta, "degraded",      newSViv(res.degraded));
                hv_stores(meta, "exact",         newSViv(res.exact));
                hv_stores(meta, "steps",         newSViv(res.steps));
                hv_stores(r, "meta", newRV_noinc((SV *)meta));

                /* THE IDS THE JOIN WILL RE-KEY ON, handed out separately from
                 * the rows because after an aggregate there are no rows. The
                 * store runs the second pass; the executor only says which
                 * traces survived its filters. */
                if (res.nex || res.ex_overflow) {
                    AV *xh = newAV(), *xl = newAV();
                    uint32_t i;
                    for (i = 0; i < res.nex; i++) {
                        av_push(xh, po_u64_to_sv(res.ex_hi[i]));
                        av_push(xl, po_u64_to_sv(res.ex_lo[i]));
                    }
                    hv_stores(r, "rekey_hi", newRV_noinc((SV *)xh));
                    hv_stores(r, "rekey_lo", newRV_noinc((SV *)xl));
                    if (res.ex_overflow)
                        hv_stores(r, "rekey_overflow", newSViv(1));
                }

                mXPUSHs(newRV_noinc((SV *)r));
            }

            po_result_free(&res);
            Safefree(rv);
            Safefree(keep);
            po_query_free(&q);
        }

# Drive the executor one step at a time, reporting the cursor after each, so
# a test can assert that it actually YIELDS rather than running to completion
# in one call.
void
poe_steps(SV *query, SV *rows, SV *step)
    PPCODE:
        {
            po_query  q;
            po_plan   plan;
            po_result res;
            po_qexec  x;
            po_row   *rv = NULL;
            SV      **keep = NULL;
            IV        nrows;
            STRLEN    qlen;
            const char *qp = SvPV(query, qlen);
            po_u64    sb = 0;
            AV       *cursors = newAV();
            int       s;

            (void)po_sv_to_u64(aTHX_ step, &sb);
            if (!po_parse(&q, qp, (size_t)qlen)) { po_query_free(&q); croak("parse"); }
            if (!po_plan_build(&plan, &q, NULL)) { po_query_free(&q); croak("plan"); }
            nrows = poe_load_rows(aTHX_ rows, &rv, &keep);
            if (nrows < 0) { po_query_free(&q); croak("rows"); }

            po_result_init(&res);
            po_qexec_init(&x, &plan, rv, (po_u64)nrows, &res, sb, 0);
            do {
                s = po_qexec_step(&x);
                av_push(cursors, po_u64_to_sv(res.scanned_rows));
            } while (s == PO_Q_MORE);

            {
                HV *r = newHV();
                hv_stores(r, "cursors", newRV_noinc((SV *)cursors));
                hv_stores(r, "steps",   newSViv(res.steps));
                hv_stores(r, "scanned", po_u64_to_sv(res.scanned_rows));
                hv_stores(r, "rows",    newSVuv((UV)res.nrow));
                mXPUSHs(newRV_noinc((SV *)r));
            }
            po_result_free(&res);
            Safefree(rv);
            Safefree(keep);
            po_query_free(&q);
        }

# --- the cross-signal edges -------------------------------------------------
#
# NOT a general relational join. Exactly three named edges, and they are the
# three that physically exist in the data:
#
#   metric -> traces   the exemplar's trace_id
#   traces -> logs     LogRecord.trace_id
#   traces -> spans    the same trace, already contiguous
#
# A general join across three columnar stores with no shared key would need a
# planner nobody can predict and a cost model nobody can debug. Refusing it is
# the design.
void
poe_join(SV *left, SV *right, SV *edge)
    PPCODE:
        {
            AV *L, *R;
            SSize_t i, j, ln, rn;
            STRLEN elen;
            const char *e = SvPV(edge, elen);
            AV *out = newAV();
            HV *seen = newHV();

            if (!SvROK(left) || !SvROK(right)) croak("arrayrefs required");
            L = (AV *)SvRV(left); R = (AV *)SvRV(right);
            ln = av_len(L) + 1; rn = av_len(R) + 1;

            if (!(elen == 6 && memcmp(e, "traces", 6) == 0)
             && !(elen == 4 && memcmp(e, "logs", 4) == 0)
             && !(elen == 5 && memcmp(e, "spans", 5) == 0)) {
                SvREFCNT_dec((SV *)seen);
                SvREFCNT_dec((SV *)out);
                croak("unknown edge '%s': only traces, logs and spans exist", e);
            }

            /* Collect the left side's trace keys. */
            for (i = 0; i < ln; i++) {
                SV **el = av_fetch(L, i, 0);
                HV *h; SV **a, **b;
                char key[64];
                int n;
                if (!el || !SvROK(*el)) continue;
                h = (HV *)SvRV(*el);
                a = hv_fetchs(h, "trace_hi", 0);
                b = hv_fetchs(h, "trace_lo", 0);
                if (!a || !b) continue;
                n = my_snprintf(key, sizeof(key), "%s/%s",
                                SvPV_nolen(*a), SvPV_nolen(*b));
                hv_store(seen, key, n, newSViv(1), 0);
            }

            for (j = 0; j < rn; j++) {
                SV **el = av_fetch(R, j, 0);
                HV *h; SV **a, **b;
                char key[64];
                int n;
                if (!el || !SvROK(*el)) continue;
                h = (HV *)SvRV(*el);
                a = hv_fetchs(h, "trace_hi", 0);
                b = hv_fetchs(h, "trace_lo", 0);
                if (!a || !b) continue;
                n = my_snprintf(key, sizeof(key), "%s/%s",
                                SvPV_nolen(*a), SvPV_nolen(*b));
                if (hv_exists(seen, key, n)) {
                    SvREFCNT_inc(*el);
                    av_push(out, *el);
                }
            }
            SvREFCNT_dec((SV *)seen);
            mXPUSHs(newRV_noinc((SV *)out));
        }
