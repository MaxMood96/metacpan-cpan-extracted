MODULE = Punk::Observe   PACKAGE = Punk::Observe::Query   PREFIX = poq_

# Parse a query and return a canonical dump of the AST, so a test reads as a
# table rather than as a walk over an opaque structure.
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
