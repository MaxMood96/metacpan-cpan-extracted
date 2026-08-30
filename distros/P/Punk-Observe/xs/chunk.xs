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

        for (ai = 2; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "from") && SvOK(v)) have_from = po_sv_to_u64(aTHX_ v, &from);
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
            RETVAL = poc_plain(aTHX_ store, q, from, to);
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
            RETVAL = poc_plain(aTHX_ store, q, from, to);
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
                RETVAL = poc_plain(aTHX_ store, q, from, to);
                goto done;
            }

            blob = poc_cache_get(aTHX_ cache, key);
            if (blob) {
                STRLEN bl = 0;
                const unsigned char *bp = (const unsigned char *)SvPV(blob, bl);
                got = po_chunk_decode(&acc, bp, (size_t)bl);
                SvREFCNT_dec(blob);
            }

            if (!got) {
                /* A MISS, A BAD BLOB AND A CACHE THAT THREW ARE ONE CASE:
                 * compute the chunk. A cache is an optimisation, so every
                 * way it can fail has to come out as a slower answer rather
                 * than a broken panel. */
                po_cres one;
                SV *r = poc_plain(aTHX_ store, q, s, po_ns_sub(end, 1));
                po_cres_init(&one);
                one.bucket_ns = b;
                if (poc_ingest(aTHX_ &one, r)) {
                    size_t need = po_chunk_size(&one);
                    unsigned char *buf = (unsigned char *)malloc(need);
                    if (buf) {
                        size_t n = po_chunk_encode(&one, buf);
                        poc_cache_set(aTHX_ cache, key, buf, n, ttl);
                        free(buf);
                    }
                    (void)poc_ingest(aTHX_ &acc, r);
                }
                po_cres_free(&one);
                if (r) SvREFCNT_dec(r);
            }
            SvREFCNT_dec(key);
            chunks++;
        }

        {   /* The live tail, always computed: it is the part still moving. */
            SV *r = poc_plain(aTHX_ store, q, stable_end, to);
            (void)poc_ingest(aTHX_ &acc, r);
            if (r) SvREFCNT_dec(r);
        }

        po_cres_sort(&acc);
        RETVAL = poc_emit(aTHX_ &acc, po_chunk_floor(from, b), chunks);
        po_cres_free(&acc);

    done: ;
    }
    OUTPUT:
        RETVAL
