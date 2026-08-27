MODULE = Punk::Observe   PACKAGE = Punk::Observe::WAL   PREFIX = pow_

# The WAL surface. The ingest path in phase 3 calls the C directly with the
# record array the decoder produced; this exists so t/0004-wal.t can drive it,
# and so a forked child in that test can append and then die mid-frame.

# --- CRC-32C ---------------------------------------------------------------

UV
pow_crc32c(SV *buf)
    CODE:
        {
            STRLEN len; const char *p;
            p = SvPV(buf, len);
            RETVAL = (UV)po_crc32c(0, p, (size_t)len);
        }
    OUTPUT:
        RETVAL

# The table path, forced. The hardware path is what runs in production on any
# modern box, so without this the fallback would ship exercised only on the
# machines least able to report why it broke - and a WAL written with the
# instruction and replayed without it has to verify.
UV
pow_crc32c_table(SV *buf)
    CODE:
        {
            STRLEN len; const char *p;
            p = SvPV(buf, len);
            RETVAL = (UV)po_crc32c_table(0, p, (size_t)len);
        }
    OUTPUT:
        RETVAL

int
pow_crc32c_hardware(...)
    CODE:
        RETVAL = po_crc32c_hardware();
    OUTPUT:
        RETVAL

UV
pow_hdr_size(...)
    CODE:
        RETVAL = (UV)PO_WAL_HDR;
    OUTPUT:
        RETVAL

# --- appending -------------------------------------------------------------

# Append a batch of records described from Perl.
#
# A record is the hash po_rec_hv produces, and every field of it is stored -
# see po_rec_from_hv for why that is not merely tidy. The WAL still does not
# need to UNDERSTAND a record; it does need to keep one whole, because it is
# the only copy until the compactor seals a segment.
SV *
pow_append(SV *path, SV *specs, SV *policy, SV *interval_ns)
    CODE:
        {
            po_wal w;
            po_arena ar;
            po_rec *recs = NULL;
            AV *av;
            SSize_t n, i;
            STRLEN plen;
            const char *p;
            po_u64 iv = 0;
            int ok = 1;
            HV *res;

            p = SvPV(path, plen);
            if (!SvROK(specs) || SvTYPE(SvRV(specs)) != SVt_PVAV)
                croak("specs must be an arrayref");
            av = (AV *)SvRV(specs);
            n  = av_len(av) + 1;

            if (!po_sv_to_u64(aTHX_ interval_ns, &iv)) iv = 0;
            if (!po_wal_open(&w, p, (int)SvIV(policy), iv))
                croak("open %s: %s", p, strerror(errno));
            if (!po_arena_init(&ar, 256)) { po_wal_close(&w); croak("arena"); }

            if (n > 0) {
                Newx(recs, n, po_rec);
                for (i = 0; i < n; i++) {
                    SV **e = av_fetch(av, i, 0);
                    po_rec_zero(&recs[i]);
                    if (!e || !SvROK(*e)) continue;
                    if (!po_rec_from_hv(aTHX_ (HV *)SvRV(*e), &recs[i], &ar)) {
                        ok = 0;
                        break;
                    }
                }
                if (ok) ok = po_wal_append(&w, recs, (size_t)n, ar.base, ar.len);
            }

            res = newHV();
            hv_stores(res, "ok",      newSViv(ok ? 1 : 0));
            hv_stores(res, "frames",  po_u64_to_sv(w.frames_written));
            hv_stores(res, "bytes",   po_u64_to_sv(w.bytes_written));
            hv_stores(res, "fsyncs",  po_u64_to_sv(w.fsyncs));
            if (!ok) hv_stores(res, "errno", newSVpv(strerror(errno), 0));

            Safefree(recs);
            po_arena_free(&ar);
            po_wal_close(&w);
            RETVAL = newRV_noinc((SV *)res);
        }
    OUTPUT:
        RETVAL

# Append several frames through ONE open handle, so the fsync policy can be
# observed across frames rather than one at a time.
SV *
pow_append_many(SV *path, SV *frames, SV *policy, SV *interval_ns)
    CODE:
        {
            po_wal w;
            STRLEN plen;
            const char *p;
            po_u64 iv = 0;
            IV nframes = SvIV(frames);
            IV k;
            int ok = 1;
            HV *res;

            p = SvPV(path, plen);
            if (!po_sv_to_u64(aTHX_ interval_ns, &iv)) iv = 0;
            if (!po_wal_open(&w, p, (int)SvIV(policy), iv))
                croak("open %s: %s", p, strerror(errno));

            for (k = 0; k < nframes && ok; k++) {
                po_rec r;
                po_rec_zero(&r);
                r.kind        = PO_SPAN;
                r.t_unix_nano = (po_u64)1774224000000000000ULL + (po_u64)k;
                ok = po_wal_append(&w, &r, 1, NULL, 0);
            }

            res = newHV();
            hv_stores(res, "ok",     newSViv(ok ? 1 : 0));
            hv_stores(res, "frames", po_u64_to_sv(w.frames_written));
            hv_stores(res, "fsyncs", po_u64_to_sv(w.fsyncs));
            po_wal_close(&w);
            RETVAL = newRV_noinc((SV *)res);
        }
    OUTPUT:
        RETVAL

SV *
pow_seal(SV *path, SV *total)
    CODE:
        {
            po_wal w;
            STRLEN plen;
            const char *p = SvPV(path, plen);
            po_u64 t = 0;
            int ok;
            (void)po_sv_to_u64(aTHX_ total, &t);
            if (!po_wal_open(&w, p, PO_FSYNC_NEVER, 0))
                croak("open %s: %s", p, strerror(errno));
            ok = po_wal_seal(&w, t);
            po_wal_close(&w);
            RETVAL = newSViv(ok ? 1 : 0);
        }
    OUTPUT:
        RETVAL

# --- replay ----------------------------------------------------------------

SV *
pow_replay(SV *buf)
    CODE:
        {
            po_wal_replay rp;
            STRLEN len;
            const char *p;
            HV *res;

            p = SvPV(buf, len);
            po_wal_replay_buf(p, (size_t)len, &rp, NULL, NULL);

            res = newHV();
            hv_stores(res, "frames",          po_u64_to_sv(rp.frames));
            hv_stores(res, "records",         po_u64_to_sv(rp.records));
            hv_stores(res, "bytes_ok",        po_u64_to_sv(rp.bytes_ok));
            hv_stores(res, "bytes_truncated", po_u64_to_sv(rp.bytes_truncated));
            hv_stores(res, "sealed",          newSViv(rp.sealed));
            hv_stores(res, "reason",
                      newSVpv(po_replay_reason(rp.stopped_reason), 0));
            RETVAL = newRV_noinc((SV *)res);
        }
    OUTPUT:
        RETVAL

# Replay and hand back the records themselves - the same hash shape the
# decoder produces, so a replayed record and a freshly decoded one are
# indistinguishable to everything upstream. That is what lets the reader in
# Punk::Observe::Store query an unsealed log without a second row shape.
void
pow_replay_bodies(SV *buf)
    PPCODE:
        {
            po_wal_replay rp;
            STRLEN len;
            const char *p;
            AV *out = newAV();

            p = SvPV(buf, len);
            {
                size_t off = 0;
                /* Walk with the same rules as po_wal_replay_buf, collecting
                 * bodies. Kept here rather than as a callback so the XS does
                 * not have to smuggle a Perl context through a C function
                 * pointer. */
                po_wal_replay_buf(p, (size_t)len, &rp, NULL, NULL);
                for (;;) {
                    uint32_t magic, frame_len, n_recs, arena_len;
                    uint16_t flags, version;
                    const char *h;
                    const po_rec *recs;
                    po_arena view;
                    size_t i;

                    if ((size_t)len - off < PO_WAL_HDR) break;
                    h = p + off;
                    memcpy(&magic, h, 4); magic = po_le32(magic);
                    if (magic != PO_WAL_MAGIC) break;
                    memcpy(&frame_len, h + 4, 4);  frame_len = po_le32(frame_len);
                    memcpy(&n_recs,    h + 8, 4);  n_recs    = po_le32(n_recs);
                    memcpy(&arena_len, h + 12, 4); arena_len = po_le32(arena_len);
                    flags   = (uint16_t)((unsigned char)h[36]
                                       | ((unsigned char)h[37] << 8));
                    version = (uint16_t)((unsigned char)h[38]
                                       | ((unsigned char)h[39] << 8));
                    if (version != PO_WAL_VERSION) break;
                    if (flags & PO_WAL_F_SEALED) break;
                    if ((size_t)len - off - PO_WAL_HDR < (size_t)frame_len) break;
                    if (off + PO_WAL_HDR + frame_len > rp.bytes_ok) break;

                    recs = (const po_rec *)(h + PO_WAL_HDR);
                    /* A read-only view onto the frame's own arena. po_rec_hv
                     * only ever reads base, and nothing here owns it, so this
                     * is never freed. */
                    view.base = (char *)(h + PO_WAL_HDR
                                           + (size_t)n_recs * sizeof(po_rec));
                    view.len  = (size_t)arena_len;
                    view.cap  = (size_t)arena_len;

                    for (i = 0; i < n_recs; i++)
                        av_push(out, po_rec_hv(aTHX_ &recs[i], &view));
                    off += PO_WAL_HDR + frame_len;
                }
            }
            mXPUSHs(newRV_noinc((SV *)out));
        }
