MODULE = Punk::Observe   PACKAGE = Punk::Observe::Store   PREFIX = post_

# The three arithmetic primitives, so the Perl that still needs them one at a
# time is not doing digit loops.

int
post_ncmp(SV *a, SV *b)
    CODE:
    {
        STRLEN al = 0, bl = 0;
        const char *ap = SvOK(a) ? SvPV(a, al) : "0";
        const char *bp;
        int ok;
        if (!SvOK(a)) al = 1;
        bp = SvOK(b) ? SvPV(b, bl) : "0";
        if (!SvOK(b)) bl = 1;
        if (!al) { ap = "0"; al = 1; }
        if (!bl) { bp = "0"; bl = 1; }
        RETVAL = po_ns_cmp_str(ap, (size_t)al, bp, (size_t)bl, &ok);
    }
    OUTPUT:
        RETVAL

SV *
post_nadd(SV *a, SV *b)
    CODE:
    {
        po_u64 x = 0, y = 0;
        (void)po_sv_to_u64(aTHX_ a, &x);
        (void)po_sv_to_u64(aTHX_ b, &y);
        RETVAL = po_u64_to_sv(po_ns_add(x, y));
    }
    OUTPUT:
        RETVAL

SV *
post_nsub(SV *a, SV *b)
    CODE:
    {
        po_u64 x = 0, y = 0;
        (void)po_sv_to_u64(aTHX_ a, &x);
        (void)po_sv_to_u64(aTHX_ b, &y);
        RETVAL = po_u64_to_sv(po_ns_sub(x, y));
    }
    OUTPUT:
        RETVAL

# Replay one log, filter it, and hand back what survives - NEWEST FIRST.
#
# This is the whole of what the Perl scan loop used to do, and the reason it
# is one call rather than several: the loop it replaces made two Perl-level
# comparison calls per record and then sorted with a Perl comparator, so a
# half-million-row segment paid a million sub calls before the sort even
# started. The filtering is the same; only the number of times a Perl stack
# frame is built has changed.
#
# The rows come back in the executor's shape rather than the record's, for
# the same reason Store::row exists: `kind` is a name and `service` is lifted
# out of the attributes, because every query filters on it and no query
# should have to know where it lives.
void
post_scan(SV *buf, SV *opts)
    PPCODE:
    {
        po_wal_replay rp;
        STRLEN len;
        const char *p;
        HV *o = NULL;
        SV **f;
        AV *out = newAV();
        HV *meta = newHV();
        po_u64 from = 0, to = PO_U64_MAX, limit = 0;
        int have_from = 0, have_to = 0, kind = 0, as_rows = 0;
        IV scanned = 0, kept = 0;
        SV **keep = NULL;
        po_u64 *keys = NULL;
        IV nkeep = 0, cap = 0;

        p = SvPV(buf, len);
        if (SvROK(opts) && SvTYPE(SvRV(opts)) == SVt_PVHV) o = (HV *)SvRV(opts);
        if (o) {
            if ((f = hv_fetchs(o, "from", 0)) && SvOK(*f))
                have_from = po_sv_to_u64(aTHX_ *f, &from);
            if ((f = hv_fetchs(o, "to", 0)) && SvOK(*f))
                have_to = po_sv_to_u64(aTHX_ *f, &to);
            if ((f = hv_fetchs(o, "kind", 0)) && SvOK(*f)) kind = (int)SvIV(*f);
            if ((f = hv_fetchs(o, "limit", 0)) && SvOK(*f))
                (void)po_sv_to_u64(aTHX_ *f, &limit);
            if ((f = hv_fetchs(o, "rows", 0)) && SvTRUE(*f)) as_rows = 1;
        }

        po_wal_replay_buf(p, (size_t)len, &rp, NULL, NULL);

        {
            size_t off = 0;
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
                view.base = (char *)(h + PO_WAL_HDR
                                       + (size_t)n_recs * sizeof(po_rec));
                view.len  = (size_t)arena_len;
                view.cap  = (size_t)arena_len;

                for (i = 0; i < n_recs; i++) {
                    const po_rec *r = &recs[i];
                    scanned++;
                    /* The comparisons are integers here, which is the point.
                     * The Perl did them on decimal strings. */
                    if (have_from && r->t_unix_nano < from) continue;
                    if (have_to   && r->t_unix_nano > to)   continue;
                    if (kind && r->kind != (uint8_t)kind)   continue;

                    if (nkeep == cap) {
                        IV want = cap ? cap * 2 : 256;
                        Renew(keep, want, SV *);
                        Renew(keys, want, po_u64);
                        cap = want;
                    }
                    keep[nkeep] = as_rows ? po_row_hv(aTHX_ r, &view)
                                          : po_rec_hv(aTHX_ r, &view);
                    keys[nkeep] = r->t_unix_nano;
                    nkeep++;
                }
                off += PO_WAL_HDR + frame_len;
            }
        }

        /* NEWEST FIRST, which is the order every one of these screens wants.
         *
         * A WRITE-AHEAD LOG IS ALREADY IN TIME ORDER - it is append-only, so
         * the records arrive oldest first. "Newest first" is therefore a
         * REVERSE and not a sort, and the common case is one pass.
         *
         * The first version of this used an insertion sort, on the reasoning
         * that nearly-ordered input is what insertion sort is best at. That
         * reasoning was exactly backwards: the input is ascending and the
         * output is descending, which is insertion sort's WORST case, and it
         * turned a 50,000-record scan into 2.5 billion comparisons. Measured
         * at five times slower than the Perl it replaced, which is the only
         * reason it was found.
         *
         * Out-of-order records do happen - a clock stepping, a batch arriving
         * late - so the order is checked rather than assumed, and anything
         * that is not already sorted falls back to a real O(n log n) sort. */
        {
            IV i;
            int ascending = 1;
            for (i = 1; i < nkeep; i++)
                if (keys[i] < keys[i - 1]) { ascending = 0; break; }

            if (ascending) {
                for (i = 0; i < nkeep / 2; i++) {
                    po_u64 tk = keys[i];
                    SV *tv = keep[i];
                    keys[i] = keys[nkeep - 1 - i];
                    keep[i] = keep[nkeep - 1 - i];
                    keys[nkeep - 1 - i] = tk;
                    keep[nkeep - 1 - i] = tv;
                }
            }
            else {
                po_sortpair *pairs;
                Newx(pairs, nkeep, po_sortpair);
                for (i = 0; i < nkeep; i++) {
                    pairs[i].key = keys[i];
                    pairs[i].sv  = keep[i];
                }
                qsort(pairs, (size_t)nkeep, sizeof(po_sortpair), po_sortpair_desc);
                for (i = 0; i < nkeep; i++) {
                    keys[i] = pairs[i].key;
                    keep[i] = pairs[i].sv;
                }
                Safefree(pairs);
            }
        }

        kept = nkeep;
        {
            IV i;
            IV lim = limit ? (IV)limit : nkeep;
            for (i = 0; i < nkeep; i++) {
                if (i < lim) av_push(out, keep[i]);
                else SvREFCNT_dec(keep[i]);   /* over the cap, and owned here */
            }
            hv_stores(meta, "truncated", newSViv(nkeep > lim ? 1 : 0));
        }
        Safefree(keep);
        Safefree(keys);

        hv_stores(meta, "scanned", newSViv(scanned));
        hv_stores(meta, "kept",    newSViv(kept));
        /* A log this build cannot read is REPORTED, never guessed at, and it
         * is not fatal: the other segments still answer and the answer says
         * it is short. */
        hv_stores(meta, "reason",
                  newSVpv(po_replay_reason(rp.stopped_reason), 0));

        mXPUSHs(newRV_noinc((SV *)out));
        mXPUSHs(newRV_noinc((SV *)meta));
    }

# ---- the file layer -------------------------------------------------------

# Every file the read side can see, sealed and live, oldest name first.
#
# The Perl this replaces did opendir, a sort, two regex matches and two stats
# per entry, then opened and parsed every sidecar in Perl. The sidecar parse
# is the part that mattered: one segment's index is a dozen lines, but a store
# with a thousand segments parsed twelve thousand lines through a regex on
# every single query.
void
post_scan_dir(SV *dir)
    PPCODE:
    {
        po_dir d;
        STRLEN dl;
        const char *dp = SvPV(dir, dl);
        AV *out = newAV();
        const char *name;
        AV *names = newAV();
        SSize_t i, n;

        if (!po_is_dir(dp)) { mXPUSHs(newRV_noinc((SV *)out)); XSRETURN(1); }
        if (!po_opendir(&d, dp)) { mXPUSHs(newRV_noinc((SV *)out)); XSRETURN(1); }
        while ((name = po_readdir(&d))) av_push(names, newSVpv(name, 0));
        po_closedir(&d);

        /* Sorted by NAME, and the name carries the sealing time - so this is
         * chronological without a stat per entry. */
        sortsv(AvARRAY(names), (SSize_t)(av_len(names) + 1), Perl_sv_cmp);

        n = av_len(names) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(names, i, 0);
            STRLEN nl;
            const char *np;
            int sealed;
            char path[PO_PATHMAX];
            HV *h;
            po_u64 sz = 0;

            if (!e) continue;
            np = SvPV(*e, nl);
            if (nl > 4 && memcmp(np + nl - 4, ".seg", 4) == 0) sealed = 1;
            else if (nl > 4 && memcmp(np + nl - 4, ".wal", 4) == 0) sealed = 0;
            else continue;

            if (!po_path_join(path, sizeof(path), dp, np)) continue;
            po_file_size(path, &sz);

            h = newHV();
            hv_stores(h, "path",   newSVpv(path, 0));
            hv_stores(h, "name",   newSVpvn(np, nl));
            hv_stores(h, "sealed", newSViv(sealed));
            hv_stores(h, "bytes",  po_u64_to_sv(sz));

            if (sealed) {
                char idx[PO_PATHMAX];
                memcpy(idx, path, strlen(path) + 1);
                memcpy(idx + strlen(idx) - 4, ".idx", 5);
                hv_stores(h, "idx_path", newSVpv(idx, 0));
                hv_stores(h, "index", po_index_read_sv(aTHX_ idx));
            }
            else hv_stores(h, "index", newSV(0));

            av_push(out, newRV_noinc((SV *)h));
        }
        SvREFCNT_dec((SV *)names);
        mXPUSHs(newRV_noinc((SV *)out));
    }

# Read one sidecar. Exposed so a caller can read an index without listing a
# directory, and so the format has one reader rather than two.
SV *
post_read_index(SV *path)
    CODE:
        RETVAL = po_index_read_sv(aTHX_ SvPV_nolen(path));
    OUTPUT:
        RETVAL

# Write one, atomically. A reader must never see half a sidecar, so this is
# write-to-temporary then rename rather than open-and-print.
int
post_write_index(SV *path, SV *summary)
    CODE:
    {
        if (!SvROK(summary) || SvTYPE(SvRV(summary)) != SVt_PVHV)
            croak("summary must be a hashref");
        RETVAL = po_index_write(aTHX_ SvPV_nolen(path), (HV *)SvRV(summary));
    }
    OUTPUT:
        RETVAL

SV *
post_slurp(SV *path)
    CODE:
    {
        size_t n = 0;
        char *b = po_slurp(SvPV_nolen(path), &n);
        if (!b) XSRETURN_UNDEF;
        RETVAL = newSVpvn(b, n);
        free(b);
    }
    OUTPUT:
        RETVAL

int
post_mkpath(SV *path)
    CODE:
        RETVAL = po_mkpath(SvPV_nolen(path)) ? 1 : 0;
    OUTPUT:
        RETVAL

int
post_rename_file(SV *from, SV *to)
    CODE:
        RETVAL = po_seal_rename(SvPV_nolen(from), SvPV_nolen(to)) ? 1 : 0;
    OUTPUT:
        RETVAL

SV *
post_file_size(SV *path)
    CODE:
    {
        po_u64 sz = 0;
        if (!po_file_size(SvPV_nolen(path), &sz)) XSRETURN_UNDEF;
        RETVAL = po_u64_to_sv(sz);
    }
    OUTPUT:
        RETVAL

# Summarise a sealed log in ONE pass over its records.
#
# EVERY FIGURE HERE IS ONE A QUERY WOULD OTHERWISE SCAN THE WHOLE SEGMENT TO
# LEARN: the time span is what lets a range query skip the file without
# opening it, and the severity histogram is what makes "how many errors" a
# read of a hundred bytes.
#
# The COUNTS of a segment, from the raw records, without building a hash per
# record the way replay_bodies has to.
#
# COUNTS ONLY. It does not build the service graph and it does not count
# traces, and `seal` therefore does not use it: those two are the whole reason
# a sidecar makes the service map a read of a few hundred bytes instead of a
# scan, and a summary with `edges => []` in it would draw an empty map at full
# speed. Wiring this in means finishing it first - the interning and the span
# conversion the graph needs are the missing half.
void
post_summarise(SV *buf)
    PPCODE:
    {
        po_wal_replay rp;
        STRLEN len;
        const char *p = SvPV(buf, len);
        HV *s = newHV();
        HV *sev = newHV(), *svc = newHV();
        po_u64 t_min = PO_U64_MAX, t_max = 0;
        IV records = 0, metrics = 0, logs = 0, spans = 0, errors = 0;
        int have_t = 0;
        po_sgraph g;
        po_intern names;
        int graph_ok;

        graph_ok = po_sgraph_init(&g) && po_intern_init(&names, 64);

        po_wal_replay_buf(p, (size_t)len, &rp, NULL, NULL);

        {
            size_t off = 0;
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
                version = (uint16_t)((unsigned char)h[38]
                                   | ((unsigned char)h[39] << 8));
                flags   = (uint16_t)((unsigned char)h[36]
                                   | ((unsigned char)h[37] << 8));
                if (version != PO_WAL_VERSION) break;

                /* THE SEAL TRAILER IS NOT A FRAME OF RECORDS. It carries the
                 * FILE'S TOTAL RECORD COUNT in the field every other frame
                 * uses for its own, with frame_len zero - so walking it as
                 * data reads 88 bytes times every record the segment ever
                 * held, past the end of the buffer. The flag was read here
                 * and then thrown away with a (void) cast. */
                if (flags & PO_WAL_F_SEALED) break;

                if ((size_t)len - off - PO_WAL_HDR < (size_t)frame_len) break;
                if (off + PO_WAL_HDR + frame_len > rp.bytes_ok) break;

                recs = (const po_rec *)(h + PO_WAL_HDR);
                view.base = (char *)(h + PO_WAL_HDR
                                       + (size_t)n_recs * sizeof(po_rec));
                view.len  = (size_t)arena_len;
                view.cap  = (size_t)arena_len;

                for (i = 0; i < n_recs; i++) {
                    const po_rec *r = &recs[i];
                    const char *service = NULL;
                    size_t svc_len = 0;

                    records++;
                    if (!have_t || r->t_unix_nano < t_min) t_min = r->t_unix_nano;
                    if (!have_t || r->t_unix_nano > t_max) t_max = r->t_unix_nano;
                    have_t = 1;

                    po_rec_service(r, &view, &service, &svc_len);
                    if (!service || !svc_len) { service = "unknown"; svc_len = 7; }
                    {
                        SV **slot = hv_fetch(svc, service, (I32)svc_len, 1);
                        if (slot) sv_setiv(*slot, (SvOK(*slot) ? SvIV(*slot) : 0) + 1);
                    }

                    if (r->kind == PO_LOG) {
                        char kb[16];
                        int kn = snprintf(kb, sizeof(kb), "%u",
                                          (unsigned)r->severity);
                        SV **slot;
                        logs++;
                        slot = hv_fetch(sev, kb, kn, 1);
                        if (slot) sv_setiv(*slot, (SvOK(*slot) ? SvIV(*slot) : 0) + 1);
                    }
                    else if (r->kind == PO_METRIC) metrics++;
                    else if (r->kind == PO_SPAN) {
                        spans++;
                        if (po_rec_status(r) == 2) errors++;
                    }
                }
                off += PO_WAL_HDR + frame_len;
            }
        }

        hv_stores(s, "records", newSViv(records));
        hv_stores(s, "t_min",   have_t ? po_u64_to_sv(t_min) : newSViv(0));
        hv_stores(s, "t_max",   have_t ? po_u64_to_sv(t_max) : newSViv(0));
        hv_stores(s, "metrics", newSViv(metrics));
        hv_stores(s, "logs",    newSViv(logs));
        hv_stores(s, "spans",   newSViv(spans));
        hv_stores(s, "errors",  newSViv(errors));
        hv_stores(s, "severity", newRV_noinc((SV *)sev));
        hv_stores(s, "service",  newRV_noinc((SV *)svc));

        /* THE GRAPH AND THE TRACE COUNT, IN THE SAME PASS.
         *
         * Both were Perl until now, and both walked the records a second time
         * to get there - one to build spans for Trace::analyse, one to count
         * distinct trace ids in a hash. The spans are gathered once here and
         * both answers come off the same set.
         *
         * The graph is accumulated AT SEAL and never at read time. A map
         * built by reading every span of every segment is a map nobody waits
         * for. */
        {
            po_span_gather sg;
            AV *edges = newAV();
            IV ntraces = 0;

            if (po_gather_init(&sg)) {
                po_gather_wal(&sg, p, (size_t)len, 0, 0, 0, 0);
                po_span_w_seal(&sg.w);

                if (sg.w.n) {
                    po_sgraph gr;
                    po_tsum_set ts;

                    if (po_sgraph_init(&gr)) {
                        if (po_sgraph_build(&gr, sg.w.s, (uint32_t)sg.w.n)) {
                            uint32_t k;
                            for (k = 0; k < gr.n; k++) {
                                HV *e = newHV();
                                uint32_t cl = 0, el = 0;
                                const char *cp = (gr.e[k].caller == PO_SVC_UNKNOWN)
                                    ? NULL : po_intern_get(&sg.sym, gr.e[k].caller, &cl);
                                const char *ep =
                                    po_intern_get(&sg.sym, gr.e[k].callee, &el);
                                hv_stores(e, "caller", cp ? newSVpvn(cp, cl)
                                                          : newSVpvs("*"));
                                hv_stores(e, "callee", ep ? newSVpvn(ep, el)
                                                          : newSVpvs("unknown"));
                                hv_stores(e, "count",   po_u64_to_sv(gr.e[k].count));
                                hv_stores(e, "errors",  po_u64_to_sv(gr.e[k].errors));
                                hv_stores(e, "dur_max", po_u64_to_sv(gr.e[k].dur_max));
                                av_push(edges, newRV_noinc((SV *)e));
                            }
                        }
                        po_sgraph_free(&gr);
                    }

                    if (po_tsum_init(&ts)) {
                        if (po_tsum_build(&ts, sg.w.s, (uint32_t)sg.w.n))
                            ntraces = (IV)ts.n;
                        po_tsum_free(&ts);
                    }
                }
                po_gather_free(&sg);
            }
            hv_stores(s, "traces", newSViv(ntraces));
            hv_stores(s, "edges",  newRV_noinc((SV *)edges));
        }

        if (graph_ok) { po_sgraph_free(&g); po_intern_free(&names); }
        mXPUSHs(newRV_noinc((SV *)s));
    }

# Retention: delete WHOLE SEGMENTS, oldest first, until the store is under
# budget.
#
# DELETION IS BY UNLINK AND NEVER BY TRUNCATION. A reader mid-query keeps the
# copy it read; the directory entry goes immediately, which is what makes the
# space reclaimable rather than reclaimed. Truncating a file another process
# has mapped is how a reader gets a SIGBUS instead of an answer.
#
# The Perl this replaces listed the directory, stat-ed every entry, sorted in
# Perl and unlinked in a loop - which is four passes over a listing the C
# already has in one.
void
post_retain(SV *self, ...)
    PPCODE:
    {
        po_dir d;
        char dpbuf[PO_PATHMAX];
        const char *dp = dpbuf;
        const char *name;
        AV *names = newAV();
        SSize_t i, n;
        po_u64 bytes = 0, total = 0, budget_v = 0;
        IV keep = 0, ai;
        HV *empty;
        IV sealed = 0, deleted = 0;
        po_u64 freed = 0;
        HV *out = newHV();

        /* Named arguments off the stack: retain(bytes => N, keep => N). */
        for (ai = 1; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            if      (strEQ(k, "bytes")) (void)po_sv_to_u64(aTHX_ ST(ai + 1), &budget_v);
            else if (strEQ(k, "keep"))  keep = SvIV(ST(ai + 1));
        }

        if (!po_store_waldir(aTHX_ self, dpbuf, sizeof(dpbuf))) {
            empty = newHV();
            hv_stores(empty, "deleted", newSViv(0));
            hv_stores(empty, "freed",   newSViv(0));
            hv_stores(empty, "kept",    newSViv(0));
            hv_stores(empty, "bytes",   newSViv(0));
            mXPUSHs(newRV_noinc((SV *)empty));
            XSRETURN(1);
        }

        if (po_opendir(&d, dp)) {
            while ((name = po_readdir(&d))) {
                size_t nl = strlen(name);
                if (nl > 4 && memcmp(name + nl - 4, ".seg", 4) == 0)
                    av_push(names, newSVpv(name, 0));
            }
            po_closedir(&d);
        }

        /* OLDEST FIRST, and the name carries the sealing time - so this is
         * chronological without a stat per entry to ask. */
        sortsv(AvARRAY(names), (SSize_t)(av_len(names) + 1), Perl_sv_cmp);
        n = av_len(names) + 1;
        sealed = (IV)n;

        for (i = 0; i < n; i++) {
            SV **e = av_fetch(names, i, 0);
            char path[PO_PATHMAX];
            if (!e) continue;
            if (!po_path_join(path, sizeof(path), dp, SvPV_nolen(*e))) continue;
            bytes = 0;
            po_file_size(path, &bytes);
            total += bytes;
        }

        if (budget_v && total > budget_v) {
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(names, i, 0);
                char path[PO_PATHMAX], idx[PO_PATHMAX];
                size_t pl;
                if (total <= budget_v) break;
                if (sealed - deleted <= keep) break;
                if (!e) continue;
                if (!po_path_join(path, sizeof(path), dp, SvPV_nolen(*e))) continue;

                bytes = 0;
                po_file_size(path, &bytes);
                if (remove(path) != 0) continue;

                /* The sidecar goes with it. Leaving one behind is the other
                 * half of an interrupted pass, and `stats` counts those. */
                pl = strlen(path);
                memcpy(idx, path, pl + 1);
                memcpy(idx + pl - 4, ".idx", 5);
                remove(idx);

                total -= bytes;
                freed += bytes;
                deleted++;
            }
        }
        SvREFCNT_dec((SV *)names);

        hv_stores(out, "deleted", newSViv(deleted));
        hv_stores(out, "freed",   po_u64_to_sv(freed));
        hv_stores(out, "kept",    newSViv(sealed - deleted));
        hv_stores(out, "bytes",   po_u64_to_sv(total));
        mXPUSHs(newRV_noinc((SV *)out));
    }

# What the status screen shows.
#
# EVERY FIGURE COMES FROM THE SIDECARS RATHER THAN FROM A SCAN, so the page is
# cheap enough to leave open. The Perl this replaces parsed every sidecar into
# a Perl hash to add up eight integers and throw the rest away; this reads the
# numbers straight out of the bytes.
void
post_stats(SV *self)
    PPCODE:
    {
        po_dir d;
        char dpbuf[PO_PATHMAX];
        const char *dp = dpbuf;
        const char *name;
        HV *out = newHV();
        HV *svc = newHV();
        int have_dir;
        AV *segs = newAV(), *idxs = newAV();
        SSize_t i, n;
        IV segments = 0, wal_depth = 0, unindexed = 0, orphan = 0;
        po_u64 records = 0, bytes = 0, logs = 0, spans = 0,
               metrics = 0, errors = 0, traces = 0;

        have_dir = po_store_waldir(aTHX_ self, dpbuf, sizeof(dpbuf)) ? 1 : 0;
        if (have_dir && po_opendir(&d, dp)) {
            while ((name = po_readdir(&d))) {
                size_t nl = strlen(name);
                if (nl > 4 && memcmp(name + nl - 4, ".seg", 4) == 0)
                    av_push(segs, newSVpv(name, 0));
                else if (nl > 4 && memcmp(name + nl - 4, ".wal", 4) == 0)
                    av_push(segs, newSVpv(name, 0));
                else if (nl > 4 && memcmp(name + nl - 4, ".idx", 4) == 0)
                    av_push(idxs, newSVpv(name, 0));
            }
            po_closedir(&d);
        }

        /* An index with no segment is the other half of an interrupted
         * retention pass: a few hundred bytes rather than a few megabytes,
         * and a sign that something unlinked one of the pair and not the
         * other. Counted, because a store that quietly accumulates them is a
         * store nobody notices leaking. */
        n = av_len(idxs) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(idxs, i, 0);
            char path[PO_PATHMAX];
            size_t pl;
            if (!e) continue;
            if (!po_path_join(path, sizeof(path), dp, SvPV_nolen(*e))) continue;
            pl = strlen(path);
            memcpy(path + pl - 4, ".seg", 5);
            if (!po_file_size(path, NULL)) orphan++;
        }

        n = av_len(segs) + 1;
        for (i = 0; i < n; i++) {
            SV **e = av_fetch(segs, i, 0);
            char path[PO_PATHMAX], idx[PO_PATHMAX];
            size_t pl, nl;
            po_u64 sz = 0;
            po_idx_nums ix;
            const char *np;

            if (!e) continue;
            {
                STRLEN el;
                np = SvPV(*e, el);
                nl = (size_t)el;
            }
            if (!po_path_join(path, sizeof(path), dp, np)) continue;
            po_file_size(path, &sz);
            bytes += sz;

            /* A LIVE LOG IS COUNTED TOO, from its own frames. Counting only
             * the sealed segments made a receiver that had accepted ten
             * thousand records and not yet reached its seal threshold report
             * nothing at all - which reads as "no telemetry is arriving"
             * while every other screen shows it arriving. */
            if (nl > 4 && memcmp(np + nl - 4, ".wal", 4) == 0) {
                wal_depth++;
                if (po_wal_nums(path, &ix, svc)) {
                    records += ix.records;
                    logs    += ix.logs;
                    spans   += ix.spans;
                    metrics += ix.metrics;
                    errors  += ix.errors;
                }
                continue;
            }
            segments++;

            pl = strlen(path);
            memcpy(idx, path, pl + 1);
            memcpy(idx + pl - 4, ".idx", 5);

            /* A sealed segment with no summary is a seal that was
             * interrupted. It is still readable and still counted, and saying
             * so is the difference between a number that is low and a number
             * that is wrong. */
            if (!po_index_nums(idx, &ix, svc)) { unindexed++; continue; }
            records += ix.records;
            logs    += ix.logs;
            spans   += ix.spans;
            metrics += ix.metrics;
            errors  += ix.errors;
            traces  += ix.traces;
        }
        SvREFCNT_dec((SV *)segs);
        SvREFCNT_dec((SV *)idxs);

        hv_stores(out, "segments",     newSViv(segments));
        hv_stores(out, "wal_depth",    newSViv(wal_depth));
        hv_stores(out, "unindexed",    newSViv(unindexed));
        hv_stores(out, "orphan_index", newSViv(orphan));
        hv_stores(out, "records", po_u64_to_sv(records));
        hv_stores(out, "bytes",   po_u64_to_sv(bytes));
        hv_stores(out, "logs",    po_u64_to_sv(logs));
        hv_stores(out, "spans",   po_u64_to_sv(spans));
        hv_stores(out, "metrics", po_u64_to_sv(metrics));
        hv_stores(out, "errors",  po_u64_to_sv(errors));
        hv_stores(out, "traces",  po_u64_to_sv(traces));
        hv_stores(out, "services", newSViv((IV)HvUSEDKEYS(svc)));
        hv_stores(out, "service",  newRV_noinc((SV *)svc));

        /* A deleted segment a reader still holds open is still occupying the
         * disk and is invisible to du. This store cannot accumulate one: a
         * read copies the segment and lets go of it inside the call, so a
         * retention pass never runs against a live mapping. Reported anyway -
         * a design property nothing displays is one nobody can check. */
        {
            SV **md = hv_fetchs((HV *)SvRV(self), "mapped_deleted", 0);
            hv_stores(out, "mapped_deleted",
                      newSViv(md && SvOK(*md) ? SvIV(*md) : 0));
        }
        mXPUSHs(newRV_noinc((SV *)out));
    }

# The service graph, merged across every segment.
#
# A sealed segment answers from its sidecar - a read of a few hundred bytes
# ONE SPAN SET ACROSS EVERY FILE, ANALYSED ONCE.
#
# The obvious optimisation is to answer a sealed segment from its sidecar - a
# read of a few hundred bytes rather than a scan of its spans, which is the
# whole reason a summary is written at seal. It is also WRONG, and wrong in a
# way that looks like working:
#
# a graph derived from one file can only see the parents that are IN that
# file. A trace whose caller and callee were received by different workers, or
# landed either side of a seal, has each half summarised on its own - and a
# span whose parent is not present is attributed to the SYNTHETIC ROOT. The
# service map then draws every service as if traffic arrived at it from
# outside, which is exactly the topology it exists to disprove. In the demo
# that turned ninety-six `shop -> cards` calls into six.
#
# So the spans are gathered from every file first and the graph is built from
# all of them together. That is a scan, and the map is the screen that can
# afford one: it is looked at occasionally and it has to be right.
void
post_graph(SV *self, ...)
    PPCODE:
    {
        char dpbuf[PO_PATHMAX];
        const char *dp = dpbuf;
        po_u64 from = 0, to = PO_U64_MAX;
        int have_from = 0, have_to = 0;
        IV ai;
        HV *edges = newHV(), *svc = newHV();
        po_span_gather all;
        po_dir d;
        const char *name;
        AV *names = newAV();
        SSize_t i, n;
        HV *out = newHV();

        for (ai = 1; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            if      (strEQ(k, "from")) have_from = po_sv_to_u64(aTHX_ ST(ai+1), &from);
            else if (strEQ(k, "to"))   have_to   = po_sv_to_u64(aTHX_ ST(ai+1), &to);
        }

        if (!po_store_waldir(aTHX_ self, dpbuf, sizeof(dpbuf))) {
            hv_stores(out, "edges",    newRV_noinc((SV *)newAV()));
            hv_stores(out, "services", newRV_noinc((SV *)svc));
            SvREFCNT_dec((SV *)edges);
            SvREFCNT_dec((SV *)names);
            mXPUSHs(newRV_noinc((SV *)out));
            XSRETURN(1);
        }

        if (!po_gather_init(&all)) {
            hv_stores(out, "edges",    newRV_noinc((SV *)newAV()));
            hv_stores(out, "services", newRV_noinc((SV *)svc));
            SvREFCNT_dec((SV *)edges);
            SvREFCNT_dec((SV *)names);
            mXPUSHs(newRV_noinc((SV *)out));
            XSRETURN(1);
        }

        if (po_opendir(&d, dp)) {
            while ((name = po_readdir(&d))) {
                size_t nl = strlen(name);
                if (nl > 4 && (memcmp(name + nl - 4, ".seg", 4) == 0
                            || memcmp(name + nl - 4, ".wal", 4) == 0))
                    av_push(names, newSVpv(name, 0));
            }
            po_closedir(&d);
        }
        sortsv(AvARRAY(names), (SSize_t)(av_len(names) + 1), Perl_sv_cmp);
        n = av_len(names) + 1;

        for (i = 0; i < n; i++) {
            SV **e = av_fetch(names, i, 0);
            const char *np;
            STRLEN nl;
            char path[PO_PATHMAX];
            int sealed;

            if (!e) continue;
            np = SvPV(*e, nl);
            sealed = (nl > 4 && memcmp(np + nl - 4, ".seg", 4) == 0);
            (void)sealed;                 /* sealed or live, both are read */
            if (!po_path_join(path, sizeof(path), dp, np)) continue;

            {   /* THE SERVICE COUNTS ARE PER RECORD, not per span - a log
                 * line counts too - so they never come from the span set.
                 * A sealed file has them tallied in its sidecar; a live one
                 * is walked for them. Counting them from the spans as well
                 * is how a service with two records reported three. */
                if (sealed) {
                    char idx[PO_PATHMAX];
                    size_t pl = strlen(path);
                    memcpy(idx, path, pl + 1);
                    memcpy(idx + pl - 4, ".idx", 5);
                    po_graph_merge_services(aTHX_ idx, svc);
                }
                else {
                    po_idx_nums nums;
                    (void)po_wal_nums(path, &nums, svc);
                }
            }

            {   /* Every span into ONE set, so a parent in another file is
                 * still a parent. */
                size_t blen = 0;
                char *bytes = po_slurp(path, &blen);
                if (!bytes) continue;
                po_gather_wal(&all, bytes, blen, have_from, from, have_to, to);
                free(bytes);
            }
        }
        SvREFCNT_dec((SV *)names);

        {   /* The graph, built once over everything that was gathered. */
            po_sgraph sg;
            po_span_w_seal(&all.w);
            if (all.w.n && po_sgraph_init(&sg)) {
                if (po_sgraph_build(&sg, all.w.s, (uint32_t)all.w.n))
                    po_graph_merge_live(aTHX_ &sg, &all, edges, NULL);
                po_sgraph_free(&sg);
            }
            po_gather_free(&all);
        }

        {   /* Sorted, so two calls against the same store agree. */
            AV *out_edges = newAV();
            AV *keys = newAV();
            HE *he;
            SSize_t j, m;
            hv_iterinit(edges);
            while ((he = hv_iternext(edges)))
                av_push(keys, newSVsv(hv_iterkeysv(he)));
            sortsv(AvARRAY(keys), (SSize_t)(av_len(keys) + 1), Perl_sv_cmp);
            m = av_len(keys) + 1;
            for (j = 0; j < m; j++) {
                SV **k = av_fetch(keys, j, 0);
                STRLEN kl;
                const char *kp;
                SV **v;
                if (!k) continue;
                kp = SvPV(*k, kl);
                v = hv_fetch(edges, kp, (I32)kl, 0);
                if (v) av_push(out_edges, newSVsv(*v));
            }
            SvREFCNT_dec((SV *)keys);
            hv_stores(out, "edges", newRV_noinc((SV *)out_edges));
        }
        hv_stores(out, "services", newRV_noinc((SV *)svc));
        SvREFCNT_dec((SV *)edges);
        mXPUSHs(newRV_noinc((SV *)out));
    }

# The trace summaries in a window, slowest first. This is the SEARCH; one
# trace is assembled by trace_dir below.
void
post_traces(SV *self, ...)
    PPCODE:
    {
        po_span_gather g;
        po_tsum_set sums;
        char dpbuf[PO_PATHMAX];
        po_u64 from = 0, to = PO_U64_MAX, min_dur = 0, max_dur = 0;
        int have_from = 0, have_to = 0, errors_only = 0, have_max = 0;
        IV limit = 50, ai;
        const char *want_svc = NULL;
        STRLEN want_len = 0;
        const char *want_match = NULL;
        STRLEN match_len = 0;
        AV *out = newAV();
        HV *res = newHV();
        uint32_t k;
        IV kept = 0;

        for (ai = 1; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "from")) have_from = po_sv_to_u64(aTHX_ v, &from);
            else if (strEQ(k, "to"))   have_to   = po_sv_to_u64(aTHX_ v, &to);
            else if (strEQ(k, "min_duration")) (void)po_sv_to_u64(aTHX_ v, &min_dur);
            /* The other end of the same column. A zero MAXIMUM is a real
             * bound - it selects the instantaneous traces - so it cannot be
             * its own "unset", the way a zero minimum can. */
            else if (strEQ(k, "max_duration") && SvOK(v))
                have_max = po_sv_to_u64(aTHX_ v, &max_dur);
            else if (strEQ(k, "errors_only"))  errors_only = SvTRUE(v);
            else if (strEQ(k, "limit"))        limit = SvIV(v);
            else if (strEQ(k, "service") && SvOK(v)) want_svc = SvPV(v, want_len);
            else if (strEQ(k, "match") && SvOK(v)) {
                want_match = SvPV(v, match_len);
                if (!match_len) want_match = NULL;
            }
        }
        if (limit <= 0) limit = 50;

        if (!po_gather_init(&g)) croak("oom");
        if (po_store_waldir(aTHX_ self, dpbuf, sizeof(dpbuf)))
            po_gather_dir(aTHX_ dpbuf, &g, have_from, from, have_to, to);
        po_span_w_seal(&g.w);

        if (!g.w.n || !po_tsum_init(&sums)) {
            po_gather_free(&g);
            hv_stores(res, "traces", newRV_noinc((SV *)out));
            hv_stores(res, "spans", newSViv(0));
            hv_stores(res, "total", newSViv(0));
            mXPUSHs(newRV_noinc((SV *)res));
            XSRETURN(1);
        }
        if (!po_tsum_build(&sums, g.w.s, (uint32_t)g.w.n) || !po_tsum_index(&sums)) {
            po_tsum_free(&sums); po_gather_free(&g);
            croak("summaries");
        }

        /* WHICH FIFTY, and the answer is not "the first fifty".
         *
         * by_dur is ordinals into t sorted FASTEST first - the binary search
         * beside it depends on that - and this loop used to walk it from
         * index 0 while a comment here claimed the opposite. So the traces
         * screen showed the fifty quickest requests in the window, and
         * "slower than 100ms" with more than fifty matches showed the fifty
         * quickest of those: the right rows by the filter and the wrong end
         * of them, on the one screen whose whole purpose is finding the slow
         * ones.
         *
         * A maximum is the exception and walks forwards, because somebody who
         * asked for the fast ones wants the fast ones. */
        for (k = 0; k < sums.n && kept < limit; k++) {
            const po_tsummary *t =
                &sums.t[sums.by_dur[have_max ? k : sums.n - 1 - k]];
            HV *h;

            if (min_dur && t->dur_ns < min_dur) continue;
            if (have_max && t->dur_ns > max_dur) continue;
            if (errors_only && !t->errors) continue;
            if (want_svc) {
                uint32_t sl = 0;
                const char *sp = po_intern_get(&g.sym, t->root_service_sym, &sl);
                if (!sp || sl != (uint32_t)want_len
                    || memcmp(sp, want_svc, want_len) != 0) continue;
            }
            /* A SUBSTRING OF WHAT THE TRACE IS: its root span's name, or the
             * service that served it. "POST" finds every POST because the
             * span name is the method and the route pattern; "checkout"
             * finds the route; "cards" finds the service.
             *
             * Case-insensitive, because a search box is typed into rather
             * than copied from, and nobody types the method in capitals
             * twice. */
            if (want_match) {
                uint32_t nl2 = 0, sl2 = 0;
                const char *np2 = po_intern_get(&g.sym, t->root_name_sym, &nl2);
                const char *sp2 = po_intern_get(&g.sym, t->root_service_sym, &sl2);
                if (!po_substr_i(np2, nl2, want_match, match_len)
                 && !po_substr_i(sp2, sl2, want_match, match_len)) continue;
            }

            h = newHV();
            hv_stores(h, "trace_hi", po_u64_to_sv(t->trace_hi));
            hv_stores(h, "trace_lo", po_u64_to_sv(t->trace_lo));
            hv_stores(h, "duration", po_u64_to_sv(t->dur_ns));
            /* WHEN it happened, not only how long it took. A table can rank
             * traces by duration without this; a chart cannot place one
             * without it, and where the slow ones CLUSTER is the thing a
             * table of the fifty slowest cannot show. */
            hv_stores(h, "t",        po_u64_to_sv(t->start_ns));
            hv_stores(h, "spans",    newSVuv((UV)t->spans));
            hv_stores(h, "errors",   newSVuv((UV)t->errors));
            hv_stores(h, "service",  po_sym_sv(aTHX_ &g.sym, t->root_service_sym));
            hv_stores(h, "name",     po_sym_sv(aTHX_ &g.sym, t->root_name_sym));
            av_push(out, newRV_noinc((SV *)h));
            kept++;
        }

        hv_stores(res, "traces", newRV_noinc((SV *)out));
        hv_stores(res, "spans",  newSVuv((UV)g.w.n));
        hv_stores(res, "total",  newSVuv((UV)sums.n));
        po_tsum_free(&sums);
        po_gather_free(&g);
        mXPUSHs(newRV_noinc((SV *)res));
    }

# One trace, assembled: every span in TREE ORDER with its depth and its offset
# from the trace's start, which is what a waterfall needs and what the
# executor cannot produce, because a tree is not a row shape.
void
post_trace(SV *self, SV *hi_sv, SV *lo_sv, ...)
    PPCODE:
    {
        po_span_gather g;
        po_tree tr;
        char dpbuf[PO_PATHMAX];
        po_u64 from = 0, to = PO_U64_MAX, hi = 0, lo = 0;
        int have_from = 0, have_to = 0;
        IV ai;
        AV *out = newAV();
        HV *res = newHV();
        uint32_t i, first = 0, count = 0;
        po_u64 t0 = PO_U64_MAX, dur = 0;
        IV errors = 0;

        (void)po_sv_to_u64(aTHX_ hi_sv, &hi);
        (void)po_sv_to_u64(aTHX_ lo_sv, &lo);
        for (ai = 3; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            if      (strEQ(k, "from")) have_from = po_sv_to_u64(aTHX_ ST(ai+1), &from);
            else if (strEQ(k, "to"))   have_to   = po_sv_to_u64(aTHX_ ST(ai+1), &to);
        }

        if (!po_gather_init(&g)) croak("oom");
        if (po_store_waldir(aTHX_ self, dpbuf, sizeof(dpbuf)))
            po_gather_dir(aTHX_ dpbuf, &g, have_from, from, have_to, to);
        po_span_w_seal(&g.w);

        /* The spans of one trace are CONTIGUOUS after the seal, because the
         * seal sorts by (trace, start). So this is a scan for the run rather
         * than a filter over everything. */
        for (i = 0; i < g.w.n; i++) {
            if (g.w.s[i].trace_hi != hi || g.w.s[i].trace_lo != lo) continue;
            if (!count) first = i;
            count++;
        }
        if (!count) { po_gather_free(&g); XSRETURN_UNDEF; }

        for (i = first; i < first + count; i++) {
            po_u64 end = g.w.s[i].start_ns + g.w.s[i].dur_ns;
            if (g.w.s[i].start_ns < t0) t0 = g.w.s[i].start_ns;
            if (end - t0 > dur && end > t0) dur = end - t0;
            if (g.w.s[i].status == 2) errors++;
        }

        if (po_tree_build(&tr, g.w.s + first, count)) {
            /* Index order, which after the seal is (trace, start) - so the
             * waterfall comes out chronological. `depth` carries the nesting;
             * there is no separate ordering array and there does not need to
             * be one. */
            for (i = 0; i < tr.n; i++) {
                const po_span *sp = &g.w.s[first + i];
                HV *h = newHV();
                hv_stores(h, "span_id",  po_u64_to_sv(sp->span_id));
                hv_stores(h, "parent",   po_u64_to_sv(sp->parent_span_id));
                hv_stores(h, "depth",    newSViv((IV)tr.depth[i]));
                hv_stores(h, "name",     po_sym_sv(aTHX_ &g.sym, sp->name_sym));
                hv_stores(h, "service",  po_sym_sv(aTHX_ &g.sym, sp->service_sym));
                hv_stores(h, "start",    po_u64_to_sv(sp->start_ns));
                hv_stores(h, "offset",   po_u64_to_sv(po_ns_sub(sp->start_ns, t0)));
                hv_stores(h, "duration", po_u64_to_sv(sp->dur_ns));
                hv_stores(h, "status",   newSVuv((UV)sp->status));
                hv_stores(h, "kind",     newSVuv((UV)sp->kind));
                av_push(out, newRV_noinc((SV *)h));
            }
            hv_stores(res, "roots",   newSVuv((UV)tr.roots));
            hv_stores(res, "cycles",  newSVuv((UV)tr.cycles));
            hv_stores(res, "orphans", newSVuv((UV)tr.orphans));
            po_tree_free(&tr);
        }

        hv_stores(res, "trace_hi",   po_u64_to_sv(hi));
        hv_stores(res, "trace_lo",   po_u64_to_sv(lo));
        hv_stores(res, "spans",      newRV_noinc((SV *)out));
        hv_stores(res, "span_count", newSViv((IV)av_len(out) + 1));
        hv_stores(res, "duration",   po_u64_to_sv(dur));
        hv_stores(res, "t_min",      po_u64_to_sv(t0 == PO_U64_MAX ? 0 : t0));
        hv_stores(res, "errors",     newSViv(errors));
        po_gather_free(&g);
        mXPUSHs(newRV_noinc((SV *)res));
    }

# ---- the object's own paths ------------------------------------------------

# The live log this worker appends to.
#
# PER WORKER AND NEVER LOCKED, which is the decision the whole storage design
# rests on: the hot path takes no lock, and a leader-elected compactor turns
# sealed logs into shared segments later. The pid in the name is what makes
# that safe without one.
SV *
post_wal_path(SV *self)
    CODE:
    {
        char dir[PO_PATHMAX], path[PO_PATHMAX];
        char name[64];
        int n;
        if (!po_store_waldir(aTHX_ self, dir, sizeof(dir))) XSRETURN_UNDEF;
        po_mkpath(dir);
        n = snprintf(name, sizeof(name), "w%ld.wal", (long)po_getpid());
        if (n <= 0 || (size_t)n >= sizeof(name)) XSRETURN_UNDEF;
        if (!po_path_join(path, sizeof(path), dir, name)) XSRETURN_UNDEF;
        RETVAL = newSVpv(path, 0);
    }
    OUTPUT:
        RETVAL

SV *
post_wal_dir(SV *self)
    CODE:
    {
        char dir[PO_PATHMAX];
        if (!po_store_waldir(aTHX_ self, dir, sizeof(dir))) XSRETURN_UNDEF;
        RETVAL = newSVpv(dir, 0);
    }
    OUTPUT:
        RETVAL

# Every file the read side can see, sealed and live.
void
post_segments(SV *self)
    PPCODE:
    {
        char dir[PO_PATHMAX];
        SV *arg;
        if (!po_store_waldir(aTHX_ self, dir, sizeof(dir))) {
            mXPUSHs(newRV_noinc((SV *)newAV()));
            XSRETURN(1);
        }
        arg = sv_2mortal(newSVpv(dir, 0));
        PUSHMARK(SP);
        XPUSHs(arg);
        PUTBACK;
        {
            int n = call_pv("Punk::Observe::Store::scan_dir", G_SCALAR);
            SPAGAIN;
            if (n < 1) { PUSHs(sv_2mortal(newRV_noinc((SV *)newAV()))); }
        }
    }

# Seal the live log and write its summary beside it.
#
# A SEALED LOG IS THE UNIT OF THE READ SIDE. The live one is being appended to
# by the worker that owns it, so a reader gets whatever complete frames exist
# at the moment it looks - correct, but not stable, and not something to build
# an index over. After the rename the file never changes again, so its index
# can never be stale.
void
post_seal(SV *self)
    PPCODE:
    {
        char dir[PO_PATHMAX], live[PO_PATHMAX], seg[PO_PATHMAX], idx[PO_PATHMAX];
        char name[96];
        size_t blen = 0;
        char *bytes;
        po_wal_replay rp;
        HV *h;
        SV **f;
        IV counter = 0;
        int n;

        if (!SvROK(self) || SvTYPE(SvRV(self)) != SVt_PVHV) XSRETURN_UNDEF;
        h = (HV *)SvRV(self);
        if (!po_store_waldir(aTHX_ self, dir, sizeof(dir))) XSRETURN_UNDEF;
        {
            char wn[64];
            int wl = snprintf(wn, sizeof(wn), "w%ld.wal", (long)po_getpid());
            if (wl <= 0) XSRETURN_UNDEF;
            if (!po_path_join(live, sizeof(live), dir, wn)) XSRETURN_UNDEF;
        }

        bytes = po_slurp(live, &blen);
        if (!bytes || !blen) { free(bytes); XSRETURN_UNDEF; }

        po_wal_replay_buf(bytes, blen, &rp, NULL, NULL);
        if (!rp.records) { free(bytes); XSRETURN_UNDEF; }

        /* The trailer goes on the file, not on the copy in hand: the summary
         * below is computed from the bytes as they were, which is the same
         * set of records the trailer is about. */
        {
            SV *args[2];
            dSP;
            ENTER; SAVETMPS; PUSHMARK(SP);
            args[0] = sv_2mortal(newSVpv(live, 0));
            args[1] = sv_2mortal(po_u64_to_sv(rp.records));
            XPUSHs(args[0]); XPUSHs(args[1]);
            PUTBACK;
            call_pv("Punk::Observe::WAL::seal", G_SCALAR | G_DISCARD);
            FREETMPS; LEAVE;
        }

        /* The name carries the worker and the sealing time, so two workers
         * sealing in the same second still land on different files and the
         * read side never has to break a tie. */
        f = hv_fetchs(h, "sealed", 0);
        if (f && SvOK(*f)) counter = SvIV(*f);
        n = snprintf(name, sizeof(name), "s%ld-%ld-%ld",
                     (long)time(NULL), (long)po_getpid(), (long)counter);
        if (n <= 0 || (size_t)n + 5 >= sizeof(name)) { free(bytes); XSRETURN_UNDEF; }
        hv_stores(h, "sealed", newSViv(counter + 1));

        {
            char base[96];
            memcpy(base, name, (size_t)n + 1);
            memcpy(base + n, ".seg", 5);
            if (!po_path_join(seg, sizeof(seg), dir, base)) { free(bytes); XSRETURN_UNDEF; }
            memcpy(base + n, ".idx", 5);
            if (!po_path_join(idx, sizeof(idx), dir, base)) { free(bytes); XSRETURN_UNDEF; }
        }

        if (!po_seal_rename(live, seg)) { free(bytes); XSRETURN_UNDEF; }

        {   /* the summary, from the bytes as they were before the trailer */
            SV *sum;
            dSP;
            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpvn(bytes, blen)));
            PUTBACK;
            if (call_pv("Punk::Observe::Store::summarise", G_SCALAR) == 1) {
                SPAGAIN;
                sum = POPs;
                if (SvROK(sum) && SvTYPE(SvRV(sum)) == SVt_PVHV)
                    (void)po_index_write(aTHX_ idx, (HV *)SvRV(sum));
                PUTBACK;
            }
            FREETMPS; LEAVE;
        }
        free(bytes);

        hv_stores(h, "wal_bytes", newSViv(0));
        SPAGAIN;
        mXPUSHs(newSVpv(seg, 0));
    }

# Records from every segment whose time span the range allows.
#
# A SEALED SEGMENT IS SKIPPED FROM ITS SIDECAR, so a query over the last five
# minutes does not open a file holding yesterday. A live log has no sidecar -
# it is still being written - so it is always read; that is bounded by the
# seal threshold rather than by hope.
#
# The cross-segment merge is here too. Each segment comes back sorted, so what
# used to be a Perl sort over everything is a merge of sorted runs, and the
# comparison is on integers rather than on decimal strings.
void
post_records(SV *self, ...)
    PPCODE:
    {
        AV *out = newAV();
        HV *meta = newHV();
        po_u64 from = 0, to = PO_U64_MAX, limit = 0, trace_hi = 0, trace_lo = 0;
        int have_from = 0, have_to = 0, kind = 0, as_rows = 0, have_trace = 0;
        IV ai;

        for (ai = 1; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "from") && SvOK(v)) have_from = po_sv_to_u64(aTHX_ v, &from);
            else if (strEQ(k, "to")   && SvOK(v)) have_to   = po_sv_to_u64(aTHX_ v, &to);
            else if (strEQ(k, "kind") && SvOK(v)) kind = (int)SvIV(v);
            else if (strEQ(k, "limit")&& SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &limit);
            else if (strEQ(k, "rows")) as_rows = SvTRUE(v);
            else if (strEQ(k, "trace_hi") && SvOK(v))
                have_trace |= po_sv_to_u64(aTHX_ v, &trace_hi);
            else if (strEQ(k, "trace_lo") && SvOK(v))
                have_trace |= po_sv_to_u64(aTHX_ v, &trace_lo);
        }
        if (!limit) {
            SV **f = hv_fetchs((HV *)SvRV(self), "max_rows", 0);
            limit = (f && SvOK(*f)) ? (po_u64)SvUV(*f) : 500000;
        }

        po_records_run(aTHX_ self, from, have_from, to, have_to,
                       kind, limit, as_rows, trace_hi, trace_lo, have_trace,
                       out, meta);
        mXPUSHs(newRV_noinc((SV *)out));
        mXPUSHs(newRV_noinc((SV *)meta));
    }

# One record in the shape the executor reads.
#
# `records` and `rows` build this during the scan and never call here; this is
# for a caller that has a record already - the record view of a single row,
# say - and wants the other shape without going back to the log.
#
# The two differ in exactly two places and both are load-bearing: the kind is
# a name rather than a number, and `service` is lifted out of the attributes
# because every query filters on it and no query should have to know it lives
# there.
SV *
post_row(SV *class, SV *rec)
    CODE:
    {
        HV *in, *out;
        SV **f;
        const char *kind = "log";
        static const char *KEYS[] = {
            "t", "duration", "severity", "status", "value",
            "trace_hi", "trace_lo", "span_id", "parent_id", "span_kind"
        };
        int i;

        PERL_UNUSED_VAR(class);
        if (!SvROK(rec) || SvTYPE(SvRV(rec)) != SVt_PVHV)
            croak("Punk::Observe::Store::row: expected a record hashref");
        in  = (HV *)SvRV(rec);
        out = newHV();

        if ((f = hv_fetchs(in, "kind", 0)) && SvOK(*f)) {
            IV k = SvIV(*f);
            kind = (k == PO_METRIC) ? "metric" : (k == PO_SPAN) ? "span" : "log";
        }
        hv_stores(out, "kind", newSVpv(kind, 0));

        for (i = 0; i < 10; i++) {
            f = hv_fetch(in, KEYS[i], (I32)strlen(KEYS[i]), 0);
            hv_store(out, KEYS[i], (I32)strlen(KEYS[i]),
                     f ? newSVsv(*f) : newSV(0), 0);
        }

        f = hv_fetchs(in, "body", 0);
        hv_stores(out, "body", (f && SvOK(*f)) ? newSVsv(*f) : newSVpvs(""));

        f = hv_fetchs(in, "attrs", 0);
        if (f && SvROK(*f) && SvTYPE(SvRV(*f)) == SVt_PVHV) {
            HV *at = (HV *)SvRV(*f);
            SV **svc = hv_fetchs(at, "service.name", 0);
            hv_stores(out, "attrs", newSVsv(*f));
            hv_stores(out, "service",
                      (svc && SvOK(*svc) && SvCUR(*svc))
                          ? newSVsv(*svc) : newSVpvs("unknown"));
        }
        else {
            hv_stores(out, "attrs", newRV_noinc((SV *)newHV()));
            hv_stores(out, "service", newSVpvs("unknown"));
        }

        RETVAL = newRV_noinc((SV *)out);
    }
    OUTPUT:
        RETVAL

# ---- the object -----------------------------------------------------------

SV *
post_new(SV *class, ...)
    CODE:
    {
        HV *self = newHV();
        IV ai;
        const char *tenant = "default";
        STRLEN tlen = 7;
        po_u64 seal_bytes = 8 * 1024 * 1024, max_rows = 500000;
        SV *dir = NULL;

        for (ai = 1; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "dir")) dir = v;
            else if (strEQ(k, "tenant") && SvOK(v) && SvCUR(v))
                tenant = SvPV(v, tlen);
            else if (strEQ(k, "seal_bytes") && SvTRUE(v))
                (void)po_sv_to_u64(aTHX_ v, &seal_bytes);
            else if (strEQ(k, "max_rows") && SvTRUE(v))
                (void)po_sv_to_u64(aTHX_ v, &max_rows);
        }

        hv_stores(self, "dir",        dir ? newSVsv(dir) : newSV(0));
        hv_stores(self, "tenant",     newSVpvn(tenant, tlen));
        hv_stores(self, "seal_bytes", po_u64_to_sv(seal_bytes));
        hv_stores(self, "max_rows",   po_u64_to_sv(max_rows));
        /* undef, not zero: a worker that restarts inherits whatever its
         * predecessor left on disk, and the first seal_if_full is what reads
         * it. Zero here would seal a full log one batch late, every restart. */
        hv_stores(self, "wal_bytes",  newSV(0));
        hv_stores(self, "sealed",     newSViv(0));

        RETVAL = sv_bless(newRV_noinc((SV *)self), gv_stashsv(class, GV_ADD));
    }
    OUTPUT:
        RETVAL

SV *
post_tenant(SV *self)
    ALIAS:
        dir = 1
    CODE:
    {
        HV *h;
        SV **f;
        if (!SvROK(self) || SvTYPE(SvRV(self)) != SVt_PVHV) XSRETURN_UNDEF;
        h = (HV *)SvRV(self);
        f = ix ? hv_fetchs(h, "dir", 0) : hv_fetchs(h, "tenant", 0);
        RETVAL = (f && SvOK(*f)) ? newSVsv(*f) : newSV(0);
    }
    OUTPUT:
        RETVAL

# Called after every append. Returns true when the log was sealed.
int
post_seal_if_full(SV *self, ...)
    CODE:
    {
        HV *h;
        SV **f;
        po_u64 added = 0, have = 0, threshold = 0;
        char dir[PO_PATHMAX];

        if (!SvROK(self) || SvTYPE(SvRV(self)) != SVt_PVHV) XSRETURN_IV(0);
        h = (HV *)SvRV(self);
        if (items > 1 && SvOK(ST(1))) (void)po_sv_to_u64(aTHX_ ST(1), &added);
        if (!po_store_waldir(aTHX_ self, dir, sizeof(dir))) XSRETURN_IV(0);

        /* READ THE SIZE FROM DISK ONCE per worker and then track it, rather
         * than stat-ing per batch. A worker that restarts inherits whatever
         * its predecessor left, which is why this is not simply zero. */
        f = hv_fetchs(h, "wal_bytes", 0);
        if (!f || !SvOK(*f)) {
            char live[PO_PATHMAX];
            char wn[64];
            po_u64 sz = 0;
            int wl = snprintf(wn, sizeof(wn), "w%ld.wal", (long)po_getpid());
            if (wl > 0 && po_path_join(live, sizeof(live), dir, wn))
                po_file_size(live, &sz);
            have = sz;
        }
        else (void)po_sv_to_u64(aTHX_ *f, &have);

        have += added;
        hv_stores(h, "wal_bytes", po_u64_to_sv(have));

        f = hv_fetchs(h, "seal_bytes", 0);
        if (f && SvOK(*f)) (void)po_sv_to_u64(aTHX_ *f, &threshold);
        if (!threshold || have < threshold) XSRETURN_IV(0);

        {   /* seal() is the method beside this one */
            SV *sealed;
            int ok;
            dSP;
            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(self);
            PUTBACK;
            ok = call_method("seal", G_SCALAR);
            SPAGAIN;
            sealed = ok ? POPs : &PL_sv_undef;
            RETVAL = (SvOK(sealed) && SvTRUE(sealed)) ? 1 : 0;
            PUTBACK;
            FREETMPS; LEAVE;
        }
    }
    OUTPUT:
        RETVAL

# The executor's shape. `records` builds it during the scan, so this is that
# call with a flag rather than a second pass and a sub call per row.
void
post_rows(SV *self, ...)
    PPCODE:
    {
        AV *out = newAV();
        HV *meta = newHV();
        po_u64 from = 0, to = PO_U64_MAX, limit = 0, trace_hi = 0, trace_lo = 0;
        int have_from = 0, have_to = 0, kind = 0, have_trace = 0;
        IV ai;

        for (ai = 1; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "from") && SvOK(v)) have_from = po_sv_to_u64(aTHX_ v, &from);
            else if (strEQ(k, "to")   && SvOK(v)) have_to   = po_sv_to_u64(aTHX_ v, &to);
            else if (strEQ(k, "kind") && SvOK(v)) kind = (int)SvIV(v);
            else if (strEQ(k, "limit")&& SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &limit);
            else if (strEQ(k, "trace_hi") && SvOK(v))
                have_trace |= po_sv_to_u64(aTHX_ v, &trace_hi);
            else if (strEQ(k, "trace_lo") && SvOK(v))
                have_trace |= po_sv_to_u64(aTHX_ v, &trace_lo);
        }
        if (!limit) {
            SV **f = hv_fetchs((HV *)SvRV(self), "max_rows", 0);
            limit = (f && SvOK(*f)) ? (po_u64)SvUV(*f) : 500000;
        }

        /* The same scan with the row shape asked for, not a second pass. */
        po_records_run(aTHX_ self, from, have_from, to, have_to,
                       kind, limit, 1, trace_hi, trace_lo, have_trace,
                       out, meta);
        mXPUSHs(newRV_noinc((SV *)out));
        mXPUSHs(newRV_noinc((SV *)meta));
    }

# Parse, plan and run one query against the store.
#
# The result is the executor's, unchanged, plus `store` describing what was
# read to produce it. A caller that renders the rows without reading the
# metadata is rendering a partial answer as a complete one.
void
post_query(SV *self, SV *q, ...)
    PPCODE:
    {
        po_query pq;
        po_plan plan;
        po_pushdown pd;
        STRLEN qlen;
        const char *qp = SvPV(q, qlen);
        po_u64 from = 0, to = PO_U64_MAX, limit = 0, hard_max = 0,
               step = 0, max_rows = 0, dflt = 500000;
        int have_from = 0, have_to = 0, kind = 0;
        IV ai;
        AV *rows = newAV();
        HV *meta = newHV();
        HV *res;
        SV **f;

        for (ai = 2; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "from") && SvOK(v)) have_from = po_sv_to_u64(aTHX_ v, &from);
            else if (strEQ(k, "to")   && SvOK(v)) have_to   = po_sv_to_u64(aTHX_ v, &to);
            else if (strEQ(k, "limit")    && SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &limit);
            else if (strEQ(k, "hard_max") && SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &hard_max);
            else if (strEQ(k, "step")     && SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &step);
            else if (strEQ(k, "max_rows") && SvOK(v)) (void)po_sv_to_u64(aTHX_ v, &max_rows);
        }
        f = hv_fetchs((HV *)SvRV(self), "max_rows", 0);
        if (f && SvOK(*f)) (void)po_sv_to_u64(aTHX_ *f, &dflt);
        if (!limit)    limit    = dflt;
        if (!hard_max) hard_max = dflt;
        if (!max_rows) max_rows = dflt;

        if (!po_parse(&pq, qp, (size_t)qlen)) {
            res = newHV();
            hv_stores(res, "ok",    newSViv(0));
            hv_stores(res, "stage", newSVpvs("parse"));
            hv_stores(res, "error", newSVpv(pq.err, 0));
            hv_stores(res, "offset", newSViv((IV)pq.err_off));
            SvREFCNT_dec((SV *)rows); SvREFCNT_dec((SV *)meta);
            mXPUSHs(newRV_noinc((SV *)res));
            XSRETURN(1);
        }

        /* The source decides which records to read. `trace` and `spans` are
         * two views of the same records - one assembled, one not. */
        switch (pq.source) {
            case PO_SRC_METRIC: kind = PO_METRIC; break;
            case PO_SRC_LOG:    kind = PO_LOG;    break;
            default:            kind = PO_SPAN;   break;
        }

        /* WHAT THE QUERY PROVES BEFORE ANYTHING IS READ. A range it proved
         * narrows the read; predicates that cannot be satisfied stop it. */
        if (po_plan_build(&plan, &pq, NULL)) {
            po_pushdown_build(&pd, &plan);
            if (po_pushdown_empty(&pd)) {
                HV *m = newHV(), *st = newHV();
                res = newHV();
                hv_stores(m, "scanned_rows", newSViv(0));
                hv_stores(m, "scanned_bytes", newSViv(0));
                hv_stores(m, "truncated", newSViv(0));
                hv_stores(m, "degraded",  newSViv(0));
                hv_stores(m, "exact",     newSViv(1));
                hv_stores(m, "steps",     newSViv(0));
                hv_stores(st, "scanned", newSViv(0));
                hv_stores(st, "skipped", newSViv(0));
                hv_stores(st, "files",   newSViv(0));
                hv_stores(st, "degraded", newSViv(0));
                hv_stores(st, "truncated", newSViv(0));
                hv_stores(st, "empty",   newSViv(1));
                hv_stores(res, "ok",     newSViv(1));
                hv_stores(res, "shape",  newSVpvs("rows"));
                hv_stores(res, "rows",   newRV_noinc((SV *)rows));
                hv_stores(res, "groups", newRV_noinc((SV *)newAV()));
                hv_stores(res, "meta",   newRV_noinc((SV *)m));
                hv_stores(res, "store",  newRV_noinc((SV *)st));
                SvREFCNT_dec((SV *)meta);
                po_query_free(&pq);
                mXPUSHs(newRV_noinc((SV *)res));
                XSRETURN(1);
            }
            if (pd.time_bounded) {
                if (!have_from || pd.from > from) { from = pd.from; have_from = 1; }
                if (!have_to   || pd.to   < to)   { to   = pd.to;   have_to   = 1; }
            }
        }
        po_query_free(&pq);

        po_records_run(aTHX_ self, from, have_from, to, have_to,
                       kind, limit, 1, 0, 0, 0, rows, meta);

        {   /* the executor, over the rows just read */
            SV *rv = NULL;
            HV *opt = newHV();
            int n;

            hv_stores(opt, "max_rows",       po_u64_to_sv(max_rows));
            hv_stores(opt, "rows_available", newSViv((IV)av_len(rows) + 1));
            hv_stores(opt, "hard_max",       po_u64_to_sv(hard_max));
            hv_stores(opt, "step",           po_u64_to_sv(step));

            /* No dSP here. In a PPCODE body `SP` is already xsubpp's, and a
             * second one shadows it - the call refreshes the shadow, the
             * XSUB's own pointer stays stale, and everything pushed
             * afterwards lands nowhere. That is why `rows` returned an empty
             * list before it was written this way. */
            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVsv(q)));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)rows)));
            XPUSHs(sv_2mortal(newRV_noinc((SV *)opt)));
            PUTBACK;
            n = call_pv("Punk::Observe::Exec::run", G_SCALAR);
            SPAGAIN;
            rv = n ? SvREFCNT_inc(POPs) : NULL;
            PUTBACK;
            FREETMPS; LEAVE;
            SPAGAIN;

            if (!rv || !SvROK(rv) || SvTYPE(SvRV(rv)) != SVt_PVHV) {
                if (rv) SvREFCNT_dec(rv);
                res = newHV();
                hv_stores(res, "ok",    newSViv(0));
                hv_stores(res, "stage", newSVpvs("plan"));
                hv_stores(res, "error", newSVpvs("the query could not be run"));
                SvREFCNT_dec((SV *)meta);
                mXPUSHs(newRV_noinc((SV *)res));
                XSRETURN(1);
            }
            res = (HV *)SvRV(rv);
            hv_stores(res, "store", newRV_inc((SV *)meta));

            /* A range that skipped a segment and a scan that hit its ceiling
             * are both reasons an answer is short, and the page says so
             * either way. */
            {
                SV **rm = hv_fetchs(res, "meta", 0);
                if (rm && SvROK(*rm) && SvTYPE(SvRV(*rm)) == SVt_PVHV) {
                    HV *m = (HV *)SvRV(*rm);
                    static const char *K[] = { "truncated", "degraded" };
                    int j;
                    for (j = 0; j < 2; j++) {
                        SV **a = hv_fetch(m, K[j], (I32)strlen(K[j]), 1);
                        SV **b = hv_fetch(meta, K[j], (I32)strlen(K[j]), 0);
                        if (a && b && !SvTRUE(*a) && SvTRUE(*b)) sv_setsv(*a, *b);
                    }
                }
            }
            SvREFCNT_dec((SV *)meta);
            mXPUSHs(rv);
        }
    }
