MODULE = Punk::Observe   PACKAGE = Punk::Observe::Ingest   PREFIX = poi_

# --- the engine -------------------------------------------------------------

# The object is a pointer, not a hash: `call` reads five fields per request and
# a hash lookup for each is the sort of cost that only looks small.
SV *
poi_new(SV *class, ...)
    CODE:
        {
            po_ingest *ing;
            SV *sv;
            int i;

            if ((items - 1) % 2) croak("Punk::Observe::Ingest->new: odd option");
            ing = po_ingest_new();
            if (!ing) croak("out of memory");

            {   /* $MAX_RATIO stays the documented override point. */
                SV *mr = get_sv("Punk::Observe::Ingest::MAX_RATIO", 0);
                po_u64 v = 0;
                if (mr && SvOK(mr) && po_sv_to_u64(aTHX_ mr, &v) && v)
                    ing->max_ratio = v;
            }

            for (i = 1; i + 1 < items; i += 2) {
                STRLEN kl;
                const char *k;
                SV *v = ST(i + 1);
                po_u64 n = 0;

                k = SvPV(ST(i), kl);

                if (kl == 8 && memcmp(k, "max_body", 8) == 0) {
                    if (po_sv_to_u64(aTHX_ v, &n) && n)
                        ing->max_body = n > PO_BODY_MAX ? PO_BODY_MAX : n;
                }
                else if (kl == 9 && memcmp(k, "max_ratio", 9) == 0) {
                    if (po_sv_to_u64(aTHX_ v, &n) && n) ing->max_ratio = n;
                }
                else if (kl == 11 && memcmp(k, "max_records", 11) == 0) {
                    if (po_sv_to_u64(aTHX_ v, &n)) ing->max_records = n;
                }
                else if (kl == 4 && memcmp(k, "auth", 4) == 0) {
                    if (SvOK(v)) ing->auth = newSVsv(v);
                }
                else if (kl == 8 && memcmp(k, "on_batch", 8) == 0) {
                    if (SvOK(v)) ing->on_batch = newSVsv(v);
                }
                else if (kl == 4 && memcmp(k, "grpc", 4) == 0) {
                    if (SvTRUE(v)) {
                        po_ingest_free(aTHX_ ing);
                        /* gRPC refuses at BOOT rather than at the first
                         * request. A gRPC call returns HTTP 200 even when it
                         * fails; the outcome lives entirely in the grpc-status
                         * and grpc-message TRAILERS. PSGI has no trailer
                         * channel and Hyperman's HTTP/2 path has no escape for
                         * one. An endpoint that answered 200 with no trailers
                         * would be an exporter that looks completely
                         * successful and has lost everything, which is worse
                         * than not offering gRPC at all - so this is a loud
                         * refusal at configuration time, where somebody can
                         * act on it. */
                        croak("Punk::Observe::Ingest: gRPC ingest is not available.\n"
                              "  gRPC reports failure in HTTP/2 trailers, and there is no\n"
                              "  trailer channel in PSGI or in Hyperman's HTTP/2 path. Serving\n"
                              "  it anyway would answer 200 with no grpc-status, which an\n"
                              "  exporter reads as complete success while losing every batch.\n"
                              "  Use the OTLP/HTTP endpoints on 4318 instead.\n");
                    }
                }
            }

            sv = newSViv(PTR2IV(ing));
            RETVAL = newRV_noinc(sv);
            sv_bless(RETVAL, gv_stashsv(SvROK(class) ? SvRV(class) : class, GV_ADD));
            SvREADONLY_on(sv);
        }
    OUTPUT:
        RETVAL

void
poi_DESTROY(SV *self)
    CODE:
        {
            SV *sv = SvRV(self);
            po_ingest *ing = INT2PTR(po_ingest *, SvIVX(sv));
            SvREADONLY_off(sv);
            sv_setiv(sv, 0);
            po_ingest_free(aTHX_ ing);
        }

# The PSGI application. A real CV with the engine hung off it as ext magic,
# rather than a Perl closure: the coderef IS the entry point on every request,
# and a closure would put a Perl frame and a method dispatch in front of it.
SV *
poi_to_app(SV *self)
    CODE:
        {
            CV *cv;
            (void)po_ingest_of(aTHX_ self, "to_app");
            cv = newXS(NULL, po_ingest_app_xs, __FILE__);
            if (!cv) croak("cannot create the app coderef");
            /* Who owns the reference newXS returned depends on the perl: newer
             * ones hand back an unowned anonymous CV, older ones may have
             * parked it in a glob first. Take our own only in the second case,
             * so this neither leaks a CV nor frees one twice. */
            if (CvGV(cv) && GvCV(CvGV(cv)) == cv) SvREFCNT_inc_simple_void(cv);
            sv_magicext((SV *)cv, self, PERL_MAGIC_ext, &po_app_vtbl, NULL, 0);
            RETVAL = newRV_noinc((SV *)cv);
        }
    OUTPUT:
        RETVAL

SV *
poi_call(SV *self, SV *env)
    CODE:
        RETVAL = po_ingest_call(aTHX_ po_ingest_of(aTHX_ self, "call"), env);
    OUTPUT:
        RETVAL

# --- the pieces, for the tests ----------------------------------------------

# Decode an already-parsed OTLP/JSON structure into records.
#
# The parse itself is File::Raw::JSON's, in Perl, and that is deliberate:
# otel_json.h:29-32 makes the same call about the same transport - JSON is the
# debuggable path, protobuf is the production one, and duplicating a JSON
# parser to save allocations on a path nobody benchmarks is the wrong trade.
# The WALK is C, so nothing is allocated per record.
SV *
poi_decode_json(SV *doc, SV *signal)
    CODE:
        {
            po_batch b;
            STRLEN slen;
            const char *sig;
            AV *recs;
            HV *res;
            size_t i;

            sig = SvPV(signal, slen);
            if (!po_batch_init(&b, 16)) croak("out of memory");

            if      (slen == 6 && memcmp(sig, "traces",  6) == 0)
                po_json_traces(aTHX_ doc, &b);
            else if (slen == 4 && memcmp(sig, "logs",    4) == 0)
                po_json_logs(aTHX_ doc, &b);
            else if (slen == 7 && memcmp(sig, "metrics", 7) == 0)
                po_json_metrics(aTHX_ doc, &b);
            else { po_batch_free(&b); croak("unknown signal"); }

            recs = newAV();
            if (!b.err)
                for (i = 0; i < b.n; i++)
                    av_push(recs, po_rec_hv(aTHX_ &b.rec[i], &b.arena));

            res = newHV();
            hv_stores(res, "ok",      newSViv(b.err ? 0 : 1));
            hv_stores(res, "records", newRV_noinc((SV *)recs));
            hv_stores(res, "dropped_bad_trace", newSViv((IV)b.dropped_bad_trace));
            hv_stores(res, "clamped_durations", newSViv((IV)b.clamped_durations));
            po_batch_free(&b);
            RETVAL = newRV_noinc((SV *)res);
        }
    OUTPUT:
        RETVAL

# Count records without materialising them. This is what the real ingest path
# does: decode, count, append to the WAL, reply - no SV per record anywhere.
SV *
poi_count(SV *buf, SV *signal, SV *encoding)
    CODE:
        {
            po_batch b;
            STRLEN len, slen, elen;
            const char *p, *sig, *enc;
            int ok = 0;
            HV *res;

            p   = SvPV(buf, len);
            sig = SvPV(signal, slen);
            enc = SvPV(encoding, elen);

            if (!po_batch_init(&b, 64)) croak("out of memory");

            if (elen == 8 && memcmp(enc, "protobuf", 8) == 0) {
                if      (slen == 6 && memcmp(sig, "traces",  6) == 0)
                    ok = po_otlp_traces(p, (size_t)len, &b);
                else if (slen == 4 && memcmp(sig, "logs",    4) == 0)
                    ok = po_otlp_logs(p, (size_t)len, &b);
                else if (slen == 7 && memcmp(sig, "metrics", 7) == 0)
                    ok = po_otlp_metrics(p, (size_t)len, &b);
                else { po_batch_free(&b); croak("unknown signal"); }
            }
            else { po_batch_free(&b); croak("unknown encoding"); }

            res = newHV();
            hv_stores(res, "ok",      newSViv(ok && !b.err ? 1 : 0));
            hv_stores(res, "records", po_u64_to_sv((po_u64)b.n));
            hv_stores(res, "dropped_bad_trace", newSViv((IV)b.dropped_bad_trace));
            hv_stores(res, "clamped_durations", newSViv((IV)b.clamped_durations));
            po_batch_free(&b);
            RETVAL = newRV_noinc((SV *)res);
        }
    OUTPUT:
        RETVAL

# Decode a batch and append it to the write-ahead log in ONE pass.
#
# THIS IS THE INGEST PATH. What it replaces is a round trip the store had no
# business paying for: decode to records in C, materialise an SV per record,
# hand the array to Perl, and have Perl hand it back to a second XSUB that
# rebuilt the record array and re-encoded every attribute block. Two
# allocations per attribute per record, per exported batch - and it was
# LOSSY as well as slow, because the hash in the middle only carried the
# three fields the WAL surface happened to read.
#
# Here the decoder's own record array and its arena go straight into the
# writev. Nothing is copied and no SV exists unless `want_records` asks for
# one, which is what an on_records observer does.
#
# `buf` is the wire bytes for protobuf and the already-parsed document for
# json, because the JSON parse is File::Raw::JSON's and stays in Perl.
SV *
poi_decode_append(SV *path, SV *buf, SV *signal, SV *encoding, SV *policy, SV *interval_ns, SV *want_records, ...)
    CODE:
        {
            po_batch b;
            po_wal w;
            STRLEN slen, elen, plen;
            const char *sig, *enc, *pth;
            po_u64 iv = 0;
            int ok = 0, appended = 0, opened = 0;
            HV *res;

            sig = SvPV(signal, slen);
            enc = SvPV(encoding, elen);
            pth = SvPV(path, plen);

            if (!po_batch_init(&b, 64)) croak("out of memory");

            if (elen == 4 && memcmp(enc, "json", 4) == 0) {
                if      (slen == 6 && memcmp(sig, "traces",  6) == 0)
                    po_json_traces(aTHX_ buf, &b);
                else if (slen == 4 && memcmp(sig, "logs",    4) == 0)
                    po_json_logs(aTHX_ buf, &b);
                else if (slen == 7 && memcmp(sig, "metrics", 7) == 0)
                    po_json_metrics(aTHX_ buf, &b);
                else { po_batch_free(&b); croak("unknown signal"); }
                ok = b.err ? 0 : 1;
            }
            else {
                STRLEN blen;
                const char *bp = SvPV(buf, blen);
                if      (slen == 6 && memcmp(sig, "traces",  6) == 0)
                    ok = po_otlp_traces(bp, (size_t)blen, &b);
                else if (slen == 4 && memcmp(sig, "logs",    4) == 0)
                    ok = po_otlp_logs(bp, (size_t)blen, &b);
                else if (slen == 7 && memcmp(sig, "metrics", 7) == 0)
                    ok = po_otlp_metrics(bp, (size_t)blen, &b);
                else { po_batch_free(&b); croak("unknown signal"); }
                if (b.err) ok = 0;
            }

            res = newHV();

            /* The records are materialised BEFORE the append, because the
             * observer is documented as seeing what was decoded whether or
             * not the disk took it - and because a failed append is exactly
             * when somebody wants to know what was in the batch. */
            if (ok && SvTRUE(want_records)) {
                AV *recs = newAV();
                size_t i;
                for (i = 0; i < b.n; i++)
                    av_push(recs, po_rec_hv(aTHX_ &b.rec[i], &b.arena));
                hv_stores(res, "records", newRV_noinc((SV *)recs));
            }

            /* THE RATE LIMIT DECIDES BEFORE THE APPEND, NOT AFTER.
             *
             * A partial success means "I did not keep these". Deciding after
             * the write and reporting the overflow anyway would say that
             * about records already on the disk, and an exporter doing the
             * correct thing - resending what it was told was rejected -
             * would duplicate every one of them. So the batch is truncated
             * here and only the admitted prefix reaches the log.
             *
             * Truncating a PREFIX rather than refusing the batch is the whole
             * reason po_rate_admit returns a count: refusing whole batches is
             * what turns a limiter into an amplifier. */
            if (ok && b.n && items > 7 && SvOK(ST(7)) && SvIV(ST(7))) {
                po_shared *sh = INT2PTR(po_shared *, SvIV(ST(7)));
                po_rate_cfg cfg;
                po_rate_win win;
                po_u64 maxr = 0, maxb = 0, admit, bytes = 0;

                if (items > 8) (void)po_sv_to_u64(aTHX_ ST(8), &maxr);
                if (items > 9) (void)po_sv_to_u64(aTHX_ ST(9), &maxb);
                po_rate_cfg_init(&cfg, maxr, maxb);
                po_shared_rate(sh, &win);

                /* The decoded size, which is what the store will hold - not
                 * the request body, which may be gzipped and is a different
                 * number depending on how well it compressed. */
                bytes = (po_u64)b.arena.len;
                admit = po_rate_admit(&cfg, &win, (po_u64)b.n, bytes);
                if (admit < (po_u64)b.n) {
                    hv_stores(res, "rejected", po_u64_to_sv((po_u64)b.n - admit));
                    b.n = (size_t)admit;
                }
            }

            /* THE CARDINALITY GATE, BEFORE THE APPEND.
             *
             * Each metric record's series id is the hash of its canonical
             * attribute block - the same bytes the segment writer interns at
             * seal. An
             * existing series passes untouched; a NEW one past the cap is
             * not dropped and not stored as itself: its record is rewritten
             * onto the named overflow series, so the volume survives, the
             * cardinality stops, and the data says "you exceeded the cap"
             * rather than going quietly missing. The exporter is NOT told
             * these were rejected - they were kept, and a partial success
             * naming them would invite a resend that duplicates them. */
            if (ok && b.n && items > 7 && SvOK(ST(7)) && SvIV(ST(7))) {
                po_shared *shc = INT2PTR(po_shared *, SvIV(ST(7)));
                uint32_t ov_off = 0, ov_len = 0;
                po_u64 overflowed = 0;
                size_t ri;
                for (ri = 0; ri < b.n; ri++) {
                    po_h128 h;
                    /* METRICS ONLY. The cap bounds per-series ONGOING state -
                     * rollups, exemplar sidecars, compression streams - and
                     * only metrics have any. A log line or span with a unique
                     * attribute block is bytes in a sealed segment, paid once
                     * and aged out by retention; its bound is the rate
                     * limiter. Gating those too meant a payment id logged as
                     * a field cost a series per checkout, and "log any data"
                     * is a requirement. */
                    if (b.rec[ri].kind != PO_METRIC) continue;
                    h = po_murmur3_128(
                        b.arena.base + b.rec[ri].attr_off,
                        (size_t)b.rec[ri].attr_len, 0);
                    if (po_shared_series_admit(shc, h.hi, h.lo)) continue;
                    if (!ov_len) {
                        po_attrs ov;
                        po_attr *oa;
                        po_h128 ovid;
                        po_attrs_init(&ov);
                        oa = po_attrs_push(&ov, "otel.overflow", 13);
                        if (oa) { oa->tag = PO_AV_STRING;
                                  oa->sp = (const uint8_t *)"cap"; oa->slen = 3; }
                        ov_off = po_attrs_encode(&ov, &b.arena, &ov_len);
                        if (ov_off == PO_ARENA_ERR) { ov_len = 0; continue; }
                        /* The overflow series is itself a series, admitted
                         * outside the cap or attributing to it would loop. */
                        ovid = po_murmur3_128(b.arena.base + ov_off,
                                              (size_t)ov_len, 0);
                        po_shared_series_force(shc, ovid.hi, ovid.lo);
                    }
                    b.rec[ri].attr_off = ov_off;
                    b.rec[ri].attr_len = ov_len;
                    overflowed++;
                }
                if (overflowed)
                    hv_stores(res, "overflowed", po_u64_to_sv(overflowed));
            }

            /* An empty batch is a success that writes nothing. Opening the log
             * for it would create an empty file per exporter that had nothing
             * to say. */
            if (ok && b.n && plen) {
                if (!po_sv_to_u64(aTHX_ interval_ns, &iv)) iv = 0;
                if (po_wal_open(&w, pth, (int)SvIV(policy), iv)) {
                    opened   = 1;
                    appended = po_wal_append(&w, b.rec, b.n,
                                             b.arena.base, b.arena.len);
                    if (!appended)
                        hv_stores(res, "errno", newSVpv(strerror(errno), 0));
                    hv_stores(res, "frames", po_u64_to_sv(w.frames_written));
                    hv_stores(res, "bytes",  po_u64_to_sv(w.bytes_written));
                    hv_stores(res, "fsyncs", po_u64_to_sv(w.fsyncs));
                    po_wal_close(&w);
                }
                else hv_stores(res, "errno", newSVpv(strerror(errno), 0));
            }
            else if (ok) appended = 1;      /* nothing to write is written */

            hv_stores(res, "ok",       newSViv(ok ? 1 : 0));
            hv_stores(res, "appended", newSViv(appended ? 1 : 0));
            hv_stores(res, "opened",   newSViv(opened ? 1 : 0));
            hv_stores(res, "n",        po_u64_to_sv((po_u64)b.n));

            /* WHAT ARRIVED, counted where every worker can see it. The store's
             * own record count is what survived retention; this is what was
             * accepted, and the two answer different questions. */
            if (appended && b.n && items > 7 && SvOK(ST(7)) && SvIV(ST(7)))
                po_shared_record(INT2PTR(po_shared *, SvIV(ST(7))),
                                 (po_u64)b.n, (po_u64)b.arena.len);

            hv_stores(res, "dropped_bad_trace", newSViv((IV)b.dropped_bad_trace));
            hv_stores(res, "clamped_durations", newSViv((IV)b.clamped_durations));
            po_batch_free(&b);
            RETVAL = newRV_noinc((SV *)res);
        }
    OUTPUT:
        RETVAL

# The OTLP partial-success body, in protobuf.
#
#   ExportTraceServiceResponse { partial_success = 1 }
#   ExportTracePartialSuccess  { rejected_* = 1, error_message = 2 }
#
# Tiny, and on the response path rather than the hot one, but it has to be
# exactly right: this is the channel that tells a client "I kept 9,600 of
# these and rejected 400", and Punk::OpenTelemetry's exporter reads it.
SV *
poi_partial_success_pb(SV *rejected, SV *message)
    CODE:
        {
            char outer[80];
            po_u64 rej = 0;
            STRLEN mlen = 0;
            const char *msg = NULL;
            size_t o;

            (void)po_sv_to_u64(aTHX_ rejected, &rej);
            if (SvOK(message)) msg = SvPV(message, mlen);
            o = po_partial_success_pb(outer, rej, msg, (size_t)mlen);
            RETVAL = newSVpvn(outer, (STRLEN)o);
        }
    OUTPUT:
        RETVAL
