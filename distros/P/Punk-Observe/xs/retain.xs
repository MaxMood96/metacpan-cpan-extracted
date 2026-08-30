MODULE = Punk::Observe   PACKAGE = Punk::Observe::Retain   PREFIX = por_

# --- the merge --------------------------------------------------------------

# Merge several sorted runs of (t, series, kind) and report the order plus how
# many duplicates were collapsed.
void
por_merge(SV *runs)
    PPCODE:
        {
            po_merge m;
            AV *av;
            SSize_t i, n;
            po_rec **bufs;
            AV *out = newAV();

            if (!SvROK(runs)) croak("arrayref required");
            av = (AV *)SvRV(runs);
            n = av_len(av) + 1;
            Newxz(bufs, n ? n : 1, po_rec *);
            po_merge_init(&m);

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                AV *inner;
                SSize_t j, cnt;
                if (!e || !SvROK(*e)) continue;
                inner = (AV *)SvRV(*e);
                cnt = av_len(inner) + 1;
                Newxz(bufs[i], cnt ? cnt : 1, po_rec);
                for (j = 0; j < cnt; j++) {
                    SV **r = av_fetch(inner, j, 0);
                    HV *h; SV **f;
                    po_u64 v = 0;
                    if (!r || !SvROK(*r)) continue;
                    h = (HV *)SvRV(*r);
                    po_rec_zero(&bufs[i][j]);
                    if ((f = hv_fetchs(h, "t", 0)) && po_sv_to_u64(aTHX_ *f, &v))
                        bufs[i][j].t_unix_nano = v;
                    if ((f = hv_fetchs(h, "series", 0)) && po_sv_to_u64(aTHX_ *f, &v))
                        bufs[i][j].series = v;
                    if ((f = hv_fetchs(h, "kind", 0)))
                        bufs[i][j].kind = (uint8_t)SvUV(*f);
                }
                po_merge_add_run(&m, bufs[i], (size_t)cnt);
            }

            {
                const po_rec *r;
                while ((r = po_merge_next(&m))) {
                    HV *h = newHV();
                    hv_stores(h, "t",      po_u64_to_sv(r->t_unix_nano));
                    hv_stores(h, "series", po_u64_to_sv(r->series));
                    av_push(out, newRV_noinc((SV *)h));
                }
            }
            {
                HV *res = newHV();
                hv_stores(res, "records",    newRV_noinc((SV *)out));
                hv_stores(res, "emitted",    po_u64_to_sv(m.emitted));
                hv_stores(res, "duplicates", po_u64_to_sv(m.duplicates));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            for (i = 0; i < n; i++) Safefree(bufs[i]);
            Safefree(bufs);
        }

# --- rollups ----------------------------------------------------------------

# Fold raw points into a 5m tier, promote to 1h, and answer aggregates from
# each. Everything a test needs in one call.
void
por_rollup(SV *points, SV *agg)
    PPCODE:
        {
            po_rollup t5, t1h;
            AV *av;
            SSize_t i, n;
            int a = (int)SvIV(agg);
            double v5 = 0, v1 = 0;
            int ok5, ok1;

            if (!SvROK(points)) croak("arrayref required");
            av = (AV *)SvRV(points);
            n = av_len(av) + 1;

            if (!po_rollup_init(&t5, PO_TIER_5M)) croak("oom");
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *h; SV **f;
                po_u64 t = 0;
                double val = 0;
                int reset = 0;
                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                if ((f = hv_fetchs(h, "t", 0)))     (void)po_sv_to_u64(aTHX_ *f, &t);
                if ((f = hv_fetchs(h, "v", 0)))     val = SvNV(*f);
                if ((f = hv_fetchs(h, "reset", 0))) reset = (int)SvIV(*f);
                po_rollup_add(&t5, t, val, reset);
            }
            if (!po_rollup_promote(&t5, &t1h, PO_TIER_1H)) {
                po_rollup_free(&t5); croak("promote");
            }

            ok5 = po_rollup_agg(&t5,  a, &v5);
            ok1 = po_rollup_agg(&t1h, a, &v1);

            {
                HV *res = newHV();
                AV *b5 = newAV();
                uint32_t k;
                for (k = 0; k < t5.n; k++) {
                    HV *h = newHV();
                    hv_stores(h, "t",     po_u64_to_sv(t5.p[k].t));
                    hv_stores(h, "count", po_u64_to_sv(t5.p[k].count));
                    hv_stores(h, "sum",   newSVnv((NV)t5.p[k].sum));
                    hv_stores(h, "min",   newSVnv((NV)t5.p[k].min));
                    hv_stores(h, "max",   newSVnv((NV)t5.p[k].max));
                    hv_stores(h, "last",  newSVnv((NV)t5.p[k].last));
                    hv_stores(h, "resets", newSViv(t5.p[k].resets));
                    av_push(b5, newRV_noinc((SV *)h));
                }
                hv_stores(res, "buckets_5m", newRV_noinc((SV *)b5));
                hv_stores(res, "n_5m",  newSVuv((UV)t5.n));
                hv_stores(res, "n_1h",  newSVuv((UV)t1h.n));
                hv_stores(res, "ok_5m", newSViv(ok5));
                hv_stores(res, "ok_1h", newSViv(ok1));
                if (ok5) hv_stores(res, "value_5m", newSVnv((NV)v5));
                if (ok1) hv_stores(res, "value_1h", newSVnv((NV)v1));
                if (!ok5) hv_stores(res, "refusal", newSVpv(po_rollup_refusal(a), 0));
                hv_stores(res, "resets_5m", newSViv(po_rollup_resets(&t5)));
                hv_stores(res, "resets_1h", newSViv(po_rollup_resets(&t1h)));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_rollup_free(&t5);
            po_rollup_free(&t1h);
        }

# --- retention --------------------------------------------------------------

void
por_sweep(SV *paths, SV *cutoff, ...)
    PPCODE:
        {
            po_retain r;
            AV *av;
            SSize_t i, n;
            po_u64 cut = 0;
            uint32_t marked;
            /* A DRY RUN IS THE MARK WITHOUT THE SWEEP. The mark already reads
             * every footer and decides; skipping only the unlink means the
             * numbers a --dry-run prints are the numbers the real run would
             * act on, not an estimate produced by different code. */
            int dry = items > 2 && SvTRUE(ST(2));

            (void)po_sv_to_u64(aTHX_ cutoff, &cut);
            if (!SvROK(paths)) croak("arrayref required");
            av = (AV *)SvRV(paths);
            n = av_len(av) + 1;
            if (!po_retain_init(&r)) croak("oom");

            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                if (e) po_retain_add(&r, SvPV_nolen(*e));
            }
            marked = po_retain_mark(&r, cut);
            if (!dry) po_retain_sweep(&r);

            {
                HV *res = newHV();
                hv_stores(res, "considered", newSVuv((UV)r.n));
                hv_stores(res, "marked",     newSVuv((UV)marked));
                hv_stores(res, "unlinked",   newSVuv((UV)r.unlinked));
                hv_stores(res, "kept",       newSVuv((UV)r.kept));
                hv_stores(res, "bytes_freed", po_u64_to_sv(r.bytes_freed));
                /* MUST be zero. ftruncate on a mapped segment is SIGBUS. */
                hv_stores(res, "truncate_calls", newSVuv((UV)r.truncate_calls));
                mXPUSHs(newRV_noinc((SV *)res));
            }
            po_retain_free(&r);
        }

# Open a segment, keep the mapping, and report whether it still reads
# correctly after its name is unlinked underneath.
void
por_read_through_unlink(SV *path)
    PPCODE:
        {
            po_seg_r s;
            STRLEN plen;
            const char *p = SvPV(path, plen);
            HV *res = newHV();
            po_u64 before = 0, after = 0;
            size_t i;

            if (!po_seg_open(&s, p)) {
                hv_stores(res, "opened", newSViv(0));
                mXPUSHs(newRV_noinc((SV *)res));
                XSRETURN(1);
            }
            hv_stores(res, "opened", newSViv(1));

            for (i = 0; i < s.n; i++) before += s.rec[i].t_unix_nano;

            /* Delete the NAME while the mapping is held. */
            hv_stores(res, "unlinked", newSViv(unlink(p) == 0 ? 1 : 0));

            /* And read every record again, through the same mapping. On POSIX
             * this is defined and correct; with ftruncate it would be SIGBUS. */
            for (i = 0; i < s.n; i++) after += s.rec[i].t_unix_nano;

            hv_stores(res, "records", po_u64_to_sv((po_u64)s.n));
            hv_stores(res, "sum_before", po_u64_to_sv(before));
            hv_stores(res, "sum_after",  po_u64_to_sv(after));
            hv_stores(res, "same", newSViv(before == after ? 1 : 0));
            po_seg_close(&s);
            mXPUSHs(newRV_noinc((SV *)res));
        }

# --- generations ------------------------------------------------------------

void
por_generations(SV *ops)
    PPCODE:
        {
            po_gen_table t;
            AV *av;
            SSize_t i, n;
            AV *busy = newAV();

            memset(&t, 0, sizeof(t));
            if (!SvROK(ops)) croak("arrayref required");
            av = (AV *)SvRV(ops);
            n = av_len(av) + 1;
            for (i = 0; i + 1 < n; i += 2) {
                SV **op = av_fetch(av, i, 0);
                SV **g  = av_fetch(av, i + 1, 0);
                po_u64 gen = 0;
                STRLEN ol;
                const char *o;
                if (!op || !g) break;
                o = SvPV(*op, ol);
                (void)po_sv_to_u64(aTHX_ *g, &gen);
                if      (ol == 7 && memcmp(o, "acquire", 7) == 0) po_gen_acquire(&t, gen);
                else if (ol == 7 && memcmp(o, "release", 7) == 0) po_gen_release(&t, gen);
                else if (ol == 4 && memcmp(o, "busy", 4) == 0)
                    av_push(busy, newSViv(po_gen_busy(&t, gen)));
            }
            mXPUSHs(newRV_noinc((SV *)busy));
        }

int
por_block_removable(SV *segments, SV *expired_all)
    CODE:
        RETVAL = po_block_removable((uint32_t)SvUV(segments), (int)SvIV(expired_all));
    OUTPUT:
        RETVAL

# --- the window, as an operator writes it ------------------------------------
#
# "30d" into nanoseconds, against the query language's OWN unit table - the
# same po_dur_unit the lexer uses - so the two cannot disagree about what a
# week is, and there is no month here for the reason po_lex.h gives.
#
# A WINDOW TOO LARGE TO REPRESENT IS REFUSED, NEVER WRAPPED, and that is the
# one that had to be caught rather than documented: the cutoff is `now - keep`
# in unsigned nanoseconds, so a keep past the top comes back round as a cutoff
# of NOW, which marks every segment in the store and deletes the lot. Refusing
# looks like a typo caught at boot; wrapping looks like an empty store on
# Monday.
SV *
por_parse_keep(SV *str)
    CODE:
    {
        STRLEN sl = 0;
        const char *sp = SvOK(str) ? SvPV(str, sl) : "";
        size_t i = 0, ds, de, us;
        int dot = 0;
        po_u64 unit, whole = 0, ns;
        double frac = 0;

        RETVAL = &PL_sv_undef;
        while (i < sl && (sp[i] == ' ' || sp[i] == '\t')) i++;
        ds = i;
        while (i < sl && sp[i] >= '0' && sp[i] <= '9') i++;
        if (i == ds) goto out;                       /* no digits at all */
        de = i;
        if (i < sl && sp[i] == '.') {
            size_t fs;
            dot = 1; i++;
            fs = i;
            while (i < sl && sp[i] >= '0' && sp[i] <= '9') i++;
            if (i == fs) goto out;
            {   /* the fraction, as a double: it only ever scales a unit */
                double d = 0, s = 0.1;
                size_t k;
                for (k = fs; k < i; k++) { d += (sp[k] - '0') * s; s /= 10; }
                frac = d;
            }
        }
        while (i < sl && (sp[i] == ' ' || sp[i] == '\t')) i++;   /* "30 d" */
        us = i;
        while (i < sl && sp[i] >= 'a' && sp[i] <= 'z') i++;
        if (i == us) goto out;                       /* no unit */
        unit = po_dur_unit(sp + us, i - us);
        if (!unit) goto out;
        while (i < sl && (sp[i] == ' ' || sp[i] == '\t')) i++;
        if (i != sl) goto out;                       /* trailing rubbish */

        {   /* The integer part in u64, refusing the multiply that would wrap
             * rather than letting it come out the top. */
            size_t k;
            for (k = ds; k < de; k++) {
                if (whole > (PO_U64_MAX - (po_u64)(sp[k] - '0')) / 10) goto out;
                whole = whole * 10 + (po_u64)(sp[k] - '0');
            }
            if (whole && unit > PO_U64_MAX / whole) goto out;
            ns = whole * unit;
            if (dot) {
                double add = frac * (double)unit;
                if (add > (double)(PO_U64_MAX - ns)) goto out;
                ns += (po_u64)(add + 0.5);
            }
        }
        RETVAL = po_u64_to_sv(ns);
    out: ;
    }
    OUTPUT:
        RETVAL

# --- logs whose worker is gone -----------------------------------------------
#
# adopt_orphans(store => $s, grace_s => 600, now => $t, dry_run => 0)
#
# Retention considers SEALED segments, and the live log is deliberately never
# touched - a worker owns the descriptor it appends to. A log left by a worker
# that DIED is neither: never indexed, never expired, never counted against a
# byte budget, and every restart leaves another. Measured on a demo store
# after a day: 261MB across 127 files, none of which `keep` could reach.
#
# SEALED, NOT DELETED. Its records are usually inside the retention window,
# and deleting them would be retention destroying what `keep` promised to
# hold. Sealing puts the log into the ordinary lifecycle: it gains a sidecar,
# queries prune it, and the next sweep expires it on the same t_max rule.
#
# TWO INDEPENDENT PROOFS THAT NOBODY OWNS IT, because sealing a log somebody
# is still appending to renames the file under their descriptor and lets them
# write records past the seal trailer:
#
#   * the owning process is gone. The pid is in the file name, and kill(0)
#     answers for it - EPERM means it EXISTS and is somebody else's, which
#     counts as alive. The mistake to avoid is reading "not mine" as "dead".
#   * the file has not been written for grace_s. A live worker appends
#     constantly, so a stale log is unowned. This covers what a pid check
#     cannot: a recycled pid now belonging to something else.
#
# Both must hold. A recycled pid makes this SKIP a log it could have
# reclaimed, which costs disk; the reverse would cost data.
SV *
por_adopt_orphans(...)
    CODE:
    {
        HV *out = newHV();
        SV *store = NULL;
        IV grace = 600, dry = 0, ai;
        po_u64 now = 0;
        int have_now = 0;
        IV seen = 0, adopted = 0, skipped_live = 0, skipped_recent = 0,
           failed = 0;
        po_u64 bytes = 0;
        char dir[PO_PATHMAX];
        SV *dsv;

        for (ai = 0; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "store"))   store = v;
            else if (strEQ(k, "grace_s") && SvOK(v)) grace = SvIV(v);
            else if (strEQ(k, "dry_run")) dry = SvTRUE(v) ? 1 : 0;
            else if (strEQ(k, "now") && SvOK(v)) {
                now = (po_u64)SvNV(v); have_now = 1;
            }
        }
        if (!store || !SvOK(store))
            croak("adopt_orphans needs a store");
        if (!have_now) now = (po_u64)time(NULL);

        dsv = por_call_str(aTHX_ store, "wal_dir");
        if (!dsv) goto emit;
        {
            STRLEN dl = 0;
            const char *dp = SvPV(dsv, dl);
            if (dl >= sizeof(dir)) { SvREFCNT_dec(dsv); goto emit; }
            memcpy(dir, dp, dl);
            dir[dl] = '\0';
        }
        SvREFCNT_dec(dsv);

        {
            po_dir d;
            const char *name;
            if (!po_opendir(&d, dir)) goto emit;
            while ((name = po_readdir(&d))) {
                char path[PO_PATHMAX];
                long pid;
                po_u64 mtime = 0, size = 0;
                size_t nl = strlen(name);

                if (nl < 6 || name[0] != 'w') continue;
                if (memcmp(name + nl - 4, ".wal", 4) != 0) continue;
                {   /* w<digits>.wal, and nothing else */
                    size_t k;
                    for (k = 1; k < nl - 4; k++)
                        if (name[k] < '0' || name[k] > '9') break;
                    if (k != nl - 4) continue;
                }
                pid = atol(name + 1);
                if (pid <= 0) continue;
                if (pid == (long)po_getpid()) continue;   /* our own live log */
                seen++;

                if (!po_path_join(path, sizeof(path), dir, name)) continue;
                if (!por_stat(path, &size, &mtime)) continue;

                if ((po_i64)mtime > (po_i64)now - (po_i64)grace) {
                    skipped_recent++;
                    continue;
                }
                if (por_pid_alive((int)pid)) { skipped_live++; continue; }

                /* DRY RUN TAKES EVERY DECISION AND SKIPS ONLY THE SEAL, which
                 * is what dry_run means for `pass`. Counting the seal instead
                 * of the decision made a dry run report nothing to do on a
                 * store with a hundred and twenty-seven reclaimable logs. */
                if (dry) { adopted++; bytes += size; continue; }

                {
                    SV *seg = por_call_seal(aTHX_ store, path);
                    if (seg) { adopted++; bytes += size; SvREFCNT_dec(seg); }
                    else failed++;
                }
            }
            po_closedir(&d);
        }

    emit:
        hv_stores(out, "seen",           newSViv(seen));
        hv_stores(out, "adopted",        newSViv(adopted));
        hv_stores(out, "bytes",          po_u64_to_sv(bytes));
        hv_stores(out, "skipped_live",   newSViv(skipped_live));
        hv_stores(out, "skipped_recent", newSViv(skipped_recent));
        hv_stores(out, "failed",         newSViv(failed));
        RETVAL = newRV_noinc((SV *)out);
    }
    OUTPUT:
        RETVAL

# --- one retention pass ------------------------------------------------------
#
# Adopt, mark, sweep, and take the orphaned sidecars with it.
#
# Deletion is by whole segment, keyed on the data's END time: a segment whose
# newest record is older than the cutoff goes, and one still holding anything
# inside the window stays whole. The sweep never truncates - a truncated
# segment is SIGBUS for every reader mapping it - and a reader holding a
# mapping keeps reading the unlinked file to the end. Both are proven by
# t/0082-retention.t; this orchestrates.
#
# EXPIRY IS DECIDED FROM THE SIDECAR SUMMARIES rather than by opening each
# segment: the seal writes t_min and t_max beside every one, which is the same
# span a query prunes on. Keyed on t_max deliberately - keying on t_min would
# delete a segment still holding data inside the window - and a segment whose
# sidecar cannot be read is KEPT and counted, because deleting on an unknown
# age is deletion.
SV *
por_pass(...)
    CODE:
    {
        HV *out = newHV();
        SV *store = NULL, *segs = NULL;
        SV *keep_sv = NULL, *bytes_sv = NULL;
        IV dry = 0, ai;
        po_u64 keep = 0, now, cutoff;
        IV considered = 0, marked = 0, unlinked = 0, kept = 0,
           unknown_kept = 0, orphan_idx = 0, adopted = 0;
        po_u64 freed = 0, adopted_bytes = 0;
        char dir[PO_PATHMAX];
        int have_dir = 0;

        for (ai = 0; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "store"))   store = v;
            else if (strEQ(k, "keep_ns")) keep_sv = v;
            else if (strEQ(k, "bytes"))   bytes_sv = SvTRUE(v) ? v : NULL;
            else if (strEQ(k, "dry_run")) dry = SvTRUE(v) ? 1 : 0;
        }
        if (!store || !SvOK(store)) croak("pass needs a store");

        /* NO DEFAULT WINDOW, AND NOT A NUMBER-ISH ONE EITHER. A retention job
         * with a silently defaulted window is a deletion job, and a keep that
         * is not plain digits is a typo somebody would rather hear about at
         * boot than discover as an empty store. */
        if (!keep_sv || !SvOK(keep_sv) || !por_all_digits(aTHX_ keep_sv))
            croak("pass needs keep_ns - a retention job with no window is a "
                  "deletion job");
        (void)po_sv_to_u64(aTHX_ keep_sv, &keep);

        now    = po_now_ns();
        cutoff = po_ns_sub(now, keep);

        /* BEFORE THE SWEEP, so a log adopted now is expired by this same pass
         * if it is old enough rather than waiting an hour for the next. */
        {
            SV *ad = por_adopt(aTHX_ store, dry);
            if (ad) {
                HV *h = (HV *)SvRV(ad);
                SV **f = hv_fetchs(h, "adopted", 0);
                if (f && SvOK(*f)) adopted = SvIV(*f);
                f = hv_fetchs(h, "bytes", 0);
                if (f && SvOK(*f)) (void)po_sv_to_u64(aTHX_ *f, &adopted_bytes);
                SvREFCNT_dec(ad);
            }
        }

        segs = por_call_str(aTHX_ store, "segments");
        if (segs && SvROK(segs) && SvTYPE(SvRV(segs)) == SVt_PVAV) {
            AV *av = (AV *)SvRV(segs);
            SSize_t i, n = av_len(av) + 1;
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *seg;
                SV **f, **idx;
                po_u64 t_max = 0, sbytes = 0;
                const char *path;
                STRLEN pl = 0;

                if (!e || !SvROK(*e) || SvTYPE(SvRV(*e)) != SVt_PVHV) continue;
                seg = (HV *)SvRV(*e);
                f = hv_fetchs(seg, "sealed", 0);
                if (!f || !SvTRUE(*f)) continue;
                considered++;

                idx = hv_fetchs(seg, "index", 0);
                f = (idx && SvROK(*idx) && SvTYPE(SvRV(*idx)) == SVt_PVHV)
                  ? hv_fetchs((HV *)SvRV(*idx), "t_max", 0) : NULL;
                if (!f || !SvOK(*f)) { kept++; unknown_kept++; continue; }
                (void)po_sv_to_u64(aTHX_ *f, &t_max);
                if (t_max >= cutoff) { kept++; continue; }

                marked++;
                if (dry) continue;

                f = hv_fetchs(seg, "path", 0);
                if (!f || !SvOK(*f)) continue;
                path = SvPV(*f, pl);
                f = hv_fetchs(seg, "bytes", 0);
                if (f && SvOK(*f)) (void)po_sv_to_u64(aTHX_ *f, &sbytes);

                if (po_unlink(path) == 0) {
                    char ip[PO_PATHMAX];
                    unlinked++;
                    freed += sbytes;
                    /* The sidecar goes with it: an index naming a segment
                     * that is gone is what `orphan_index` on the status page
                     * counts, and leaving one behind here would create the
                     * very thing the next block cleans up. */
                    if (pl > 4 && pl < sizeof(ip)
                        && memcmp(path + pl - 4, ".seg", 4) == 0) {
                        memcpy(ip, path, pl - 4);
                        memcpy(ip + pl - 4, ".idx", 5);
                        (void)po_unlink(ip);
                    }
                }
            }
        }
        if (segs) SvREFCNT_dec(segs);

        if (!dry) {
            SV *dsv = por_call_str(aTHX_ store, "wal_dir");
            if (dsv) {
                STRLEN dl = 0;
                const char *dp = SvPV(dsv, dl);
                if (dl < sizeof(dir)) {
                    memcpy(dir, dp, dl); dir[dl] = '\0'; have_dir = 1;
                }
                SvREFCNT_dec(dsv);
            }
        }
        if (have_dir) {
            /* A SIDECAR WHOSE SEGMENT IS GONE, from a crash between the two
             * unlinks above. Harmless but not free, and it is counted so an
             * operator can see it happening rather than wonder. */
            po_dir d;
            const char *name;
            if (po_opendir(&d, dir)) {
                while ((name = po_readdir(&d))) {
                    char ip[PO_PATHMAX], sp2[PO_PATHMAX];
                    size_t nl = strlen(name);
                    if (nl < 5 || memcmp(name + nl - 4, ".idx", 4) != 0)
                        continue;
                    if (!po_path_join(sp2, sizeof(sp2), dir, name)) continue;
                    memcpy(ip, sp2, strlen(sp2) + 1);
                    {
                        size_t sl2 = strlen(sp2);
                        memcpy(sp2 + sl2 - 4, ".seg", 5);
                    }
                    if (po_file_exists(sp2)) continue;
                    if (po_unlink(ip) == 0) orphan_idx++;
                }
                po_closedir(&d);
            }
        }

        hv_stores(out, "considered",   newSViv(considered));
        hv_stores(out, "marked",       newSViv(marked));
        hv_stores(out, "unlinked",     newSViv(unlinked));
        hv_stores(out, "kept",         newSViv(kept));
        hv_stores(out, "unknown_kept", newSViv(unknown_kept));
        hv_stores(out, "truncate_calls", newSViv(0));
        hv_stores(out, "orphan_idx_removed", newSViv(orphan_idx));
        hv_stores(out, "adopted",       newSViv(adopted));
        hv_stores(out, "adopted_bytes", po_u64_to_sv(adopted_bytes));
        hv_stores(out, "cutoff",       po_u64_to_sv(cutoff));

        /* THE BYTE BUDGET, over and above the window: a store still past it
         * after the time sweep loses its oldest segments even inside the
         * window, because a full disk loses everything rather than the oldest
         * hour. Never under dry_run - the store's own pass does the deleting
         * and has no rehearsal. */
        if (bytes_sv) {
            if (!por_all_digits(aTHX_ bytes_sv)) {
                STRLEN bl = 0;
                const char *bp = SvPV(bytes_sv, bl);
                SvREFCNT_dec((SV *)out);
                croak("pass bytes '%.*s' is not a byte count", (int)bl, bp);
            }
            if (dry) hv_stores(out, "budget_skipped", newSVpvs("dry_run"));
            else {
                SV *b = por_call_retain(aTHX_ store, bytes_sv);
                IV bd = 0; po_u64 bf = 0;
                if (b && SvROK(b) && SvTYPE(SvRV(b)) == SVt_PVHV) {
                    HV *bh = (HV *)SvRV(b);
                    SV **f = hv_fetchs(bh, "deleted", 0);
                    if (f && SvOK(*f)) bd = SvIV(*f);
                    f = hv_fetchs(bh, "freed", 0);
                    if (f && SvOK(*f)) (void)po_sv_to_u64(aTHX_ *f, &bf);
                    f = hv_fetchs(bh, "bytes", 0);
                    if (f && SvOK(*f)) hv_stores(out, "bytes", newSVsv(*f));
                }
                if (b) SvREFCNT_dec(b);
                hv_stores(out, "budget_deleted", newSViv(bd));
                hv_stores(out, "budget_freed",   po_u64_to_sv(bf));
                unlinked += bd;
                freed    += bf;
                hv_stores(out, "unlinked", newSViv(unlinked));
            }
        }
        hv_stores(out, "bytes_freed", po_u64_to_sv(freed));
        RETVAL = newRV_noinc((SV *)out);
    }
    OUTPUT:
        RETVAL

# --- the scheduled forms -----------------------------------------------------

# cron_task(store => $s, keep_ns => $ns, bytes => $b, owner => $$, ...)
#
# The closure a host schedules when it would rather declare its own cron than
# let the plugin register one. Takes the queue, runs one pass under the leader
# lease, returns how many segments went.
SV *
por_cron_task(...)
    CODE:
    {
        HV *o = newHV();
        CV *cv;
        SV *keep = NULL;
        IV ai, lease = 30, owner = -1;

        for (ai = 0; ai + 1 < items; ai += 2) {
            const char *k = SvPV_nolen(ST(ai));
            SV *v = ST(ai + 1);
            if      (strEQ(k, "store"))   hv_stores(o, "store", newSVsv(v));
            else if (strEQ(k, "keep_ns")) { keep = v; hv_stores(o, "keep_ns", newSVsv(v)); }
            else if (strEQ(k, "bytes") && SvTRUE(v)) hv_stores(o, "bytes", newSVsv(v));
            else if (strEQ(k, "lease_seconds") && SvTRUE(v)) lease = SvIV(v);
            else if (strEQ(k, "owner") && SvOK(v) && por_all_digits(aTHX_ v))
                owner = SvIV(v);
        }
        if (!keep || !SvOK(keep)) {
            SvREFCNT_dec((SV *)o);
            croak("cron_task needs keep_ns");
        }
        hv_stores(o, "lease", newSViv(lease));
        hv_stores(o, "owner", newSViv(owner >= 0 ? owner : (IV)po_getpid()));

        cv = newXS(NULL, por_cron_thunk, __FILE__);
        /* The options ride on the CV as magic, which is also what frees them:
         * the closure owns its captures the way a Perl one would. */
        sv_magicext((SV *)cv, sv_2mortal(newRV_noinc((SV *)o)),
                    PERL_MAGIC_ext, &por_cron_vtbl, NULL, 0);
        RETVAL = newRV_inc((SV *)cv);
    }
    OUTPUT:
        RETVAL

# retain_job($job, $class) - the Punk::Queue task body.
#
# Recovers the plugin's state from the app class in the args, because a task
# body receives its job and its arguments and nothing else, and the worker
# compiled the same application class the server did.
SV *
por_retain_job(SV *job, SV *class)
    CODE:
    {
        HV *out = newHV();
        SV *st = NULL, *q = NULL, *store = NULL, *keep = NULL, *bytes = NULL;
        SV *res = NULL, *err = NULL;
        IV owner = (IV)po_getpid();
        int locked;

        st = por_state_for(aTHX_ class);
        if (!st) {
            STRLEN cl = 0;
            const char *cp = SvOK(class) ? SvPV(class, cl) : "";
            SvREFCNT_dec((SV *)out);
            croak("Punk::Observe::Retain: no Observe plugin state for %.*s - "
                  "is the worker running the same application class as the "
                  "server?", (int)cl, cp);
        }

        q = por_call_str(aTHX_ job, "queue_object");
        if (!q) { SvREFCNT_dec(st); SvREFCNT_dec((SV *)out);
                  croak("Punk::Observe::Retain: the job has no queue"); }

        locked = por_q_lock(aTHX_ q, "observe.retain", 60, owner);
        if (!locked) {
            hv_stores(out, "skipped", newSVpvs("lock"));
            SvREFCNT_dec(q); SvREFCNT_dec(st);
            RETVAL = newRV_noinc((SV *)out);
            goto done;
        }

        por_job_opts(aTHX_ st, &store, &keep, &bytes);
        {
            dSP;
            int n;
            ENTER; SAVETMPS; PUSHMARK(SP);
            XPUSHs(sv_2mortal(newSVpvs("store")));
            XPUSHs(store ? store : &PL_sv_undef);
            XPUSHs(sv_2mortal(newSVpvs("keep_ns")));
            XPUSHs(keep ? keep : &PL_sv_undef);
            if (bytes) { XPUSHs(sv_2mortal(newSVpvs("bytes"))); XPUSHs(bytes); }
            PUTBACK;
            n = call_pv("Punk::Observe::Retain::pass", G_SCALAR | G_EVAL);
            SPAGAIN;
            res = n ? SvREFCNT_inc(POPs) : NULL;
            PUTBACK;
            FREETMPS; LEAVE;
            if (SvTRUE(ERRSV)) err = newSVsv(ERRSV);
        }

        /* THE LEASE IS RELEASED WHETHER OR NOT THE PASS THREW, or the next
         * occurrence waits out a lease nobody is holding. */
        {
            SV *a[2];
            a[0] = sv_2mortal(newSVpvs("observe.retain"));
            a[1] = sv_2mortal(newSViv(owner));
            por_q_call(aTHX_ q, "unlock", a, 2);
        }
        SvREFCNT_dec(q);
        SvREFCNT_dec(st);

        if (err) {
            if (res) SvREFCNT_dec(res);
            SvREFCNT_dec((SV *)out);
            sv_setsv(ERRSV, err);
            SvREFCNT_dec(err);
            croak(NULL);
        }

        if (res && SvROK(res) && SvTYPE(SvRV(res)) == SVt_PVHV) {
            HV *r = (HV *)SvRV(res);
            static const char *K[] = { "unlinked", "kept", "bytes_freed",
                                       "unknown_kept", NULL };
            int i;
            for (i = 0; K[i]; i++) {
                SV **f = hv_fetch(r, K[i], (I32)strlen(K[i]), 0);
                hv_store(out, K[i], (I32)strlen(K[i]),
                         f ? newSVsv(*f) : newSViv(0), 0);
            }
        }
        if (res) SvREFCNT_dec(res);
        RETVAL = newRV_noinc((SV *)out);
    done: ;
    }
    OUTPUT:
        RETVAL
