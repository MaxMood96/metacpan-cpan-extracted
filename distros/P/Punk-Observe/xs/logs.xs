MODULE = Punk::Observe   PACKAGE = Punk::Observe::Log   PREFIX = pol_

# --- the bloom filter -------------------------------------------------------

# Build a filter over a corpus, then answer a list of queries. Returns which
# queries the filter says are POSSIBLE - the caller compares that against
# which are actually present, which is how the false-negative assertion is
# made.
void
pol_bloom_probe(SV *corpus, SV *queries)
    PPCODE:
        {
            po_bloom b;
            po_tri_count *tc;
            STRLEN clen;
            const char *cp;
            AV *qs;
            SSize_t i, n;
            AV *out = newAV();

            cp = SvPV(corpus, clen);
            if (!SvROK(queries)) croak("queries must be an arrayref");
            qs = (AV *)SvRV(queries);
            n = av_len(qs) + 1;

            tc = (po_tri_count *)calloc(1, sizeof(po_tri_count));
            if (!tc) croak("oom");
            po_trigrams(cp, (size_t)clen, po_tri_count_cb, tc);
            if (!po_bloom_init(&b, tc->n)) { free(tc); croak("oom"); }
            po_bloom_add_text(&b, cp, (size_t)clen);

            for (i = 0; i < n; i++) {
                SV **q = av_fetch(qs, i, 0);
                STRLEN ql; const char *qp;
                if (!q) { av_push(out, newSViv(0)); continue; }
                qp = SvPV(*q, ql);
                av_push(out, newSViv(
                    po_bloom_may_contain(b.bits, b.mask, qp, (size_t)ql) ? 1 : 0));
            }
            {
                HV *res = newHV();
                hv_stores(res, "possible", newRV_noinc((SV *)out));
                hv_stores(res, "bits",     newSVuv((UV)b.nbits));
                hv_stores(res, "distinct", newSVuv((UV)tc->n));
                hv_stores(res, "added",    newSVuv((UV)b.added));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            free(tc);
            po_bloom_free(&b);
        }

# Is a query long enough for the filter to say anything? A query under three
# bytes has no trigrams, so pruning on it would wrongly exclude every block.
int
pol_query_usable(SV *q)
    CODE:
        {
            STRLEN l; const char *p = SvPV(q, l);
            (void)p;
            RETVAL = po_bloom_query_usable((size_t)l);
        }
    OUTPUT:
        RETVAL

# The exact, case-folded match that runs after the filter says "possible".
int
pol_contains(SV *hay, SV *needle)
    CODE:
        {
            STRLEN hn, nn;
            const char *h, *n;
            h = SvPV(hay, hn);
            n = SvPV(needle, nn);
            RETVAL = po_memfind(h, (size_t)hn, n, (size_t)nn) ? 1 : 0;
        }
    OUTPUT:
        RETVAL

# --- blocks -----------------------------------------------------------------

# Build a block from line specs, seal it, inflate it, and read the lines back.
# The whole round trip in one call so a test asserts what came out equals what
# went in rather than trusting an intermediate.
void
pol_block_roundtrip(SV *lines, SV *stream)
    PPCODE:
        {
            po_block_w b;
            AV *av;
            SSize_t i, n;
            char *comp = NULL;
            size_t clen = 0;
            po_u64 st = 0;
            AV *out = newAV();

            (void)po_sv_to_u64(aTHX_ stream, &st);
            if (!SvROK(lines)) croak("lines must be an arrayref");
            av = (AV *)SvRV(lines);
            n = av_len(av) + 1;

            if (!po_block_w_init(&b, st)) croak("oom");

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *h; SV **f;
                po_u64 t = 0, tr_hi = 0, tr_lo = 0, span = 0;
                UV sev = 0;
                const char *body = ""; STRLEN blen = 0;
                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                if ((f = hv_fetchs(h, "t", 0)))        (void)po_sv_to_u64(aTHX_ *f, &t);
                if ((f = hv_fetchs(h, "severity", 0))) sev = SvUV(*f);
                if ((f = hv_fetchs(h, "body", 0)))     body = SvPV(*f, blen);
                if ((f = hv_fetchs(h, "trace_hi", 0))) (void)po_sv_to_u64(aTHX_ *f, &tr_hi);
                if ((f = hv_fetchs(h, "trace_lo", 0))) (void)po_sv_to_u64(aTHX_ *f, &tr_lo);
                if ((f = hv_fetchs(h, "span_id", 0)))  (void)po_sv_to_u64(aTHX_ *f, &span);
                po_block_add(&b, t, (uint16_t)sev, body, (size_t)blen,
                             tr_hi, tr_lo, span);
            }

            if (!po_block_seal(&b, &comp, &clen)) {
                po_block_w_free(&b);
                croak("seal failed");
            }

            {
                char *raw = NULL;
                if (po_block_inflate(&b.h, comp, clen, &raw)) {
                    po_line_r r;
                    po_line ln;
                    po_line_r_init(&r, &b.h, raw);
                    while (po_line_next(&r, &ln)) {
                        HV *h = newHV();
                        hv_stores(h, "t",        po_u64_to_sv(ln.t));
                        hv_stores(h, "severity", newSVuv((UV)ln.severity));
                        hv_stores(h, "body",     newSVpvn(ln.body, ln.body_len));
                        hv_stores(h, "trace_hi", po_u64_to_sv(ln.trace_hi));
                        hv_stores(h, "trace_lo", po_u64_to_sv(ln.trace_lo));
                        hv_stores(h, "span_id",  po_u64_to_sv(ln.span_id));
                        av_push(out, newRV_noinc((SV *)h));
                    }
                    free(raw);
                }
            }

            {
                HV *res = newHV();
                hv_stores(res, "lines",    newRV_noinc((SV *)out));
                hv_stores(res, "raw_len",  newSVuv((UV)b.h.raw_len));
                hv_stores(res, "comp_len", newSVuv((UV)b.h.comp_len));
                hv_stores(res, "count",    newSVuv((UV)b.h.lines));
                hv_stores(res, "stored",   newSViv(b.h.flags & PO_BLK_STORED ? 1 : 0));
                hv_stores(res, "t_min",    po_u64_to_sv(b.h.t_min));
                hv_stores(res, "t_max",    po_u64_to_sv(b.h.t_max));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            free(comp);
            po_block_w_free(&b);
        }

# Corrupt a byte of the compressed bytes and confirm the CRC catches it.
int
pol_block_corrupt_detected(SV *lines, SV *at)
    CODE:
        {
            po_block_w b;
            AV *av;
            SSize_t i, n;
            char *comp = NULL;
            size_t clen = 0;
            char *raw = NULL;
            IV pos = SvIV(at);

            if (!SvROK(lines)) croak("arrayref required");
            av = (AV *)SvRV(lines);
            n = av_len(av) + 1;
            if (!po_block_w_init(&b, 1)) croak("oom");
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                STRLEN bl; const char *body;
                if (!e) continue;
                body = SvPV(*e, bl);
                po_block_add(&b, (po_u64)(1000 + i), 9, body, (size_t)bl, 0, 0, 0);
            }
            if (!po_block_seal(&b, &comp, &clen)) { po_block_w_free(&b); croak("seal"); }

            if (pos >= 0 && (size_t)pos < clen)
                comp[pos] = (char)(comp[pos] ^ 0xFF);

            /* 1 means the corruption was DETECTED (inflate or CRC refused). */
            RETVAL = po_block_inflate(&b.h, comp, clen, &raw) ? 0 : 1;
            free(raw);
            free(comp);
            po_block_w_free(&b);
        }
    OUTPUT:
        RETVAL

# --- the label allowlist ----------------------------------------------------

int
pol_is_label(SV *key)
    CODE:
        {
            po_labelset s;
            STRLEN l; const char *p;
            po_labelset_default(&s);
            p = SvPV(key, l);
            RETVAL = po_is_label(&s, p, (size_t)l);
        }
    OUTPUT:
        RETVAL

void
pol_default_labels(...)
    PPCODE:
        {
            po_labelset s;
            int i;
            po_labelset_default(&s);
            for (i = 0; i < s.n; i++)
                mXPUSHp(s.key[i], s.klen[i]);
        }

# --- pruning ----------------------------------------------------------------

# Given block descriptions and a query, report which survive each test. The
# stats are the assertion that the pruning actually prunes.
void
pol_prune(SV *blocks, SV *from, SV *to, SV *query)
    PPCODE:
        {
            AV *av;
            SSize_t i, n;
            po_u64 f = 0, t = 0;
            STRLEN qlen;
            const char *q;
            po_prune_stats st;
            AV *kept = newAV();

            memset(&st, 0, sizeof(st));
            (void)po_sv_to_u64(aTHX_ from, &f);
            (void)po_sv_to_u64(aTHX_ to, &t);
            q = SvPV(query, qlen);
            if (!SvROK(blocks)) croak("arrayref required");
            av = (AV *)SvRV(blocks);
            n = av_len(av) + 1;

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *h; SV **fl;
                po_block_w b;
                po_dir_ent ent;
                char *comp = NULL; size_t clen = 0;
                po_u64 bt_min = 0, bt_max = 0;
                const char *text = ""; STRLEN tlen = 0;

                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                if ((fl = hv_fetchs(h, "t_min", 0))) (void)po_sv_to_u64(aTHX_ *fl, &bt_min);
                if ((fl = hv_fetchs(h, "t_max", 0))) (void)po_sv_to_u64(aTHX_ *fl, &bt_max);
                if ((fl = hv_fetchs(h, "text", 0)))  text = SvPV(*fl, tlen);

                if (!po_block_w_init(&b, 1)) croak("oom");
                po_block_add(&b, bt_min, 9, text, (size_t)tlen, 0, 0, 0);
                if (bt_max > bt_min)
                    po_block_add(&b, bt_max, 9, "", 0, 0, 0, 0);
                if (!po_block_seal(&b, &comp, &clen)) { po_block_w_free(&b); croak("seal"); }

                memset(&ent, 0, sizeof(ent));
                ent.h = b.h;
                if (po_block_candidate(&ent, 0, 0, f, t,
                                       b.bloom.bits, q, (size_t)qlen, &st))
                    av_push(kept, newSViv((IV)i));

                free(comp);
                po_block_w_free(&b);
            }
            {
                HV *res = newHV();
                hv_stores(res, "kept",           newRV_noinc((SV *)kept));
                hv_stores(res, "considered",     newSVuv((UV)st.considered));
                hv_stores(res, "skipped_time",   newSVuv((UV)st.skipped_time));
                hv_stores(res, "skipped_bloom",  newSVuv((UV)st.skipped_bloom));
                hv_stores(res, "candidates",     newSVuv((UV)st.candidates));
                mXPUSHs(newRV_noinc((SV *)res));
            }
        }

int
pol_have_zlib(...)
    CODE:
#ifdef PO_HAVE_ZLIB
        RETVAL = 1;
#else
        RETVAL = 0;
#endif
    OUTPUT:
        RETVAL
