#ifndef PMAIL_TX_CAPTURE_H
#define PMAIL_TX_CAPTURE_H

/* pmail_tx_capture.h - the transport for tests and development.
 *
 * Builds the bytes and keeps them: every delivery is pushed onto
 * `messages` as { spec, envelope, bytes, result }, so a test reads what
 * would have gone out. With `dir`, each message is also written as one
 * <epoch>.<seq>.<pid>.eml under dir/new/ - maildir-shaped enough for a
 * mail client to open, and nothing more. `result` scripts the verdict, so
 * a site test can exercise its "not accepted" branch without a server. */

static const char *const PMAIL_CAPTURE_OPTS[] = { "dir", "result" };

static SV *pmail_capture_new(pTHX_ const char *class, SV *opts_sv)
{
    HV *opts = pmail_opts_hv(aTHX_ opts_sv, "the capture transport");
    HV *self = newHV();
    SV *dir, *result;
    pmail_opts_check(aTHX_ "the capture transport", opts, PMAIL_CAPTURE_OPTS, 2);
    dir = pmail_opt_str(aTHX_ opts, "dir", "the capture transport", 0);
    result = pmail_opt_str(aTHX_ opts, "result", "the capture transport", 0);
    if (result) {
        STRLEN n; const char *p = SvPV_const(result, n);
        if (!(strEQ(p, PMAIL_ST_ACCEPTED) || strEQ(p, PMAIL_ST_DEFERRED)
              || strEQ(p, PMAIL_ST_REJECTED) || strEQ(p, PMAIL_ST_FAILED)))
            croak("Punk::Mailer: the capture transport's result must be accepted, "
                  "deferred, rejected or failed, not '%.*s'", (int)n, p);
    }
    (void)hv_stores(self, "dir", dir ? dir : newSV(0));
    (void)hv_stores(self, "result", result ? result : newSVpvs(PMAIL_ST_ACCEPTED));
    (void)hv_stores(self, "messages", newRV_noinc((SV *)newAV()));
    (void)hv_stores(self, "seq", newSViv(0));
    return pmail_bless(aTHX_ self, class);
}

static void pmail_mkdir_p2(pTHX_ const char *dir)
{
    SV *sub = sv_2mortal(newSVpvf("%s/new", dir));
    if (mkdir(dir, 0700) != 0 && errno != EEXIST)
        croak("Punk::Mailer: cannot create %s: %s", dir, strerror(errno));
    if (mkdir(SvPV_nolen(sub), 0700) != 0 && errno != EEXIST)
        croak("Punk::Mailer: cannot create %s: %s", SvPV_nolen(sub), strerror(errno));
}

static SV *pmail_capture_deliver(pTHX_ SV *self_sv, SV *spec_sv, SV *env_sv)
{
    HV *self = pmail_self(aTHX_ self_sv, "deliver");
    HV *spec = pmail_spec_hv(aTHX_ spec_sv, "deliver");
    SV *bytes = sv_2mortal(pmail_build_bytes(aTHX_ spec));
    SV *dir = pmail_hv_get(aTHX_ self, "dir");
    SV *scripted = pmail_hv_get(aTHX_ self, "result");
    SV **seqp = hv_fetchs(self, "seq", 0);
    IV seq = (seqp && *seqp) ? SvIV(*seqp) + 1 : 1;
    SV *id = pmail_message_id_of(aTHX_ bytes);
    const char *status = scripted ? SvPV_nolen(scripted) : PMAIL_ST_ACCEPTED;
    IV code = strEQ(status, PMAIL_ST_ACCEPTED) ? 250
            : strEQ(status, PMAIL_ST_DEFERRED) ? 451
            : strEQ(status, PMAIL_ST_REJECTED) ? 550 : 0;
    SV *result, *rec;
    HV *entry;

    if (id) sv_2mortal(id);
    if (seqp && *seqp) sv_setiv(*seqp, seq);

    if (dir) {
        const char *d = SvPV_nolen(dir);
        SV *path;
        int fd;
        pmail_sink s;
        char tb[PMAIL_U64_LEN];
        pmail_mkdir_p2(aTHX_ d);
        path = sv_2mortal(newSVpvf("%s/new/%s.%" IVdf ".%lu.eml", d,
                                   pmail_u64_str(tb, (pmail_u64)time(NULL)), seq,
                                   (unsigned long)getpid()));
        fd = open(SvPV_nolen(path), O_WRONLY | O_CREAT | O_EXCL, 0600);
        if (fd < 0)
            croak("Punk::Mailer: cannot write %s: %s", SvPV_nolen(path), strerror(errno));
        pmail_sink_fd(&s, fd);
        if (pmail_sink_sv_put(aTHX_ &s, bytes) != 0) {
            int e = errno;
            close(fd);
            croak("Punk::Mailer: cannot write %s: %s", SvPV_nolen(path), strerror(e));
        }
        close(fd);
        (void)hv_stores(self, "last_path", newSVsv(path));
    }

    result = pmail_result_newf(aTHX_ status, code, NULL, "capture", id,
                               "captured (scripted %s)", status);
    entry = newHV();
    (void)hv_stores(entry, "spec", newSVsv(spec_sv));
    (void)hv_stores(entry, "envelope", newSVsv(env_sv));
    (void)hv_stores(entry, "bytes", newSVsv(bytes));
    (void)hv_stores(entry, "result", newSVsv(result));
    rec = newRV_noinc((SV *)entry);
    {
        SV **mp = hv_fetchs(self, "messages", 0);
        av_push((AV *)SvRV(*mp), rec);
    }
    return result;
}

#endif /* PMAIL_TX_CAPTURE_H */
