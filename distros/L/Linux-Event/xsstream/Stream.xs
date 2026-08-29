/*
 * Linux::Event::Stream XS binding boundary
 * ========================================
 *
 * One immutable descriptor is built for each Perl Stream subclass. It owns
 * resolved callback CVs, transport policy, and native framer configuration.
 * Per-connection state references that descriptor and owns only mutable I/O,
 * parser, queue, instrumentation, and lifetime state.
 *
 * Public Perl remains responsible for policy and semantic state such as
 * end(), close(), outbound framing, and watcher ownership. Native code owns
 * for repetitive transport work:
 *
 *     EPOLLIN
 *       -> XSState::_read_ready()
 *       -> native transport read until retry
 *       -> reusable native read buffer
 *       -> Perl only when bytes are available
 *
 *     Stream->write($bytes)
 *       -> XSState::_write()
 *       -> immediate native transport write when the queue is empty
 *       -> native segmented queue on partial write/EAGAIN
 *
 *     EPOLLOUT
 *       -> XSState::_write_ready()
 *       -> native transport vector writes until retry or empty
 *       -> Perl only for drain/error/queue-empty semantic transitions
 *
 * Why a segmented queue?
 * ----------------------
 * The reference Perl Stream used one large scalar plus an offset.  Appending
 * to that scalar and periodically deleting its consumed prefix creates copy
 * and compaction work in Perl.  The native queue instead stores independent
 * byte segments and advances offsets.  writev() can flush several segments in
 * one syscall without concatenating them first.
 *
 * Queued segments own an independent SV copy. That gives
 * write() ordinary value semantics: callers may modify or release their input
 * scalar immediately after write() returns.  A later benchmark may test COW or
 * retained immutable SVs as a separate zero-copy optimization; it is not
 * mixed into this write-path measurement.
 *
 * Transport boundary
 * ------------------
 * Connection state selects a native byte-transport operations table. The
 * current plain provider maps it to read/write/writev/shutdown. Its identity
 * is specialized before each operation so ordinary Streams retain direct
 * syscalls rather than paying an indirect provider call. Parser, queue, and
 * lifecycle code consume transport results and distinguish WANT_READ from
 * WANT_WRITE for a future adjacent TLS provider.
 *
 * Backpressure contract
 * ---------------------
 * The native state tracks pending bytes and high/low watermarks.  _write()
 * returns an internal bitmask to Perl:
 *
 *     LES_WRITE_FLOW_OK  producer may continue
 *     LES_WRITE_QUEUED   EPOLLOUT interest must be enabled
 *
 * Crossing above high_watermark makes write() false.  Once draining reaches
 * low_watermark or below, write_blocked is cleared before on_drain is invoked.
 * The callback may therefore call write() reentrantly and start a new blocked
 * interval safely.
 *
 * A nonzero max_pending_bytes is an independent hard queue bound. Before an
 * unsent remainder is copied into a segment, XS checks the resulting pending
 * count. Overflow enters Perl for one typed error/close transition and the
 * remainder is never queued. The ordinary false return therefore continues to
 * mean accepted cooperative backpressure, never rejection.
 *
 * Callback and lifetime safety
 * ----------------------------
 * The Perl Stream owns this XSState object. XSState holds strong references to
 * the Stream and its shared class descriptor. close()/detach() mark native state
 * closed and clear queued SVs before the reactor watcher is cancelled.  User
 * callbacks may pause, close, end, or write reentrantly; native loops re-check
 * state after every Perl callback before continuing.
 *
 * Source organization
 * -------------------
 * This file contains the XSUB boundary. Focused stream_*.c translation units
 * own state, transport, callbacks, input, delivery, read, write, and protocol
 * transition mechanics. Each built-in parser lives in its matching
 * framer_*.c file. stream_internal.h is their only shared private contract.
 *
 * Separation from Linux::Event internals
 * --------------------------------------
 * This file intentionally does not include Linux::Event private C headers.
 * The reactor passes watcher data directly to these XSUBs through the private
 * callback-data hook established by the prior Stream milestone.  That keeps
 * the core a generic readiness engine while allowing Stream to be developed
 * and benchmarked independently.
 */

#include "stream_internal.h"

MODULE = Linux::Event::Stream    PACKAGE = Linux::Event::Stream::XSDescriptor
PROTOTYPES: DISABLE

SV *
new(CLASS, read_size, read_batch_bytes, message_batch_size, high_watermark, low_watermark, max_pending_bytes, max_buffer, read_mode, deliver_cb, message_cb, message_batch_cb, drain_cb, eof_cb, read_error_cb, write_error_cb, output_limit_cb, write_empty_cb, framing_error_cb, delimiter_sv, include_delimiter, max_frame_sv, fixed_size, prefix_bytes, prefix_little, include_prefix)
    const char *CLASS
    UV read_size
    UV read_batch_bytes
    UV message_batch_size
    UV high_watermark
    UV low_watermark
    UV max_pending_bytes
    UV max_buffer
    int read_mode
    SV *deliver_cb
    SV *message_cb
    SV *message_batch_cb
    SV *drain_cb
    SV *eof_cb
    SV *read_error_cb
    SV *write_error_cb
    SV *output_limit_cb
    SV *write_empty_cb
    SV *framing_error_cb
    SV *delimiter_sv
    int include_delimiter
    SV *max_frame_sv
    UV fixed_size
    int prefix_bytes
    int prefix_little
    int include_prefix
  PREINIT:
    les_descriptor_t *descriptor;
    STRLEN delimiter_len = 0;
    const char *delimiter = NULL;
  CODE:
    if (read_size == 0) croak("read_size must be > 0");
    if (read_batch_bytes > (UV)(size_t)-1)
        croak("read_batch_bytes exceeds native size_t");
    if (low_watermark > high_watermark)
        croak("low_watermark must be <= high_watermark");
    if (read_mode != LES_READ_DELIVER
        && (read_mode < LES_READ_DELIMITER || read_mode > LES_READ_DECIMAL))
        croak("invalid Stream native read mode");
    if (read_mode == LES_READ_DELIVER
        && (!deliver_cb || !SvOK(deliver_cb)))
        croak("on_data callback required for raw Stream descriptor");
    if (read_mode == LES_READ_DELIVER && message_batch_size)
        croak("message_batch_size requires framed mode");
    if (read_mode != LES_READ_DELIVER && read_batch_bytes)
        croak("read_batch_bytes requires raw mode");
    if (read_mode != LES_READ_DELIVER && !message_batch_size
        && (!message_cb || !SvOK(message_cb)))
        croak("on_message callback required for framed Stream descriptor");
    if (read_mode != LES_READ_DELIVER && message_batch_size
        && (!message_batch_cb || !SvOK(message_batch_cb)))
        croak("on_messages callback required for batched framed Stream descriptor");
    if (read_mode != LES_READ_DELIVER
        && (!framing_error_cb || !SvOK(framing_error_cb)))
        croak("framing error callback required for framed Stream descriptor");
    if (read_mode == LES_READ_FIXED && fixed_size == 0)
        croak("fixed_size must be > 0 for native fixed framing");
    if (read_mode == LES_READ_LENGTH
        && prefix_bytes != 1 && prefix_bytes != 2 && prefix_bytes != 4)
        croak("prefix_bytes must be 1, 2, or 4 for native length framing");

    if (read_mode == LES_READ_DELIMITER || read_mode == LES_READ_DECIMAL) {
        if (!delimiter_sv || !SvOK(delimiter_sv))
            croak("delimiter required for native delimiter mode");
        delimiter = SvPVbyte(delimiter_sv, delimiter_len);
        if (delimiter_len == 0)
            croak("delimiter must not be empty");
        if (read_mode == LES_READ_DECIMAL && delimiter_len != 1)
            croak("separator must be exactly one byte for native decimal framing");
    }

    descriptor = (les_descriptor_t *)calloc(1, sizeof(*descriptor));
    if (!descriptor) croak("calloc XSDescriptor failed");

    descriptor->read_size = (size_t)read_size;
    descriptor->read_batch_bytes = read_batch_bytes;
    descriptor->message_batch_size = message_batch_size;
    descriptor->high_watermark = high_watermark;
    descriptor->low_watermark = low_watermark;
    descriptor->max_pending_bytes = max_pending_bytes;
    descriptor->max_buffer = max_buffer;
    descriptor->read_mode = read_mode;
    descriptor->include_delimiter = include_delimiter ? 1 : 0;
    descriptor->fixed_size = fixed_size;
    descriptor->prefix_bytes = prefix_bytes;
    descriptor->prefix_little = prefix_little ? 1 : 0;
    descriptor->include_prefix = include_prefix ? 1 : 0;
    if (max_frame_sv && SvOK(max_frame_sv)) {
        descriptor->has_max_frame = 1;
        descriptor->max_frame = SvUV(max_frame_sv);
    }
    if (delimiter_len) {
        descriptor->delimiter = (char *)malloc((size_t)delimiter_len);
        if (!descriptor->delimiter) {
            free(descriptor);
            croak("malloc native descriptor delimiter failed");
        }
        memcpy(descriptor->delimiter, delimiter, (size_t)delimiter_len);
        descriptor->delimiter_len = (size_t)delimiter_len;
    }

    descriptor->deliver_cb = les_store_optional_cb(deliver_cb, "on_data callback");
    descriptor->message_cb = les_store_optional_cb(message_cb, "on_message callback");
    descriptor->message_batch_cb = les_store_optional_cb(message_batch_cb,
        "on_messages callback");
    descriptor->drain_cb = les_store_optional_cb(drain_cb, "on_drain callback");
    descriptor->eof_cb = les_store_cb(eof_cb, "EOF callback");
    descriptor->read_error_cb = les_store_cb(read_error_cb, "read error callback");
    descriptor->write_error_cb = les_store_cb(write_error_cb, "write error callback");
    descriptor->output_limit_cb = les_store_cb(output_limit_cb, "output limit callback");
    descriptor->write_empty_cb = les_store_cb(write_empty_cb, "write empty callback");
    descriptor->framing_error_cb = les_store_cb(framing_error_cb, "framing error callback");

    RETVAL = sv_setref_pv(newSV(0), CLASS, (void *)descriptor);
  OUTPUT:
    RETVAL

void
DESTROY(descriptor_obj)
    SV *descriptor_obj
  PREINIT:
    les_descriptor_t *descriptor;
  CODE:
    descriptor = les_descriptor_from_sv(descriptor_obj);
    if (descriptor) {
        if (descriptor->deliver_cb) SvREFCNT_dec(descriptor->deliver_cb);
        if (descriptor->message_cb) SvREFCNT_dec(descriptor->message_cb);
        if (descriptor->message_batch_cb) SvREFCNT_dec(descriptor->message_batch_cb);
        if (descriptor->drain_cb) SvREFCNT_dec(descriptor->drain_cb);
        if (descriptor->eof_cb) SvREFCNT_dec(descriptor->eof_cb);
        if (descriptor->read_error_cb) SvREFCNT_dec(descriptor->read_error_cb);
        if (descriptor->write_error_cb) SvREFCNT_dec(descriptor->write_error_cb);
        if (descriptor->output_limit_cb) SvREFCNT_dec(descriptor->output_limit_cb);
        if (descriptor->write_empty_cb) SvREFCNT_dec(descriptor->write_empty_cb);
        if (descriptor->framing_error_cb) SvREFCNT_dec(descriptor->framing_error_cb);
        free(descriptor->delimiter);
        free(descriptor);
        sv_setiv(SvRV(descriptor_obj), 0);
    }

MODULE = Linux::Event::Stream    PACKAGE = Linux::Event::Stream::XSState
PROTOTYPES: DISABLE

SV *
new(CLASS, stream, fd, descriptor_obj)
    const char *CLASS
    SV *stream
    int fd
    SV *descriptor_obj
  PREINIT:
    les_xsstate_t *st;
    les_descriptor_t *descriptor;
  CODE:
    if (fd < 0) croak("fd must be >= 0");
    descriptor = les_descriptor_from_sv(descriptor_obj);
    if (!descriptor) croak("Stream descriptor is closed");

    st = (les_xsstate_t *)calloc(1, sizeof(*st));
    if (!st) croak("calloc XSState failed");
    st->fd = fd;
    st->plain_transport.fd = fd;
    st->transport_ops = &les_plain_transport_ops;
    st->transport_context = &st->plain_transport;
    st->descriptor = descriptor;
    st->descriptor_sv = newSVsv(descriptor_obj);
    st->stream_sv = newSVsv(stream);

    if (descriptor->read_mode == LES_READ_DELIVER) {
        st->read_buffer = (char *)malloc(descriptor->read_size);
        if (!st->read_buffer) {
            SvREFCNT_dec(st->descriptor_sv);
            SvREFCNT_dec(st->stream_sv);
            free(st);
            croak("malloc XSState read buffer failed");
        }
    }

    RETVAL = sv_setref_pv(newSV(0), CLASS, (void *)st);
  OUTPUT:
    RETVAL

void
DESTROY(state_obj)
    SV *state_obj
  PREINIT:
    les_xsstate_t *st;
  CODE:
    st = les_state_from_sv(state_obj);
    if (st) {
        les_clear_write_queue(st);
        les_discard_message_batch(st);
        if (st->stream_sv) SvREFCNT_dec(st->stream_sv);
        if (st->descriptor_sv) SvREFCNT_dec(st->descriptor_sv);
        if (st->transport_provider_sv) SvREFCNT_dec(st->transport_provider_sv);
        free(st->read_buffer);
        free(st->input_buffer);
        free(st);
        sv_setiv(SvRV(state_obj), 0);
    }

SV *
stream(state_obj)
    SV *state_obj
  CODE:
    les_xsstate_t *st = les_state_from_sv(state_obj);
    RETVAL = st->stream_sv ? newSVsv(st->stream_sv) : &PL_sv_undef;
  OUTPUT:
    RETVAL

void
_read_ready(state_obj)
    SV *state_obj
  CODE:
    les_read_ready(aTHX_ les_state_from_sv(state_obj));

int
_write(state_obj, bytes)
    SV *state_obj
    SV *bytes
  CODE:
    RETVAL = les_write_submit(aTHX_ les_state_from_sv(state_obj), bytes);
  OUTPUT:
    RETVAL

void
_write_ready(state_obj)
    SV *state_obj
  CODE:
    les_write_ready(aTHX_ les_state_from_sv(state_obj));

void
_attach_transport(state_obj, provider, abi_version, ops_address, context_address)
    SV *state_obj
    SV *provider
    UV abi_version
    UV ops_address
    UV context_address
  PREINIT:
    les_xsstate_t *st;
    const les_transport_ops_t *ops;
  CODE:
    st = les_state_from_sv(state_obj);
    if (st->closed) croak("cannot attach a transport to a closed Stream");
    if (st->transport_ops != &les_plain_transport_ops)
        croak("Stream already has a non-plain transport");
    if (abi_version != LES_TRANSPORT_ABI_VERSION)
        croak("transport ABI version mismatch: got %llu, need %u",
            (unsigned long long)abi_version, LES_TRANSPORT_ABI_VERSION);
    if (!ops_address || !context_address)
        croak("transport returned a null native address");
    ops = INT2PTR(const les_transport_ops_t *, ops_address);
    if (ops->abi_version != LES_TRANSPORT_ABI_VERSION)
        croak("transport operations table has an incompatible ABI version");
    if (!ops->name || !ops->name[0] || !ops->read_bytes || !ops->write_bytes
        || !ops->write_vectors || !ops->shutdown_write || !ops->drive
        || !ops->is_ready || !ops->error_string)
        croak("transport operations table is incomplete");
    st->transport_provider_sv = newSVsv(provider);
    st->transport_ops = ops;
    st->transport_context = INT2PTR(void *, context_address);

void
_shutdown_write(state_obj)
    SV *state_obj
  PREINIT:
    les_xsstate_t *st;
    les_transport_result_t result;
  PPCODE:
    st = les_state_from_sv(state_obj);
    if (st->closed) {
        result.count = 0;
        result.status = LES_TRANSPORT_ERROR;
        result.error = EBADF;
    } else {
        result = les_transport_shutdown_write(st);
    }
    EXTEND(SP, 3);
    PUSHs(sv_2mortal(newSViv(result.status)));
    PUSHs(sv_2mortal(newSViv(result.error)));
    PUSHs(sv_2mortal(newSVpv(
        result.status == LES_TRANSPORT_ERROR
            ? st->transport_ops->error_string(st->transport_context) : "", 0)));

void
_pause(state_obj)
    SV *state_obj
  CODE:
    les_state_from_sv(state_obj)->read_paused = 1;

void
_resume(state_obj)
    SV *state_obj
  PREINIT:
    les_xsstate_t *st;
  CODE:
    ENTER;
    SAVEFREESV(SvREFCNT_inc(state_obj));
    st = les_state_from_sv(state_obj);
    if (!st->closed && !st->read_eof) {
        st->read_paused = 0;
        if (st->input_dispatch_depth == 0 && st->input_len) {
            ENTER;
            SAVEINT(st->input_dispatch_depth);
            st->input_dispatch_depth++;
            les_process_existing_input(aTHX_ st, 1);
            LEAVE;
        }
    }
    LEAVE;

void
_set_activity_tracking(state_obj, enabled)
    SV *state_obj
    int enabled
  PREINIT:
    les_xsstate_t *st;
    unsigned long long now;
  CODE:
    st = les_state_from_sv(state_obj);
    if (enabled) {
        if (!st->activity_tracking) {
            now = les_activity_now_ns(aTHX);
            st->last_read_ns = now;
            st->last_write_ns = now;
            st->activity_clock_calls++;
        }
        st->activity_tracking = 1;
    } else {
        st->activity_tracking = 0;
    }

void
_activity_snapshot(state_obj)
    SV *state_obj
  PREINIT:
    les_xsstate_t *st;
  PPCODE:
    st = les_state_from_sv(state_obj);
    if (!st->activity_tracking)
        croak("Stream activity tracking is not enabled");
    EXTEND(SP, 2);
    PUSHs(sv_2mortal(newSVnv((NV)st->last_read_ns / 1000000000.0)));
    PUSHs(sv_2mortal(newSVnv((NV)st->last_write_ns / 1000000000.0)));

void
_transition(state_obj, descriptor_obj, input = &PL_sv_undef)
    SV *state_obj
    SV *descriptor_obj
    SV *input
  CODE:
    les_transition_descriptor(aTHX_ les_state_from_sv(state_obj),
        descriptor_obj, input);

void
_transition_ready(state_obj)
    SV *state_obj
  PREINIT:
    les_xsstate_t *st;
  CODE:
    ENTER;
    SAVEFREESV(SvREFCNT_inc(state_obj));
    st = les_state_from_sv(state_obj);
    if (!st->closed && !st->read_paused && !st->read_eof
        && st->input_dispatch_depth == 0 && st->input_len) {
        ENTER;
        SAVEINT(st->input_dispatch_depth);
        st->input_dispatch_depth++;
        les_process_existing_input(aTHX_ st, 1);
        LEAVE;
    }
    LEAVE;

void
_close(state_obj)
    SV *state_obj
  PREINIT:
    les_xsstate_t *st;
  CODE:
    st = les_state_from_sv(state_obj);
    if (!st->closed) {
        st->closed = 1;
        les_clear_write_queue(st);
        les_discard_message_batch(st);
        st->input_start = 0;
        st->input_len = 0;
    }

int
is_read_eof(state_obj)
    SV *state_obj
  CODE:
    RETVAL = les_state_from_sv(state_obj)->read_eof ? 1 : 0;
  OUTPUT:
    RETVAL

UV
pending_bytes(state_obj)
    SV *state_obj
  CODE:
    RETVAL = les_state_from_sv(state_obj)->pending_bytes;
  OUTPUT:
    RETVAL

int
is_write_blocked(state_obj)
    SV *state_obj
  CODE:
    RETVAL = les_state_from_sv(state_obj)->write_blocked ? 1 : 0;
  OUTPUT:
    RETVAL

const char *
transport_name(state_obj)
    SV *state_obj
  CODE:
    RETVAL = les_state_from_sv(state_obj)->transport_ops->name;
  OUTPUT:
    RETVAL

int
transport_ready(state_obj)
    SV *state_obj
  CODE:
    RETVAL = les_transport_ready(les_state_from_sv(state_obj)) ? 1 : 0;
  OUTPUT:
    RETVAL

SV *
stats(state_obj)
    SV *state_obj
  PREINIT:
    les_xsstate_t *st;
    HV *hv;
  CODE:
    st = les_state_from_sv(state_obj);
    hv = newHV();

    hv_stores(hv, "read_ready_calls", newSVuv(st->read_ready_calls));
    hv_stores(hv, "read_calls", newSVuv(st->read_calls));
    hv_stores(hv, "bytes_read", newSVuv(st->bytes_read));
    hv_stores(hv, "read_eagain_count", newSVuv(st->read_eagain_count));
    hv_stores(hv, "read_eintr_count", newSVuv(st->read_eintr_count));
    hv_stores(hv, "eof_count", newSVuv(st->eof_count));
    hv_stores(hv, "read_error_count", newSVuv(st->read_error_count));
    hv_stores(hv, "delivery_calls", newSVuv(st->delivery_calls));
    hv_stores(hv, "read_batch_bytes",
        newSVuv(st->descriptor->read_batch_bytes));
    hv_stores(hv, "read_batch_flushes", newSVuv(st->read_batch_flushes));
    hv_stores(hv, "read_batch_peak_bytes",
        newSVuv(st->read_batch_peak_bytes));
    hv_stores(hv, "input_appends", newSVuv(st->input_appends));
    hv_stores(hv, "input_compactions", newSVuv(st->input_compactions));
    hv_stores(hv, "input_peak_bytes", newSVuv(st->input_peak_bytes));
    hv_stores(hv, "input_buffered_bytes", newSVuv(st->input_len));
    hv_stores(hv, "delimiter_searches", newSVuv(st->delimiter_searches));
    hv_stores(hv, "frames_emitted", newSVuv(st->frames_emitted));
    hv_stores(hv, "message_batch_size",
        newSVuv(st->descriptor->message_batch_size));
    hv_stores(hv, "message_callback_calls",
        newSVuv(st->message_callback_calls));
    hv_stores(hv, "message_batch_calls", newSVuv(st->message_batch_calls));
    hv_stores(hv, "message_batch_peak_messages",
        newSVuv(st->message_batch_peak_messages));
    hv_stores(hv, "message_batch_peak_bytes",
        newSVuv(st->message_batch_peak_bytes));
    hv_stores(hv, "framing_error_count", newSVuv(st->framing_error_count));
    hv_stores(hv, "transition_count", newSVuv(st->transition_count));

    hv_stores(hv, "write_submit_calls", newSVuv(st->write_submit_calls));
    hv_stores(hv, "write_ready_calls", newSVuv(st->write_ready_calls));
    hv_stores(hv, "write_calls", newSVuv(st->write_calls));
    hv_stores(hv, "writev_calls", newSVuv(st->writev_calls));
    hv_stores(hv, "bytes_written", newSVuv(st->bytes_written));
    hv_stores(hv, "write_eagain_count", newSVuv(st->write_eagain_count));
    hv_stores(hv, "write_eintr_count", newSVuv(st->write_eintr_count));
    hv_stores(hv, "write_error_count", newSVuv(st->write_error_count));
    hv_stores(hv, "output_limit_count", newSVuv(st->output_limit_count));
    hv_stores(hv, "queued_segments", newSVuv(st->queued_segments));
    hv_stores(hv, "queue_peak_bytes", newSVuv(st->queue_peak_bytes));
    hv_stores(hv, "drain_calls", newSVuv(st->drain_calls));
    hv_stores(hv, "empty_calls", newSVuv(st->empty_calls));
    hv_stores(hv, "pending_bytes", newSVuv(st->pending_bytes));
    hv_stores(hv, "write_blocked", newSViv(st->write_blocked ? 1 : 0));
    hv_stores(hv, "activity_tracking",
        newSViv(st->activity_tracking ? 1 : 0));
    hv_stores(hv, "activity_clock_calls",
        newSVuv(st->activity_clock_calls));

    RETVAL = newRV_noinc((SV *)hv);
  OUTPUT:
    RETVAL
