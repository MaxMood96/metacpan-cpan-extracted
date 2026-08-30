MODULE = Punk::Observe   PACKAGE = Punk::Observe::Query   PREFIX = poq_

# Parse a query and return a canonical dump of the AST, so a test reads as a
# table rather than as a walk over an opaque structure.
# THE LANGUAGE, DESCRIBED BY THE CODE THAT IMPLEMENTS IT.
#
# The help page is generated from this rather than written out, because a
# reference maintained by hand is a reference that goes wrong - and this one
# would be wrong about a language whose entire surface is four static tables
# a few lines apart. Every list here is read from the table the parser itself
# consults, so a column added to PO_COLUMNS appears on the page without
# anybody having to remember.
void
poq_grammar()
    PPCODE:
    {
        HV *out = newHV();
        int i;

        {   /* Sources. The canonical spelling, and the alias that also works
             * - accepted, and not what the page should teach. */
            AV *src = newAV();
            static const char *const NAME[]  = { "metric", "log", "trace", "spans" };
            static const char *const FORM[]  = { "metric NAME", "log", "trace", "spans" };
            static const char *const ALIAS[] = { NULL, "logs", "traces", "span" };
            for (i = 0; i < 4; i++) {
                HV *h = newHV();
                hv_stores(h, "name", newSVpv(NAME[i], 0));
                hv_stores(h, "form", newSVpv(FORM[i], 0));
                if (ALIAS[i]) hv_stores(h, "alias", newSVpv(ALIAS[i], 0));
                av_push(src, newRV_noinc((SV *)h));
            }
            hv_stores(out, "sources", newRV_noinc((SV *)src));
        }

        {   /* Columns per source, straight off the table the parser
             * validates against. */
            HV *cols = newHV();
            static const char *const K[] = { "metric", "log", "trace", "spans" };
            static const int BIT[] = { PO_C_METRIC, PO_C_LOG, PO_C_TRACE, PO_C_SPAN };
            int sx;
            for (sx = 0; sx < 4; sx++) {
                AV *list = newAV();
                for (i = 0; PO_COLUMNS[i].name; i++)
                    if (PO_COLUMNS[i].sources & BIT[sx])
                        av_push(list, newSVpv(PO_COLUMNS[i].name, 0));
                (void)hv_store(cols, K[sx], (I32)strlen(K[sx]),
                               newRV_noinc((SV *)list), 0);
            }
            hv_stores(out, "columns", newRV_noinc((SV *)cols));
        }

        {   /* Aggregates. Every one takes NO argument and reads a column
             * chosen by the row kind, which is the thing nothing documents. */
            AV *agg = newAV();
            static const char *const A[] = { "count", "sum", "avg", "min",
                                             "max", "p50", "p90", "p95",
                                             "p99", "distinct", NULL };
            for (i = 0; A[i]; i++) av_push(agg, newSVpv(A[i], 0));
            hv_stores(out, "aggregates", newRV_noinc((SV *)agg));
        }

        {   /* Severity names, with the numbers they resolve to at parse
             * time, from po_severity_value itself. */
            AV *sev = newAV();
            static const char *const N[] = { "trace", "debug", "info", "warn",
                                             "warning", "error", "fatal", NULL };
            for (i = 0; N[i]; i++) {
                HV *h = newHV();
                hv_stores(h, "name",  newSVpv(N[i], 0));
                {   /* It answers through an out-parameter and returns
                     * whether the word was one, which is the shape the
                     * parser needs and not the shape a list does. */
                    po_u64 v = 0;
                    (void)po_severity_value(N[i], strlen(N[i]), &v);
                    hv_stores(h, "value", newSViv((IV)v));
                }
                av_push(sev, newRV_noinc((SV *)h));
            }
            hv_stores(out, "severities", newRV_noinc((SV *)sev));
        }

        {   /* Duration units, from po_dur_unit, so the page cannot offer one
             * the lexer does not take. */
            AV *un = newAV();
            static const char *const U[] = { "ns", "us", "ms", "s", "m", "h",
                                             "d", "w", "y", NULL };
            for (i = 0; U[i]; i++) {
                HV *h = newHV();
                hv_stores(h, "name", newSVpv(U[i], 0));
                hv_stores(h, "ns",
                          po_u64_to_sv(po_dur_unit(U[i], strlen(U[i]))));
                av_push(un, newRV_noinc((SV *)h));
            }
            hv_stores(out, "units", newRV_noinc((SV *)un));
        }

        {
            AV *ops = newAV();
            static const char *const O[] = { "=", "==", "!=", "<", "<=", ">",
                                             ">=", "=~", "!~", NULL };
            for (i = 0; O[i]; i++) av_push(ops, newSVpv(O[i], 0));
            hv_stores(out, "operators", newRV_noinc((SV *)ops));
        }

        mXPUSHs(newRV_noinc((SV *)out));
        XSRETURN(1);
    }

SV *
poq_parse(SV *src)
    CODE:
        {
            po_query q;
            STRLEN len;
            const char *p;
            HV *res = newHV();

            p = SvPV(src, len);          /* own line: sibling-arg order is UB */
            po_parse(&q, p, (size_t)len);

            hv_stores(res, "ok", newSViv(q.failed ? 0 : 1));
            if (q.failed) {
                hv_stores(res, "error",  newSVpv(q.err, 0));
                hv_stores(res, "offset", newSVuv((UV)q.err_off));
            }
            else {
                AV *stages = newAV();
                po_stage *s;

                hv_stores(res, "source", newSVpv(po_src_name(q.source), 0));
                if (q.name)
                    hv_stores(res, "name", newSVpvn(q.name, q.name_len));
                if (q.selector)
                    hv_stores(res, "selector", poq_expr_sv(aTHX_ q.selector));

                for (s = q.stages; s; s = s->next) {
                    HV *h = newHV();
                    const char *k = "?";
                    switch (s->kind) {
                        case PO_ST_WHERE:     k = "where";     break;
                        case PO_ST_SEARCH:    k = "search";    break;
                        case PO_ST_BY:        k = "by";        break;
                        case PO_ST_AGG:       k = "agg";       break;
                        case PO_ST_RATE:      k = "rate";      break;
                        case PO_ST_TOPN:      k = "top";       break;
                        /* `bucket` HAD NO CASE, so Query::parse reported its
                         * kind as "?" - the stage parsed and executed
                         * correctly and was the only one the AST could not
                         * name. It is also missing from Query.pm's own list
                         * of kinds, which is where it went unnoticed. */
                        case PO_ST_BUCKET:    k = "bucket";    break;
                        case PO_ST_SLOWEST:   k = "slowest";   break;
                        case PO_ST_LIMIT:     k = "limit";     break;
                        case PO_ST_SORT:      k = "sort";      break;
                        case PO_ST_EXEMPLARS: k = "exemplars"; break;
                        case PO_ST_TRACES:    k = "traces";    break;
                        case PO_ST_LOGS:      k = "logs";      break;
                        case PO_ST_SPANS:     k = "spans";     break;
                        default: break;
                    }
                    hv_stores(h, "kind", newSVpv(k, 0));
                    if (s->expr) hv_stores(h, "expr", poq_expr_sv(aTHX_ s->expr));
                    if (s->str)  hv_stores(h, "text", newSVpvn(s->str, s->str_len));
                    if (s->agg)  hv_stores(h, "agg", newSVpv(poq_agg_name(s->agg), 0));
                    if (s->dur)  hv_stores(h, "window", po_u64_to_sv(s->dur));
                    if (s->num)  hv_stores(h, "n", po_u64_to_sv(s->num));
                    if (s->desc) hv_stores(h, "desc", newSViv(1));
                    if (s->nfields) {
                        AV *f = newAV();
                        int i;
                        for (i = 0; i < s->nfields; i++)
                            av_push(f, newSVpvn(s->fields[i], s->field_lens[i]));
                        hv_stores(h, "fields", newRV_noinc((SV *)f));
                    }
                    av_push(stages, newRV_noinc((SV *)h));
                }
                hv_stores(res, "stages", newRV_noinc((SV *)stages));
                if (q.viz)
                    hv_stores(res, "viz", newSVpvn(q.viz, q.viz_len));
            }
            po_query_free(&q);
            RETVAL = newRV_noinc((SV *)res);
        }
    OUTPUT:
        RETVAL

# Parse and immediately free, so a leak check has something to run many times.
UV
poq_parse_free_cycles(SV *src, SV *n)
    CODE:
        {
            STRLEN len;
            const char *p;
            IV i, cycles = SvIV(n);
            UV ok = 0;
            p = SvPV(src, len);
            for (i = 0; i < cycles; i++) {
                po_query q;
                if (po_parse(&q, p, (size_t)len)) ok++;
                po_query_free(&q);
            }
            RETVAL = ok;
        }
    OUTPUT:
        RETVAL
