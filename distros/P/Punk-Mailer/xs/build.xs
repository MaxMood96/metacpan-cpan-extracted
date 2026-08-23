MODULE = Punk::Mailer    PACKAGE = Punk::Mailer

# ---- the public surface ------------------------------------------------

# build(\%message): the message as bytes.
SV *
build(class, spec)
        SV *class
        SV *spec
    PREINIT:
        pmail_sink s;
        SV *out;
    CODE:
        PERL_UNUSED_VAR(class);
        if (!SvROK(spec) || SvTYPE(SvRV(spec)) != SVt_PVHV)
            croak("Punk::Mailer: build takes a hashref");
        out = newSVpvs("");
        sv_2mortal(out);
        pmail_sink_sv(aTHX_ &s, out);
        if (pmail_build(aTHX_ (HV *)SvRV(spec), &s) != 0)
            croak("Punk::Mailer: build failed: %s", strerror(errno));
        RETVAL = SvREFCNT_inc_simple_NN(out);
    OUTPUT:
        RETVAL

# build_to(\%message, \&code): the bytes, in chunks, to a callback.
void
build_to(class, spec, code)
        SV *class
        SV *spec
        SV *code
    PREINIT:
        pmail_sink s;
    PPCODE:
        PERL_UNUSED_VAR(class);
        if (!SvROK(spec) || SvTYPE(SvRV(spec)) != SVt_PVHV)
            croak("Punk::Mailer: build_to takes a hashref");
        if (!SvROK(code) || SvTYPE(SvRV(code)) != SVt_PVCV)
            croak("Punk::Mailer: build_to takes a coderef");
        pmail_sink_cv(aTHX_ &s, code);
        if (pmail_build(aTHX_ (HV *)SvRV(spec), &s) != 0)
            croak("Punk::Mailer: build failed: %s", strerror(errno));
        XSRETURN_YES;

# envelope(\%message): { from => addr, to => [ addrs ] }.
SV *
envelope(class, spec)
        SV *class
        SV *spec
    CODE:
        PERL_UNUSED_VAR(class);
        if (!SvROK(spec) || SvTYPE(SvRV(spec)) != SVt_PVHV)
            croak("Punk::Mailer: envelope takes a hashref");
        RETVAL = newRV_noinc((SV *)pmail_envelope(aTHX_ (HV *)SvRV(spec)));
    OUTPUT:
        RETVAL

# ---- test hooks: the codecs and rules on their own ----------------------
# Underscore-prefixed and not part of the API; t/01-03 drive them so a
# failure names the codec rather than the message it was inside.

# base64, 76-column CRLF lines, the attachment form
SV *
_b64(bytes)
        SV *bytes
    PREINIT:
        pmail_sink s;
        pmail_b64_st st;
        STRLEN n;
        const char *p;
        SV *out;
    CODE:
        p = SvPV_const(bytes, n);
        out = newSVpvs("");
        sv_2mortal(out);
        pmail_sink_sv(aTHX_ &s, out);
        pmail_b64_init(&st, 1);
        pmail_b64_update(&st, (const unsigned char *)p, n, &s);
        pmail_b64_final(&st, &s);
        RETVAL = SvREFCNT_inc_simple_NN(out);
    OUTPUT:
        RETVAL

# the same, fed in `chunk`-byte pieces: must equal _b64
SV *
_b64_chunked(bytes, chunk)
        SV *bytes
        IV chunk
    PREINIT:
        pmail_sink s;
        pmail_b64_st st;
        STRLEN n, off = 0;
        const char *p;
        SV *out;
    CODE:
        if (chunk < 1) croak("chunk must be positive");
        p = SvPV_const(bytes, n);
        out = newSVpvs("");
        sv_2mortal(out);
        pmail_sink_sv(aTHX_ &s, out);
        pmail_b64_init(&st, 1);
        while (off < n) {
            STRLEN take = n - off < (STRLEN)chunk ? n - off : (STRLEN)chunk;
            pmail_b64_update(&st, (const unsigned char *)p + off, take, &s);
            off += take;
        }
        pmail_b64_final(&st, &s);
        RETVAL = SvREFCNT_inc_simple_NN(out);
    OUTPUT:
        RETVAL

# one unwrapped run, the RFC 2047 / AUTH form
SV *
_b64_plain(bytes)
        SV *bytes
    PREINIT:
        STRLEN n;
        const char *p;
    CODE:
        p = SvPV_const(bytes, n);
        RETVAL = pmail_b64_plain_sv(aTHX_ (const unsigned char *)p, n);
    OUTPUT:
        RETVAL

# what _b64 of n bytes is long, without encoding anything
UV
_b64_wrapped_len(n)
        UV n
    CODE:
        RETVAL = (UV)pmail_b64_wrapped_len((pmail_u64)n);
    OUTPUT:
        RETVAL

# quoted-printable over bytes already in CRLF form
SV *
_qp(bytes)
        SV *bytes
    PREINIT:
        pmail_sink s;
        STRLEN n;
        const char *p;
        SV *out;
    CODE:
        p = SvPV_const(bytes, n);
        out = newSVpvs("");
        sv_2mortal(out);
        pmail_sink_sv(aTHX_ &s, out);
        pmail_qp_encode((const unsigned char *)p, n, &s);
        RETVAL = SvREFCNT_inc_simple_NN(out);
    OUTPUT:
        RETVAL

# (display, addr) for one address string, or a croak
void
_address(str)
        SV *str
    PREINIT:
        SV *display, *addr;
    PPCODE:
        pmail_addr_parse(aTHX_ "address", str, &display, &addr);
        EXTEND(SP, 2);
        mPUSHs(display);
        mPUSHs(addr);

# the folded "Name: ..." line(s) for an address or a list of them
SV *
_address_header(name, list)
        const char *name
        SV *list
    PREINIT:
        AV *parsed;
        SV *val, *out;
    CODE:
        parsed = (AV *)sv_2mortal((SV *)newAV());
        pmail_addr_list(aTHX_ name, list, parsed);
        val = sv_2mortal(pmail_addr_header_value(aTHX_ parsed));
        out = newSVpvs("");
        pmail_hdr_fold_sv(aTHX_ out, name, val);
        RETVAL = out;
    OUTPUT:
        RETVAL

# an unstructured value as it would appear: ASCII as is, else encoded-words
SV *
_encode_word(str)
        SV *str
    PREINIT:
        STRLEN n;
        const char *p;
        SV *out;
    CODE:
        p = pmail_sv_utf8(aTHX_ str, &n);
        out = newSVpvs("");
        pmail_hdr_unstructured(aTHX_ out, p, n);
        RETVAL = out;
    OUTPUT:
        RETVAL

# "Name: value" folded at 78
SV *
_fold(name, value)
        const char *name
        SV *value
    PREINIT:
        SV *out;
    CODE:
        out = newSVpvs("");
        pmail_hdr_fold_sv(aTHX_ out, name, value);
        RETVAL = out;
    OUTPUT:
        RETVAL

# the SMTP dot-stuffing filter, fed in `chunk`-byte pieces
SV *
_dotstuff(bytes, chunk)
        SV *bytes
        IV chunk
    PREINIT:
        pmail_sink inner, outer;
        pmail_dotstuff st;
        STRLEN n, off = 0;
        const char *p;
        SV *out;
    CODE:
        if (chunk < 1) croak("chunk must be positive");
        p = SvPV_const(bytes, n);
        out = newSVpvs("");
        sv_2mortal(out);
        pmail_sink_sv(aTHX_ &inner, out);
        pmail_sink_dotstuff(&outer, &st, &inner);
        while (off < n) {
            STRLEN take = n - off < (STRLEN)chunk ? n - off : (STRLEN)chunk;
            pmail_put(&outer, p + off, take);
            off += take;
        }
        RETVAL = SvREFCNT_inc_simple_NN(out);
    OUTPUT:
        RETVAL

# the Date header value for an epoch
SV *
_date(epoch)
        NV epoch
    PREINIT:
        char buf[64];
    CODE:
        pmail_hdr_date(buf, sizeof buf, (time_t)epoch);
        RETVAL = newSVpv(buf, 0);
    OUTPUT:
        RETVAL

# a fresh random token, to show two are never alike
SV *
_token()
    PREINIT:
        char token[25];
    CODE:
        if (pmail_random_token(token, 24) != 0) croak("no entropy");
        RETVAL = newSVpv(token, 24);
    OUTPUT:
        RETVAL
