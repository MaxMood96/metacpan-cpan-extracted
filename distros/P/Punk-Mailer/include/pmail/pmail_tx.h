#ifndef PMAIL_TX_H
#define PMAIL_TX_H

/* pmail_tx.h - what every transport shares: option checking that croaks
 * at construction naming the option, the blessed-hash object shape, and
 * building the message bytes for transports that carry bytes. */

static HV *pmail_self(pTHX_ SV *self, const char *what)
{
    if (!self || !SvROK(self) || SvTYPE(SvRV(self)) != SVt_PVHV || !sv_isobject(self))
        croak("Punk::Mailer: %s needs an object", what);
    return (HV *)SvRV(self);
}

/* an options hashref, or undef for none; anything else croaks */
static HV *pmail_opts_hv(pTHX_ SV *opts, const char *what)
{
    if (!opts || !SvOK(opts)) return (HV *)sv_2mortal((SV *)newHV());
    if (!SvROK(opts) || SvTYPE(SvRV(opts)) != SVt_PVHV)
        croak("Punk::Mailer: %s takes a hashref of options", what);
    return (HV *)SvRV(opts);
}

/* every key must be one the caller lists: a misspelt option that did
 * nothing is the failure this exists to prevent */
static void pmail_opts_check(pTHX_ const char *what, HV *opts,
                             const char *const *ok, size_t n)
{
    HE *he;
    hv_iterinit(opts);
    while ((he = hv_iternext(opts))) {
        STRLEN kl;
        const char *k = HePV(he, kl);
        if (!pmail_str_in(k, kl, ok, n, 0))
            croak("Punk::Mailer: unknown option '%.*s' for %s", (int)kl, k, what);
    }
}

static SV *pmail_opt(pTHX_ HV *opts, const char *key)
{
    SV **p = hv_fetch(opts, key, (I32)strlen(key), 0);
    return (p && *p && SvOK(*p)) ? *p : NULL;
}

static SV *pmail_opt_str(pTHX_ HV *opts, const char *key, const char *what, int required)
{
    SV *v = pmail_opt(aTHX_ opts, key);
    if (!v) {
        if (required) croak("Punk::Mailer: %s needs '%s'", what, key);
        return NULL;
    }
    if (SvROK(v)) croak("Punk::Mailer: '%s' for %s must be a string", key, what);
    return newSVsv(v);
}

static NV pmail_opt_nv(pTHX_ HV *opts, const char *key, NV dflt, const char *what)
{
    SV *v = pmail_opt(aTHX_ opts, key);
    if (!v) return dflt;
    if (SvROK(v) || !looks_like_number(v))
        croak("Punk::Mailer: '%s' for %s must be a number", key, what);
    return SvNV(v);
}

static SV *pmail_bless(pTHX_ HV *h, const char *class)
{
    return sv_bless(newRV_noinc((SV *)h), gv_stashpv(class, GV_ADD));
}

static SV *pmail_hv_get(pTHX_ HV *h, const char *key)
{
    SV **p = hv_fetch(h, key, (I32)strlen(key), 0);
    return (p && *p && SvOK(*p)) ? *p : NULL;
}

static HV *pmail_spec_hv(pTHX_ SV *spec, const char *what)
{
    if (!spec || !SvROK(spec) || SvTYPE(SvRV(spec)) != SVt_PVHV)
        croak("Punk::Mailer: %s takes a message hashref", what);
    return (HV *)SvRV(spec);
}

/* the message as bytes, +1 */
static SV *pmail_build_bytes(pTHX_ HV *spec)
{
    pmail_sink s;
    SV *out = newSVpvs("");
    pmail_sink_sv(aTHX_ &s, out);
    if (pmail_build(aTHX_ spec, &s) != 0) {
        SvREFCNT_dec(out);
        croak("Punk::Mailer: build failed: %s", strerror(errno));
    }
    return out;
}

/* the message's size in bytes as it will be sent, without reading a path
 * attachment (see PMAIL_SIZING) */
static pmail_u64 pmail_build_size(pTHX_ HV *spec)
{
    pmail_sink s;
    pmail_u64 total = 0;
    pmail_sink_count(&s, &total);
    ENTER;
    SAVEINT(PMAIL_SIZING);
    PMAIL_SIZING = 1;
    if (pmail_build(aTHX_ spec, &s) != 0) { LEAVE; croak("Punk::Mailer: sizing failed"); }
    LEAVE;
    return total;
}

/* The Message-ID a message carries, from a render of its headers alone:
 * the attachments are dropped from a copy first, so no file is read for
 * it. For the transports that stream the real bytes somewhere they
 * cannot read them back from. Mortal, or NULL. */
static SV *pmail_message_id_for(pTHX_ HV *spec)
{
    HV *copy = newHVhv(spec);
    SV *ref = sv_2mortal(newRV_noinc((SV *)copy));
    SV *bytes, *id;
    (void)hv_stores(copy, "attachments", newSV(0));
    bytes = sv_2mortal(pmail_build_bytes(aTHX_ copy));
    id = pmail_message_id_of(aTHX_ bytes);
    (void)ref;
    return id ? sv_2mortal(id) : NULL;
}

/* the envelope's recipient list and sender, from an envelope hashref */
static SV *pmail_env_from(pTHX_ HV *env)
{
    SV *f = pmail_hv_get(aTHX_ env, "from");
    if (!f) croak("Punk::Mailer: the envelope has no sender");
    return f;
}

static AV *pmail_env_to(pTHX_ HV *env)
{
    SV *t = pmail_hv_get(aTHX_ env, "to");
    if (!t || !SvROK(t) || SvTYPE(SvRV(t)) != SVt_PVAV)
        croak("Punk::Mailer: the envelope has no recipient list");
    return (AV *)SvRV(t);
}

/* a mailbox as the JSON providers want it: the raw display name, quoted
 * only when it has to be, and the address - no RFC 2047, because the
 * other end is an API taking UTF-8 strings, not a mail header */
static SV *pmail_addr_plain(pTHX_ SV *display, SV *addr)
{
    STRLEN dn, an, i;
    const char *d = SvPV_const(display, dn);
    const char *a = SvPV_const(addr, an);
    SV *out = newSVpvs("");
    int plain = 1;
    SvUTF8_on(out);
    if (dn == 0) { sv_catpvn(out, a, an); return out; }
    for (i = 0; i < dn; i++) {
        unsigned char c = (unsigned char)d[i];
        if (c < 0x80 && !pmail_atext_or_space(c)) { plain = 0; break; }
    }
    if (plain) sv_catpvn(out, d, dn);
    else {
        sv_catpvs(out, "\"");
        for (i = 0; i < dn; i++) {
            if (d[i] == '"' || d[i] == '\\') sv_catpvs(out, "\\");
            sv_catpvn(out, d + i, 1);
        }
        sv_catpvs(out, "\"");
    }
    sv_catpvs(out, " <");
    sv_catpvn(out, a, an);
    sv_catpvs(out, ">");
    return out;
}

static AV *pmail_addr_plain_list(pTHX_ AV *pairs)
{
    AV *out = newAV();
    SSize_t i, n = av_len(pairs) + 1;
    for (i = 0; i < n; i++) {
        AV *pair = (AV *)SvRV(*av_fetch(pairs, i, 0));
        av_push(out, pmail_addr_plain(aTHX_ *av_fetch(pair, 0, 0), *av_fetch(pair, 1, 0)));
    }
    return out;
}

#endif /* PMAIL_TX_H */
