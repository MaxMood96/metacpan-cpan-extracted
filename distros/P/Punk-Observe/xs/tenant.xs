MODULE = Punk::Observe   PACKAGE = Punk::Observe::Tenant   PREFIX = potn_

void
potn_check(SV *id)
    PPCODE:
        {
            STRLEN l;
            const char *p = SvPV(id, l);
            int rc = po_tenant_check(p, (size_t)l);
            HV *res = newHV();
            hv_stores(res, "ok",     newSViv(rc == PO_TN_OK));
            hv_stores(res, "code",   newSViv(rc));
            hv_stores(res, "reason", newSVpv(po_tn_reason(rc), 0));
            mXPUSHs(newRV_noinc((SV *)res));
        }

# Resolve through the seam. `resolver` is a coderef, or undef for the
# constant - and BOTH go through the same validation, which is the whole
# point of the seam existing.
void
potn_resolve(SV *fixed, SV *resolver)
    PPCODE:
        {
            po_tenant_cfg cfg;
            char out[PO_TENANT_MAX + 1];
            size_t len = 0;
            STRLEN fl;
            const char *f = SvOK(fixed) ? SvPV(fixed, fl) : (fl = 0, "");
            int rc;
            HV *res = newHV();

            rc = po_tenant_set_fixed(&cfg, fl ? f : NULL, (size_t)fl);
            if (rc != PO_TN_OK) {
                hv_stores(res, "ok",     newSViv(0));
                hv_stores(res, "code",   newSViv(rc));
                hv_stores(res, "reason", newSVpv(po_tn_reason(rc), 0));
                hv_stores(res, "at",     newSVpvs("configuration"));
                mXPUSHs(newRV_noinc((SV *)res));
                XSRETURN(1);
            }

            if (SvROK(resolver) && SvTYPE(SvRV(resolver)) == SVt_PVCV) {
                /* The callback runs in Perl and hands back a string; the C
                 * seam validates whatever it produced. Host code that returns
                 * `../other` is a bug to CATCH, not to trust.
                 *
                 * The answer is copied but NOT TRUNCATED. Shortening an
                 * over-long id to fit would turn an invalid tenant into a
                 * valid one silently, which is the same class of mistake as
                 * accepting it - and the first version of this did exactly
                 * that. Anything past the buffer is too long by definition,
                 * so the length alone answers it without the bytes. */
                char buf[PO_TENANT_MAX + 2];
                po_tn_sv tn;
                SV *ret;
                int forced = 0;
                dSP;
                tn.p = NULL; tn.len = 0;
                ENTER; SAVETMPS; PUSHMARK(SP); PUTBACK;
                call_sv(resolver, G_SCALAR);
                SPAGAIN;
                ret = POPs;
                if (SvOK(ret)) {
                    STRLEN rl;
                    const char *rp = SvPV(ret, rl);
                    if (rl > sizeof(buf) - 1) forced = PO_TN_TOO_LONG;
                    else {
                        memcpy(buf, rp, rl);
                        buf[rl] = '\0';
                        tn.p = buf; tn.len = (size_t)rl;
                    }
                }
                PUTBACK; FREETMPS; LEAVE;
                /* The return stack moved under call_sv; re-fetch before this
                 * XSUB pushes anything of its own. */
                SPAGAIN;
                if (forced) rc = forced;
                else {
                    po_tenant_set_fn(&cfg, po_tn_cb, &tn);
                    rc = po_tenant_resolve(&cfg, out, sizeof(out), &len);
                }
            }
            else rc = po_tenant_resolve(&cfg, out, sizeof(out), &len);
            hv_stores(res, "ok",     newSViv(rc == PO_TN_OK));
            hv_stores(res, "code",   newSViv(rc));
            hv_stores(res, "reason", newSVpv(po_tn_reason(rc), 0));
            if (rc == PO_TN_OK) hv_stores(res, "tenant", newSVpvn(out, len));
            mXPUSHs(newRV_noinc((SV *)res));
        }

SV *
potn_hash(SV *id)
    CODE:
        {
            STRLEN l;
            const char *p = SvPV(id, l);
            RETVAL = newSVuv((UV)po_tenant_hash(p, (size_t)l));
        }
    OUTPUT:
        RETVAL

int
potn_owns(SV *header_hash, SV *id)
    CODE:
        {
            STRLEN l;
            const char *p = SvPV(id, l);
            RETVAL = po_tenant_owns((uint32_t)SvUV(header_hash), p, (size_t)l);
        }
    OUTPUT:
        RETVAL

MODULE = Punk::Observe   PACKAGE = Punk::Observe::Key   PREFIX = poky_

void
poky_bearer(SV *hdr)
    PPCODE:
        {
            STRLEN l;
            const char *p = SvOK(hdr) ? SvPV(hdr, l) : (l = 0, NULL);
            const char *tok = NULL;
            size_t tl = 0;
            if (p && po_bearer(p, (size_t)l, &tok, &tl))
                mXPUSHs(newSVpvn(tok, tl));
            else XSRETURN_UNDEF;
        }

# Build a ring from (name => token) pairs, then check a presented header.
void
poky_check(SV *keys, SV *hdr, SV *revoke)
    PPCODE:
        {
            po_keyring r;
            AV *av;
            SSize_t i, n;
            const char *tok = NULL, *name = NULL;
            size_t tl = 0, nl = 0;
            STRLEN hl;
            const char *h;
            int rc;
            HV *res = newHV();

            po_keyring_init(&r);
            if (SvROK(keys) && SvTYPE(SvRV(keys)) == SVt_PVAV) {
                av = (AV *)SvRV(keys);
                n = av_len(av) + 1;
                for (i = 0; i + 1 < n; i += 2) {
                    SV **k = av_fetch(av, i, 0);
                    SV **v = av_fetch(av, i + 1, 0);
                    STRLEN kl, vl;
                    const char *kp, *vp;
                    if (!k || !v) break;
                    kp = SvPV(*k, kl);
                    vp = SvPV(*v, vl);
                    po_keyring_add(&r, kp, (size_t)kl, vp, (size_t)vl);
                }
            }
            if (SvOK(revoke)) {
                STRLEN rl;
                const char *rp = SvPV(revoke, rl);
                po_keyring_revoke(&r, rp, (size_t)rl);
            }

            if (SvOK(hdr)) {
                h = SvPV(hdr, hl);
                if (!po_bearer(h, (size_t)hl, &tok, &tl)) { tok = NULL; tl = 0; }
            }

            rc = po_keyring_check(&r, tok, tl, &name, &nl);
            hv_stores(res, "ok",       newSViv(rc == PO_AUTH_OK));
            hv_stores(res, "code",     newSViv(rc));
            hv_stores(res, "required", newSViv(r.required));
            if (rc == PO_AUTH_OK && name)
                hv_stores(res, "name", newSVpvn(name, nl));
            mXPUSHs(newRV_noinc((SV *)res));
        }

# The comparison itself, so a test can drive it directly.
int
poky_ct_eq(SV *a, SV *b)
    CODE:
        {
            po_u64 ah, al, bh, bl;
            STRLEN la, lb;
            const char *pa = SvPV(a, la);
            const char *pb = SvPV(b, lb);
            po_key_hash(pa, (size_t)la, &ah, &al);
            po_key_hash(pb, (size_t)lb, &bh, &bl);
            RETVAL = po_ct_eq128(ah, al, bh, bl);
        }
    OUTPUT:
        RETVAL

MODULE = Punk::Observe   PACKAGE = Punk::Observe::Limit   PREFIX = poli_

# The ingest rate, over a sequence of batches with the clock moved between
# them. Returns what was accepted per batch, which is what becomes the OTLP
# partial success.
void
poli_rate(SV *cfg, SV *batches)
    PPCODE:
        {
            po_rate_cfg c;
            po_rate_win w;
            po_rate_local local;
            HV *ch;
            SV **f;
            AV *av;
            SSize_t i, n;
            po_u64 max_rec = 0, max_bytes = 0;
            AV *out = newAV();
            HV *res = newHV();

            if (!SvROK(cfg) || SvTYPE(SvRV(cfg)) != SVt_PVHV)
                croak("cfg must be a hashref");
            ch = (HV *)SvRV(cfg);
            if ((f = hv_fetchs(ch, "records", 0))) (void)po_sv_to_u64(aTHX_ *f, &max_rec);
            if ((f = hv_fetchs(ch, "bytes", 0)))   (void)po_sv_to_u64(aTHX_ *f, &max_bytes);
            po_rate_cfg_init(&c, max_rec, max_bytes);
            po_rate_local_bind(&local, &w);

            if (!SvROK(batches)) croak("batches must be an arrayref");
            av = (AV *)SvRV(batches);
            n = av_len(av) + 1;
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *b; SV **g;
                po_u64 at = 0, rec = 0, bytes = 0, got;
                if (!e || !SvROK(*e)) continue;
                b = (HV *)SvRV(*e);
                if ((g = hv_fetchs(b, "at", 0))) {
                    (void)po_sv_to_u64(aTHX_ *g, &at);
                    po_clock_freeze(at);
                }
                if ((g = hv_fetchs(b, "records", 0))) (void)po_sv_to_u64(aTHX_ *g, &rec);
                if ((g = hv_fetchs(b, "bytes", 0)))   (void)po_sv_to_u64(aTHX_ *g, &bytes);
                got = po_rate_admit(&c, &w, rec, bytes);
                {
                    HV *r = newHV();
                    hv_stores(r, "offered",  po_u64_to_sv(rec));
                    hv_stores(r, "accepted", po_u64_to_sv(got));
                    hv_stores(r, "rejected", po_u64_to_sv(rec - got));
                    av_push(out, newRV_noinc((SV *)r));
                }
            }
            po_clock_real();
            hv_stores(res, "batches",  newRV_noinc((SV *)out));
            hv_stores(res, "rejected", po_u64_to_sv(local.rejected));
            mXPUSHs(newRV_noinc((SV *)res));
        }

# The storage budget: which blocks survive, and how far back that reaches.
void
poli_storage(SV *blocks, SV *budget)
    PPCODE:
        {
            po_blk_size *b;
            AV *av;
            SSize_t i, n;
            po_u64 bud = 0, kept = 0, horizon = 0;
            uint32_t keep;
            HV *res = newHV();

            if (!SvROK(blocks)) croak("blocks must be an arrayref");
            (void)po_sv_to_u64(aTHX_ budget, &bud);
            av = (AV *)SvRV(blocks);
            n = av_len(av) + 1;
            Newxz(b, n ? n : 1, po_blk_size);
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                HV *h; SV **g;
                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                if ((g = hv_fetchs(h, "age", 0)))   (void)po_sv_to_u64(aTHX_ *g, &b[i].age_ns);
                if ((g = hv_fetchs(h, "bytes", 0))) (void)po_sv_to_u64(aTHX_ *g, &b[i].bytes);
            }
            keep = po_limit_storage(b, (uint32_t)n, bud, &kept, &horizon);
            Safefree(b);

            hv_stores(res, "keep",    newSVuv((UV)keep));
            hv_stores(res, "bytes",   po_u64_to_sv(kept));
            hv_stores(res, "horizon", po_u64_to_sv(horizon));
            mXPUSHs(newRV_noinc((SV *)res));
        }

# The indexed-attribute allowlist, and the overflow that NAMES the attribute.
void
poli_attrs(SV *allow, SV *keys)
    PPCODE:
        {
            po_labelset ls;
            po_attr_overflow ov;
            AV *av;
            SSize_t i, n;
            AV *indexed = newAV(), *residual = newAV(), *named = newAV();
            HV *res = newHV();
            int worst;

            memset(&ls, 0, sizeof(ls));
            po_attr_overflow_init(&ov);

            if (SvROK(allow) && SvTYPE(SvRV(allow)) == SVt_PVAV) {
                AV *a = (AV *)SvRV(allow);
                SSize_t j, m = av_len(a) + 1;
                for (j = 0; j < m; j++) {
                    SV **e = av_fetch(a, j, 0);
                    STRLEN l;
                    const char *p;
                    if (!e) continue;
                    p = SvPV(*e, l);
                    po_labelset_add(&ls, p, (size_t)l);
                }
            }
            else po_labelset_default(&ls);

            if (!SvROK(keys)) croak("keys must be an arrayref");
            av = (AV *)SvRV(keys);
            n = av_len(av) + 1;
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(av, i, 0);
                STRLEN l;
                const char *p;
                if (!e) continue;
                p = SvPV(*e, l);
                if (po_is_label(&ls, p, (size_t)l))
                    av_push(indexed, newSVpvn(p, l));
                else {
                    /* NOT dropped. It stays in the record and is reachable by
                     * a residual filter - only the INDEX is bounded. */
                    av_push(residual, newSVpvn(p, l));
                    po_attr_overflow_note(&ov, p, (size_t)l);
                }
            }

            {
                uint32_t k;
                for (k = 0; k < ov.n; k++) {
                    HV *h = newHV();
                    hv_stores(h, "name",  newSVpvn(ov.name[k], ov.name_len[k]));
                    hv_stores(h, "count", po_u64_to_sv(ov.count[k]));
                    av_push(named, newRV_noinc((SV *)h));
                }
            }
            worst = po_attr_overflow_worst(&ov);

            hv_stores(res, "indexed",  newRV_noinc((SV *)indexed));
            hv_stores(res, "residual", newRV_noinc((SV *)residual));
            hv_stores(res, "overflow", newRV_noinc((SV *)named));
            hv_stores(res, "other",    po_u64_to_sv(ov.dropped_other));
            hv_stores(res, "worst", worst >= 0
                      ? newSVpvn(ov.name[worst], ov.name_len[worst])
                      : newSVpvs(""));
            mXPUSHs(newRV_noinc((SV *)res));
        }

# The cardinality counter, across forked workers. The arena is mapped BEFORE
# the fork: one mapped after is private per worker, and the symptom is a limit
# silently N times what was configured.
void
poli_cardinality_forked(SV *cap, SV *workers, SV *per_worker)
    PPCODE:
        {
            po_shared sh;
            po_u64 c = 0;
            IV nw = SvIV(workers), n = SvIV(per_worker), i;
            HV *res = newHV();

            (void)po_sv_to_u64(aTHX_ cap, &c);
            if (!po_shared_init(&sh, c)) croak("no shared arena");
            if (!po_shared_is_shared(&sh)) {
                po_shared_free(&sh);
                hv_stores(res, "shared", newSViv(0));
                mXPUSHs(newRV_noinc((SV *)res));
                XSRETURN(1);
            }

            for (i = 0; i < nw; i++) {
                pid_t pid = fork();
                if (pid == 0) {
                    IV j;
                    for (j = 0; j < n; j++) (void)po_limit_series(&sh);
                    _exit(0);
                }
            }
            {
                int status;
                while (wait(&status) > 0) ;
            }

            hv_stores(res, "shared",   newSViv(1));
            hv_stores(res, "admitted", po_u64_to_sv(sh.m->series));
            hv_stores(res, "rejected", po_u64_to_sv(sh.m->rejected));
            hv_stores(res, "offered",  po_u64_to_sv((po_u64)(nw * n)));
            po_shared_free(&sh);
            mXPUSHs(newRV_noinc((SV *)res));
        }
