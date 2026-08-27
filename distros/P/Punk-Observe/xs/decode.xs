MODULE = Punk::Observe   PACKAGE = Punk::Observe::Decode   PREFIX = pod_

# The decode surface. Records come back as an array of hashrefs so the tests
# can assert field by field; the ingest path in phase 3 never builds an SV per
# record and calls the C directly.

# --- the generic reader, exposed for the wire-level tests -------------------

# Parse a buffer into [ { field, wire, ... } ], one entry per top-level field.
# Enough to assert the wire contract without any OTLP schema in the way.
void
pod_pb_fields(SV *buf)
    PPCODE:
        {
            po_pbr r;
            STRLEN len;
            const char *p;
            uint32_t f, w;
            AV *out = newAV();

            p = SvPV(buf, len);          /* own line: sibling-arg order is UB */
            po_pbr_init(&r, p, (size_t)len);

            while (po_pbr_next(&r, &f, &w)) {
                HV *h = newHV();
                hv_stores(h, "field", newSVuv((UV)f));
                hv_stores(h, "wire",  newSVuv((UV)w));
                switch (w) {
                    case PO_PB_VARINT: {
                        po_u64 v;
                        if (!po_pbr_varint(&r, &v)) break;
                        hv_stores(h, "varint", po_u64_to_sv(v));
                        hv_stores(h, "int32",  newSViv((IV)(int32_t)(uint32_t)(v & 0xFFFFFFFFu)));
                        break;
                    }
                    case PO_PB_FIXED64: {
                        po_u64 v; double d;
                        if (!po_pbr_fixed64(&r, &v)) break;
                        memcpy(&d, &v, 8);
                        hv_stores(h, "fixed64", po_u64_to_sv(v));
                        hv_stores(h, "double",  newSVnv((NV)d));
                        break;
                    }
                    case PO_PB_FIXED32: {
                        uint32_t v;
                        if (!po_pbr_fixed32(&r, &v)) break;
                        hv_stores(h, "fixed32", newSVuv((UV)v));
                        break;
                    }
                    case PO_PB_BYTES: {
                        const uint8_t *bp; size_t bn;
                        if (!po_pbr_bytes(&r, &bp, &bn)) break;
                        hv_stores(h, "bytes", newSVpvn((const char *)bp, bn));
                        break;
                    }
                    default: break;
                }
                av_push(out, newRV_noinc((SV *)h));
                if (r.err) break;
            }

            {
                HV *res = newHV();
                hv_stores(res, "fields", newRV_noinc((SV *)out));
                hv_stores(res, "err",    newSViv((IV)r.err));
                hv_stores(res, "errstr", newSVpv(po_pbr_errstr(r.err), 0));
                mXPUSHs(newRV_noinc((SV *)res));
            }
        }

# --- OTLP ------------------------------------------------------------------

SV *
pod_decode(SV *buf, SV *signal)
    CODE:
        {
            po_batch b;
            STRLEN len, slen;
            const char *p, *sig;
            int ok;
            AV *recs;
            HV *res;
            size_t i;

            p   = SvPV(buf, len);
            sig = SvPV(signal, slen);

            if (!po_batch_init(&b, 16)) croak("out of memory");

            if      (slen == 6 && memcmp(sig, "traces",  6) == 0)
                ok = po_otlp_traces(p, (size_t)len, &b);
            else if (slen == 4 && memcmp(sig, "logs",    4) == 0)
                ok = po_otlp_logs(p, (size_t)len, &b);
            else if (slen == 7 && memcmp(sig, "metrics", 7) == 0)
                ok = po_otlp_metrics(p, (size_t)len, &b);
            else { po_batch_free(&b); croak("unknown signal"); }

            recs = newAV();
            if (ok && !b.err) {
                for (i = 0; i < b.n; i++)
                    av_push(recs, po_rec_hv(aTHX_ &b.rec[i], &b.arena));
            }

            res = newHV();
            hv_stores(res, "ok",      newSViv(ok && !b.err ? 1 : 0));
            hv_stores(res, "records", newRV_noinc((SV *)recs));
            hv_stores(res, "dropped_bad_trace", newSViv((IV)b.dropped_bad_trace));
            hv_stores(res, "clamped_durations", newSViv((IV)b.clamped_durations));
            po_batch_free(&b);
            RETVAL = newRV_noinc((SV *)res);
        }
    OUTPUT:
        RETVAL
