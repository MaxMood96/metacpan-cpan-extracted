MODULE = Punk::Observe   PACKAGE = Punk::Observe::Cache   PREFIX = poc_

# The bucket width a query asks for, or undef when it must be run whole.
SV *
poc_bucket_ns(SV *q)
    CODE:
    {
        po_query pq;
        STRLEN ql = 0;
        const char *qp = SvOK(q) ? SvPV(q, ql) : "";
        po_u64 b = 0;
        if (ql && po_parse(&pq, qp, (size_t)ql)) {
            b = po_chunk_bucket_ns(&pq);
            po_query_free(&pq);
        }
        RETVAL = b ? po_u64_to_sv(b) : newSV(0);
    }
    OUTPUT:
        RETVAL

SV *
poc_chunk_ns(SV *b)
    CODE:
    {
        po_u64 x = 0;
        (void)po_sv_to_u64(aTHX_ b, &x);
        RETVAL = po_u64_to_sv(po_chunk_width(x));
    }
    OUTPUT:
        RETVAL

# query($store, $q, from => ..., to => ..., cache => ..., ...)
#
# The same contract `$store->query` has, with the settled part of the window
# served from the cache. Falls back to one plain query whenever splitting
# would not be sound - no cache, no bucket, a whole-window stage, a window
# with no settled part, or a key too long to store - so a caller never has to
# ask which it is getting.
SV *
poc_query(SV *store, SV *q, ...)
    CODE:
    {
        po_query pq;
        STRLEN ql = 0;
        const char *qp = SvOK(q) ? SvPV(q, ql) : "";
        SV *cache = NULL;
        po_u64 from = 0, to = 0, now = 0, lag = PO_CHUNK_LAG_NS;
        int have_from = 0, have_to = 0, have_now = 0;
        IV ttl = 3600, ai;
        po_u64 b = 0, width, settled, stable_end, first, s;
        po_cres acc;
        int chunks = 0, parsed = 0;
        SV *tenant = NULL;
        SV **extra = NULL;
        int nextra = 0;

        /* The caller's own options, kept aside to travel with every chunk.
         * Matched on the key alone rather than on the key having a usable
         * value, or `from => undef` would be forwarded as an option and
         * quietly overrule the window this file is splitting. */
        Newx(extra, items > 2 ? items : 2, SV *);
        for (ai = 2; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if (!poc_consumed(k)) {
                extra[nextra++] = ST(ai);
                extra[nextra++] = v;
            }
            else if (strEQ(k, "from") && SvOK(v)) have_from = po_sv_to_u64(aTHX_ v, &from);
            else if (strEQ(k, "to")   && SvOK(v)) have_to   = po_sv_to_u64(aTHX_ v, &to);
            else if (strEQ(k, "now")  && SvOK(v)) have_now  = po_sv_to_u64(aTHX_ v, &now);
            else if (strEQ(k, "lag_ns") && SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &lag);
            else if (strEQ(k, "ttl")  && SvOK(v)) ttl = SvIV(v);
            else if (strEQ(k, "cache")) cache = SvTRUE(v) ? v : NULL;
            else if (strEQ(k, "tenant") && SvOK(v)) tenant = v;
        }

        if (ql && po_parse(&pq, qp, (size_t)ql)) {
            parsed = 1;
            b = po_chunk_bucket_ns(&pq);
            po_query_free(&pq);
        }
        (void)parsed;

        if (!cache || !have_from || !have_to || !b) {
            RETVAL = poc_plain(aTHX_ store, q, from, to, extra, nextra);
            goto done;
        }

        width = po_chunk_width(b);
        if (!have_now) now = po_now_ns();
        settled = po_ns_sub(now, lag);
        if (settled > to) settled = to;
        stable_end = po_chunk_floor(settled, width);
        first      = po_chunk_floor(from, width);

        /* Nothing has settled inside the window: one plain query is both the
         * correct answer and the cheaper one. */
        if (stable_end <= first) {
            RETVAL = poc_plain(aTHX_ store, q, from, to, extra, nextra);
            goto done;
        }

        po_cres_init(&acc);
        acc.bucket_ns = b;

        for (s = first; s < stable_end; s += width) {
            po_u64 end = s + width;
            SV *key = poc_key(aTHX_ store, q, s, width, tenant);
            SV *blob = NULL;
            int got = 0;

            if (!key) {                 /* too long to key on: run it whole */
                po_cres_free(&acc);
                RETVAL = poc_plain(aTHX_ store, q, from, to, extra, nextra);
                goto done;
            }

            blob = poc_cache_get(aTHX_ cache, key);
            if (blob) {
                STRLEN bl = 0;
                const unsigned char *bp = (const unsigned char *)SvPV(blob, bl);
                got = po_chunk_decode(&acc, bp, (size_t)bl);
                SvREFCNT_dec(blob);
                /* Present and unreadable. To `compute` that is a hit, so the
                 * entry has to go or it stands in the way of its own
                 * replacement for the whole of its life. */
                if (!got) poc_cache_del(aTHX_ cache, key);
            }

            if (!got) {
                /* A MISS, A BAD BLOB AND A CACHE THAT THREW ARE ONE CASE:
                 * compute the chunk, once across the pool where the cache
                 * offers that. A cache is an optimisation, so every way it
                 * can fail has to come out as a slower answer rather than a
                 * broken panel. */
                SV *filled = poc_fill(aTHX_ cache, key, ttl, store, q,
                                      s, po_ns_sub(end, 1), b, extra, nextra);
                if (filled) {
                    STRLEN fl = 0;
                    const unsigned char *fp =
                        (const unsigned char *)SvPV(filled, fl);
                    got = po_chunk_decode(&acc, fp, (size_t)fl);
                    SvREFCNT_dec(filled);
                }
            }

            if (!got) {
                /* Nothing worth storing came back - the scan died, or it
                 * truncated and `_blob` refused to hand a short answer to the
                 * cache. Either way this call still owes an answer, so the
                 * chunk is computed plainly and kept out of the cache. */
                SV *r = poc_plain(aTHX_ store, q, s, po_ns_sub(end, 1),
                                  extra, nextra);
                (void)poc_ingest(aTHX_ &acc, r);
                if (r) SvREFCNT_dec(r);
            }
            SvREFCNT_dec(key);
            chunks++;
        }

        {   /* The live tail, always computed: it is the part still moving. */
            SV *r = poc_plain(aTHX_ store, q, stable_end, to, extra, nextra);
            (void)poc_ingest(aTHX_ &acc, r);
            if (r) SvREFCNT_dec(r);
        }

        po_cres_sort(&acc);
        RETVAL = poc_emit(aTHX_ &acc, po_chunk_floor(from, b), chunks);
        po_cres_free(&acc);

    done:
        Safefree(extra);
    }
    OUTPUT:
        RETVAL

# warm($store, $q, from => ..., to => ..., cache => ..., ...)
#
# THE SETTLED CHUNKS, COMPUTED WHERE NOBODY IS WAITING. `query` fills the
# cache as a side effect of answering, which means the first person to open a
# dashboard after a restart pays for the whole window. This is the same walk
# with the answer thrown away: no live tail, no merge, nothing built that a
# chart would read - only the entries, so that the request that follows finds
# them already there.
#
# NEWEST FIRST, because that is the end of the range people look at, and a pass
# that runs out of budget should have spent it on the hours somebody is about
# to ask for.
#
# A BUDGET AND A DEADLINE, BOTH. A pass that can run for ever is a pass that
# can hold a queue worker for ever, and the work here is unbounded by nature -
# one chunk of a busy store is a real scan. Neither can interrupt a scan
# already started, so both are checked before one begins.
SV *
poc_warm(SV *store, SV *q, ...)
    CODE:
    {
        po_query pq;
        STRLEN ql = 0;
        const char *qp = SvOK(q) ? SvPV(q, ql) : "";
        SV *cache = NULL, *tenant = NULL;
        po_u64 from = 0, to = 0, now = 0, lag = PO_CHUNK_LAG_NS, refresh = 0;
        int have_from = 0, have_to = 0, have_now = 0;
        IV ttl = 3600, ai, budget = 0;
        NV deadline = 0;
        po_u64 b = 0, width = 0, settled, stable_end, first, s, refresh_edge;
        po_u64 t0 = po_tick_ns(), limit_ns = 0;
        SV **extra = NULL;
        int nextra = 0;
        IV n_chunks = 0, n_computed = 0, n_hits = 0, n_failed = 0;
        IV n_unstorable = 0;
        const char *stopped = "";
        HV *out = newHV();

        Newx(extra, items > 2 ? items : 2, SV *);
        for (ai = 2; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if (!poc_consumed(k)) {
                extra[nextra++] = ST(ai);
                extra[nextra++] = v;
            }
            else if (strEQ(k, "from") && SvOK(v)) have_from = po_sv_to_u64(aTHX_ v, &from);
            else if (strEQ(k, "to")   && SvOK(v)) have_to   = po_sv_to_u64(aTHX_ v, &to);
            else if (strEQ(k, "now")  && SvOK(v)) have_now  = po_sv_to_u64(aTHX_ v, &now);
            else if (strEQ(k, "lag_ns") && SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &lag);
            else if (strEQ(k, "refresh_ns") && SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &refresh);
            else if (strEQ(k, "ttl")  && SvOK(v)) ttl = SvIV(v);
            else if (strEQ(k, "budget") && SvOK(v)) budget = SvIV(v);
            else if (strEQ(k, "deadline") && SvOK(v)) deadline = SvNV(v);
            else if (strEQ(k, "cache")) cache = SvTRUE(v) ? v : NULL;
            else if (strEQ(k, "tenant") && SvOK(v)) tenant = v;
        }

        if (ql && po_parse(&pq, qp, (size_t)ql)) {
            b = po_chunk_bucket_ns(&pq);
            po_query_free(&pq);
        }

        /* THE REFUSALS ARE NAMED. A warmer walks queries it was handed rather
         * than ones it chose, so "nothing was warmed" has to say which of the
         * several harmless reasons it was. */
        if (!cache)                 { stopped = "no cache";   goto emit; }
        if (!have_from || !have_to) { stopped = "no window";  goto emit; }
        if (!b)                     { stopped = "unbucketed"; goto emit; }

        width = po_chunk_width(b);
        if (!have_now) now = po_now_ns();
        settled = po_ns_sub(now, lag);
        if (settled > to) settled = to;
        stable_end   = po_chunk_floor(settled, width);
        first        = po_chunk_floor(from, width);
        refresh_edge = po_ns_sub(settled, refresh);
        if (deadline > 0) limit_ns = (po_u64)(deadline * 1000000000.0);

        if (stable_end <= first) { stopped = "nothing settled"; goto emit; }

        for (s = stable_end; s > first; ) {
            po_u64 end;
            SV *key;
            int force;

            s -= width;
            end = s + width;
            /* Telemetry arrives late, so the newest settled chunks are the
             * ones that can still have gained records since they were last
             * computed. They are recomputed rather than left; everything
             * older is filled only where it is missing. */
            force = refresh && end > refresh_edge;

            key = poc_key(aTHX_ store, q, s, width, tenant);
            if (!key) { stopped = "key too long"; break; }
            n_chunks++;

            if (!force) {
                SV *blob = poc_cache_get(aTHX_ cache, key);
                if (blob) {
                    STRLEN bl = 0;
                    const unsigned char *bp =
                        (const unsigned char *)SvPV(blob, bl);
                    int usable = po_chunk_valid(bp, (size_t)bl);
                    SvREFCNT_dec(blob);
                    if (usable) {
                        SvREFCNT_dec(key);
                        n_hits++;
                        continue;
                    }
                }
            }

            /* Checked here, before a scan that cannot be interrupted once it
             * has begun, and BEFORE THE ENTRY IS TOUCHED. Deleting first and
             * stopping second would leave the chunk colder than this pass
             * found it, and a warmer that keeps running out of budget on the
             * same chunk would keep emptying it. A pass that stops says so,
             * and the next one resumes by walking the same way and finding
             * what this one left. */
            if (budget && n_computed >= budget) {
                SvREFCNT_dec(key);
                stopped = "budget";
                break;
            }
            if (limit_ns && po_duration(t0, po_tick_ns()) >= limit_ns) {
                SvREFCNT_dec(key);
                stopped = "deadline";
                break;
            }

            /* Whatever is there is either stale by policy or unreadable, and
             * `compute` runs its code on a miss - so it has to go, or it
             * stands in the way of its own replacement. */
            poc_cache_del(aTHX_ cache, key);

            {
                SV *filled = poc_fill(aTHX_ cache, key, ttl, store, q,
                                      s, po_ns_sub(end, 1), b, extra, nextra);
                if (!filled) n_failed++;
                else {
                    SV *back;
                    SvREFCNT_dec(filled);
                    n_computed++;
                    /* DID IT LAND. A value past the cache's own budget is
                     * refused rather than stored, and a chunk quietly
                     * recomputed on every pass for ever is worth a number
                     * somebody can see rather than a cost nobody can find. */
                    back = poc_cache_get(aTHX_ cache, key);
                    if (back) SvREFCNT_dec(back);
                    else n_unstorable++;
                }
            }
            SvREFCNT_dec(key);
        }

    emit:
        hv_stores(out, "chunks",     newSViv(n_chunks));
        hv_stores(out, "computed",   newSViv(n_computed));
        hv_stores(out, "hits",       newSViv(n_hits));
        hv_stores(out, "failed",     newSViv(n_failed));
        hv_stores(out, "unstorable", newSViv(n_unstorable));
        hv_stores(out, "stopped",    newSVpv(stopped, 0));
        hv_stores(out, "bucket_ns",  po_u64_to_sv(b));
        hv_stores(out, "chunk_ns",   po_u64_to_sv(width));
        Safefree(extra);
        RETVAL = newRV_noinc((SV *)out);
    }
    OUTPUT:
        RETVAL
