#include "stream_internal.h"

void
les_call_one(pTHX_ SV *cb, SV *arg)
{
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, 1);
    PUSHs(arg);
    PUTBACK;
    call_sv(cb, G_DISCARD | G_VOID);
    FREETMPS;
    LEAVE;
}

void
les_call_two(pTHX_ SV *cb, SV *a, SV *b)
{
    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, 2);
    PUSHs(a);
    PUSHs(b);
    PUTBACK;
    call_sv(cb, G_DISCARD | G_VOID);
    FREETMPS;
    LEAVE;
}

void
les_call_transport_event(pTHX_ les_xsstate_t *st, int status,
    const char *operation)
{
    dSP;
    const char *message = "";

    if (status == LES_TRANSPORT_ERROR && st->transport_ops->error_string)
        message = st->transport_ops->error_string(st->transport_context);

    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, 4);
    PUSHs(st->stream_sv);
    PUSHs(sv_2mortal(newSViv(status)));
    PUSHs(sv_2mortal(newSVpv(operation, 0)));
    PUSHs(sv_2mortal(newSVpv(message ? message : "", 0)));
    PUTBACK;
    call_method("_xs_transport_event", G_DISCARD | G_VOID);
    FREETMPS;
    LEAVE;
}

void
les_call_deliver(pTHX_ les_xsstate_t *st, SV *bytes)
{
    les_call_two(aTHX_ st->descriptor->deliver_cb, st->stream_sv, bytes);
    st->delivery_calls++;
}

void
les_call_framing_error(pTHX_ les_xsstate_t *st, const char *message)
{
    les_descriptor_t *descriptor = st->descriptor;
    SV *msg;

    les_flush_message_batch(aTHX_ st);
    if (st->closed || st->read_paused || st->descriptor != descriptor)
        return;
    if (!st->descriptor->framing_error_cb)
        return;
    st->framing_error_count++;
    msg = sv_2mortal(newSVpv(message, 0));
    les_call_two(aTHX_ st->descriptor->framing_error_cb, st->stream_sv, msg);
}

void
les_call_eof(pTHX_ les_xsstate_t *st)
{
    les_call_one(aTHX_ st->descriptor->eof_cb, st->stream_sv);
}

void
les_call_read_error(pTHX_ les_xsstate_t *st, int err)
{
    SV *errno_sv = sv_2mortal(newSViv(err));
    les_call_two(aTHX_ st->descriptor->read_error_cb, st->stream_sv, errno_sv);
}

void
les_call_write_error(pTHX_ les_xsstate_t *st, int err)
{
    SV *errno_sv = sv_2mortal(newSViv(err));
    les_call_two(aTHX_ st->descriptor->write_error_cb, st->stream_sv, errno_sv);
}

void
les_call_output_limit(pTHX_ les_xsstate_t *st, UV pending_bytes)
{
    SV *pending_sv = sv_2mortal(newSVuv(pending_bytes));
    SV *limit_sv = sv_2mortal(newSVuv(st->descriptor->max_pending_bytes));
    dSP;

    st->output_limit_count++;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    EXTEND(SP, 3);
    PUSHs(st->stream_sv);
    PUSHs(pending_sv);
    PUSHs(limit_sv);
    PUTBACK;
    call_sv(st->descriptor->output_limit_cb, G_DISCARD | G_VOID);
    FREETMPS;
    LEAVE;
}

void
les_call_drain(pTHX_ les_xsstate_t *st)
{
    if (!st->descriptor->drain_cb)
        return;
    st->drain_calls++;
    les_call_one(aTHX_ st->descriptor->drain_cb, st->stream_sv);
}

void
les_call_empty(pTHX_ les_xsstate_t *st)
{
    st->empty_calls++;
    les_call_one(aTHX_ st->descriptor->write_empty_cb, st->stream_sv);
}
