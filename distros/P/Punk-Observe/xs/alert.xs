MODULE = Punk::Observe   PACKAGE = Punk::Observe::Alert   PREFIX = poal_

# Drive a rule through a sequence of evaluations, moving the injected clock
# between them. Nothing here sleeps: every transition is a clock step.
void
poal_run(SV *rule, SV *ticks)
    PPCODE:
        {
            po_al_rule r;
            po_al_state st;
            HV *rh;
            SV **f;
            AV *tv;
            SSize_t t, nt;
            AV *out = newAV();

            if (!SvROK(rule) || SvTYPE(SvRV(rule)) != SVt_PVHV)
                croak("rule must be a hashref");
            if (!SvROK(ticks) || SvTYPE(SvRV(ticks)) != SVt_PVAV)
                croak("ticks must be an arrayref");
            rh = (HV *)SvRV(rule);
            tv = (AV *)SvRV(ticks);

            memset(&r, 0, sizeof(r));
            r.op = PO_AL_GT;
            if ((f = hv_fetchs(rh, "op", 0))) {
                STRLEN l; const char *o = SvPV(*f, l);
                if      (l == 1 && o[0] == '>') r.op = PO_AL_GT;
                else if (l == 2 && o[0] == '>' && o[1] == '=') r.op = PO_AL_GE;
                else if (l == 1 && o[0] == '<') r.op = PO_AL_LT;
                else if (l == 2 && o[0] == '<' && o[1] == '=') r.op = PO_AL_LE;
                else if (l == 2 && o[0] == '=' && o[1] == '=') r.op = PO_AL_EQ;
                else if (l == 2 && o[0] == '!' && o[1] == '=') r.op = PO_AL_NE;
            }
            if ((f = hv_fetchs(rh, "threshold", 0))) r.threshold = SvNV(*f);
            if ((f = hv_fetchs(rh, "for", 0)))   (void)po_sv_to_u64(aTHX_ *f, &r.for_ns);
            if ((f = hv_fetchs(rh, "every", 0))) (void)po_sv_to_u64(aTHX_ *f, &r.every_ns);
            if (!r.every_ns) r.every_ns = PO_NS_PER_SEC;

            po_al_init(&st);
            nt = av_len(tv) + 1;

            for (t = 0; t < nt; t++) {
                SV **e = av_fetch(tv, t, 0);
                HV *th;
                po_al_row rows[64];
                uint32_t nrows = 0;
                int status = PO_EVAL_OK;
                po_u64 at = 0;
                HV *res;
                AV *notes, *states;
                uint32_t i;

                if (!e || !SvROK(*e)) continue;
                th = (HV *)SvRV(*e);

                if ((f = hv_fetchs(th, "at", 0))) {
                    (void)po_sv_to_u64(aTHX_ *f, &at);
                    po_clock_freeze(at);
                }
                if ((f = hv_fetchs(th, "fail", 0)) && SvTRUE(*f))
                    status = PO_EVAL_FAIL;

                if ((f = hv_fetchs(th, "rows", 0)) && SvROK(*f)) {
                    AV *ra = (AV *)SvRV(*f);
                    SSize_t j, nr = av_len(ra) + 1;
                    for (j = 0; j < nr && nrows < 64; j += 2) {
                        SV **k = av_fetch(ra, j, 0);
                        SV **v = av_fetch(ra, j + 1, 0);
                        if (!k || !v) break;
                        rows[nrows].key = SvPV(*k, rows[nrows].key_len);
                        rows[nrows].value = SvNV(*v);
                        nrows++;
                    }
                }

                po_al_step(&st, &r, status, rows, nrows);

                res    = newHV();
                notes  = newAV();
                states = newAV();
                for (i = 0; i < st.nnote; i++) {
                    HV *n = newHV();
                    hv_stores(n, "series", newSVpvn(st.note[i].key,
                                                    st.note[i].key_len));
                    hv_stores(n, "kind",   newSViv(st.note[i].kind));
                    hv_stores(n, "from",   newSVpv(po_al_state_name(st.note[i].from), 0));
                    hv_stores(n, "to",     newSVpv(po_al_state_name(st.note[i].to), 0));
                    hv_stores(n, "at",     po_u64_to_sv(st.note[i].at));
                    hv_stores(n, "fired_at", po_u64_to_sv(st.note[i].fired_at));
                    av_push(notes, newRV_noinc((SV *)n));
                }
                for (i = 0; i < st.n; i++) {
                    HV *s = newHV();
                    hv_stores(s, "series", newSVpvn(st.s[i].key, st.s[i].key_len));
                    hv_stores(s, "state",  newSVpv(po_al_state_name(st.s[i].state), 0));
                    hv_stores(s, "since",  po_u64_to_sv(st.s[i].since));
                    hv_stores(s, "fired_at", po_u64_to_sv(st.s[i].fired_at));
                    av_push(states, newRV_noinc((SV *)s));
                }
                hv_stores(res, "notes",  newRV_noinc((SV *)notes));
                hv_stores(res, "states", newRV_noinc((SV *)states));
                av_push(out, newRV_noinc((SV *)res));
            }

            po_clock_real();
            mXPUSHs(newRV_noinc((SV *)out));
        }

MODULE = Punk::Observe   PACKAGE = Punk::Observe::Route   PREFIX = poro_

# Grouping, silences and the outbox, driven by the same injected clock.
void
poro_run(SV *opts, SV *events)
    PPCODE:
        {
            po_router  rt;
            po_outbox  ob;
            po_silences sl;
            HV *o;
            SV **f;
            AV *ev;
            SSize_t i, n;
            po_u64 wait = 0, repeat = 0;
            AV *sent = newAV();
            HV *res = newHV();
            IV enqueued = 0, deduped = 0;

            if (!SvROK(opts) || SvTYPE(SvRV(opts)) != SVt_PVHV)
                croak("opts must be a hashref");
            if (!SvROK(events) || SvTYPE(SvRV(events)) != SVt_PVAV)
                croak("events must be an arrayref");
            o  = (HV *)SvRV(opts);
            ev = (AV *)SvRV(events);

            if ((f = hv_fetchs(o, "group_wait", 0)))      (void)po_sv_to_u64(aTHX_ *f, &wait);
            if ((f = hv_fetchs(o, "repeat_interval", 0))) (void)po_sv_to_u64(aTHX_ *f, &repeat);
            po_router_init(&rt, wait, repeat);
            po_outbox_init(&ob);
            po_silences_init(&sl);

            if ((f = hv_fetchs(o, "silences", 0)) && SvROK(*f)) {
                AV *sa = (AV *)SvRV(*f);
                SSize_t j, ns = av_len(sa) + 1;
                for (j = 0; j < ns; j++) {
                    SV **e = av_fetch(sa, j, 0);
                    HV *h; SV **g;
                    STRLEN pl = 0;
                    const char *pat = "";
                    int prefix = 0;
                    po_u64 until = 0;
                    if (!e || !SvROK(*e)) continue;
                    h = (HV *)SvRV(*e);
                    if ((g = hv_fetchs(h, "pattern", 0))) pat = SvPV(*g, pl);
                    if ((g = hv_fetchs(h, "prefix", 0)))  prefix = SvTRUE(*g);
                    if ((g = hv_fetchs(h, "until", 0)))   (void)po_sv_to_u64(aTHX_ *g, &until);
                    po_silence_add(&sl, pat, (size_t)pl, prefix, until);
                }
            }

            n = av_len(ev) + 1;
            for (i = 0; i < n; i++) {
                SV **e = av_fetch(ev, i, 0);
                HV *h; SV **g;
                po_u64 at = 0, rule = 0, fired = 0;
                STRLEN gl = 0, sn = 0;
                const char *gk = "", *series = "";
                int silenced;

                if (!e || !SvROK(*e)) continue;
                h = (HV *)SvRV(*e);
                if ((g = hv_fetchs(h, "at", 0))) {
                    (void)po_sv_to_u64(aTHX_ *g, &at);
                    po_clock_freeze(at);
                }
                if ((g = hv_fetchs(h, "group", 0)))  gk = SvPV(*g, gl);
                if ((g = hv_fetchs(h, "series", 0))) series = SvPV(*g, sn);
                if ((g = hv_fetchs(h, "rule", 0)))   (void)po_sv_to_u64(aTHX_ *g, &rule);
                if ((g = hv_fetchs(h, "fired_at", 0))) (void)po_sv_to_u64(aTHX_ *g, &fired);

                /* A "drain" event carries no series: it is the sender waking
                 * up to see what is due, which is how group_wait is observed
                 * at all. */
                if (sn) {
                    silenced = po_is_silenced(&sl, series, (size_t)sn);
                    po_route_add(&rt, gk, (size_t)gl, series, (size_t)sn, silenced);
                    if (!silenced) {
                        if (po_outbox_put(&ob, rule, series, (size_t)sn, fired))
                            enqueued++;
                        else deduped++;
                    }
                }

                for (;;) {
                    po_ngroup *due = po_router_next_due(&rt);
                    HV *m;
                    AV *mem;
                    uint32_t k;
                    if (!due) break;
                    m   = newHV();
                    mem = newAV();
                    for (k = 0; k < due->nmember; k++)
                        av_push(mem, newSVpvn(due->member[k], due->member_len[k]));
                    hv_stores(m, "group",    newSVpvn(due->key, due->key_len));
                    hv_stores(m, "members",  newRV_noinc((SV *)mem));
                    hv_stores(m, "count",    newSVuv((UV)due->nmember));
                    hv_stores(m, "overflow", newSVuv((UV)due->overflow));
                    hv_stores(m, "at",       po_u64_to_sv(po_now_ns()));
                    av_push(sent, newRV_noinc((SV *)m));
                    po_group_mark_sent(&rt, due);
                }
            }

            hv_stores(res, "sent",     newRV_noinc((SV *)sent));
            hv_stores(res, "enqueued", newSViv(enqueued));
            hv_stores(res, "deduped",  newSViv(deduped));
            hv_stores(res, "pending",  newSVuv((UV)po_outbox_pending(&ob)));
            {
                /* pending is reported BEFORE the claim loop below, which is
                 * what an operator wants to see; pending_after is what is
                 * left once a sender has taken everything it can. */
                /* Claim everything once, then try again: a claimed row must
                 * not be claimable by a second sender. */
                IV first = 0, second = 0;
                while (po_outbox_claim(&ob)) first++;
                while (po_outbox_claim(&ob)) second++;
                hv_stores(res, "claimed",  newSViv(first));
                hv_stores(res, "reclaimed", newSViv(second));
                hv_stores(res, "pending_after",
                          newSVuv((UV)po_outbox_pending(&ob)));
            }
            po_clock_real();
            mXPUSHs(newRV_noinc((SV *)res));
        }

MODULE = Punk::Observe   PACKAGE = Punk::Observe::Target   PREFIX = potg_

void
potg_check(SV *url, SV *allow)
    PPCODE:
        {
            STRLEN ul;
            const char *u = SvPV(url, ul);
            const char *list[32];
            SV *keep[32];
            int nallow = 0, rc;
            HV *res = newHV();

            if (SvROK(allow) && SvTYPE(SvRV(allow)) == SVt_PVAV) {
                AV *av = (AV *)SvRV(allow);
                SSize_t i, n = av_len(av) + 1;
                for (i = 0; i < n && nallow < 32; i++) {
                    SV **e = av_fetch(av, i, 0);
                    if (!e) continue;
                    keep[nallow] = *e;
                    list[nallow] = SvPV_nolen(keep[nallow]);
                    nallow++;
                }
            }

            rc = po_target_ok(u, (size_t)ul, nallow ? list : NULL, nallow);
            hv_stores(res, "ok",     newSViv(rc == PO_TGT_OK));
            hv_stores(res, "code",   newSViv(rc));
            hv_stores(res, "reason", newSVpv(po_tgt_reason(rc), 0));
            mXPUSHs(newRV_noinc((SV *)res));
        }

MODULE = Punk::Observe   PACKAGE = Punk::Observe::Dashboard   PREFIX = podb_

void
podb_check_panel(SV *spec)
    PPCODE:
        {
            po_panel p;
            HV *h;
            SV **f;
            STRLEN tl = 0, ql = 0, vl = 0;
            const char *title = "", *query = "", *viz = "";
            IV position = 0, cols = 1;
            int rc;
            HV *res = newHV();

            if (!SvROK(spec) || SvTYPE(SvRV(spec)) != SVt_PVHV)
                croak("spec must be a hashref");
            h = (HV *)SvRV(spec);
            if ((f = hv_fetchs(h, "title", 0)) && SvOK(*f)) title = SvPV(*f, tl);
            if ((f = hv_fetchs(h, "query", 0)) && SvOK(*f)) query = SvPV(*f, ql);
            if ((f = hv_fetchs(h, "viz", 0))   && SvOK(*f)) viz   = SvPV(*f, vl);
            if ((f = hv_fetchs(h, "position", 0))) position = SvIV(*f);
            if ((f = hv_fetchs(h, "cols", 0)))     cols     = SvIV(*f);

            rc = po_panel_check(&p, title, (size_t)tl, query, (size_t)ql,
                                viz, (size_t)vl, (int)position, (int)cols);
            hv_stores(res, "ok",       newSViv(rc == PO_PANEL_OK));
            hv_stores(res, "code",     newSViv(rc));
            hv_stores(res, "error",    newSVpv(p.err, 0));
            hv_stores(res, "viz",      newSVpv(po_viz_name(p.viz), 0));
            hv_stores(res, "position", newSViv(p.position));
            hv_stores(res, "cols",     newSViv(p.cols));
            mXPUSHs(newRV_noinc((SV *)res));
        }
