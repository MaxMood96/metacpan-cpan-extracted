/*
 * Linux::Event::Stream native I/O state
 * =====================================
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
 * Separation from Linux::Event internals
 * --------------------------------------
 * This file intentionally does not include Linux::Event private C headers.
 * The reactor passes watcher data directly to these XSUBs through the private
 * callback-data hook established by the prior Stream milestone.  That keeps
 * the core a generic readiness engine while allowing Stream to be developed
 * and benchmarked independently.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>
#include <sys/uio.h>
#include "stream_transport_abi.h"
#include <sys/socket.h>

#define LES_WRITE_FLOW_OK 0x01
#define LES_WRITE_QUEUED  0x02
#define LES_IOV_MAX       64
#define LES_READ_DELIVER   0
#define LES_READ_DELIMITER 2
#define LES_READ_FIXED     3
#define LES_READ_LENGTH    4
#define LES_READ_NETSTRING 5
#define LES_READ_VARINT    6
#define LES_READ_DECIMAL   7

/*
 * Native transport boundary
 * -------------------------
 * Stream owns buffering, framing, backpressure, and lifecycle semantics. A
 * transport owns the mechanical byte movement beneath them. The plain-fd
 * provider below preserves the original read/write/writev behavior. A later
 * adjacent TLS extension can supply the same operations without teaching the
 * parser, queue, or XSLoop about encryption policy.
 */
typedef struct les_plain_transport_s {
    int fd;
} les_plain_transport_t;

static les_transport_result_t
les_plain_result(ssize_t count, int retry_status)
{
    les_transport_result_t result;
    result.count = count;
    result.error = 0;

    if (count > 0)
        result.status = LES_TRANSPORT_OK;
    else if (count == 0)
        result.status = LES_TRANSPORT_EOF;
    else if (errno == EINTR)
        result.status = LES_TRANSPORT_INTERRUPT;
    else if (errno == EAGAIN || errno == EWOULDBLOCK)
        result.status = retry_status;
    else {
        result.status = LES_TRANSPORT_ERROR;
        result.error = errno;
    }
    return result;
}

static les_transport_result_t
les_plain_read(void *context, void *buffer, size_t length)
{
    les_plain_transport_t *plain = (les_plain_transport_t *)context;
    return les_plain_result(read(plain->fd, buffer, length),
        LES_TRANSPORT_WANT_READ);
}

static les_transport_result_t
les_plain_write(void *context, const void *buffer, size_t length)
{
    les_plain_transport_t *plain = (les_plain_transport_t *)context;
    return les_plain_result(write(plain->fd, buffer, length),
        LES_TRANSPORT_WANT_WRITE);
}

static les_transport_result_t
les_plain_writev(void *context, const struct iovec *vectors, int count)
{
    les_plain_transport_t *plain = (les_plain_transport_t *)context;
    return les_plain_result(writev(plain->fd, vectors, count),
        LES_TRANSPORT_WANT_WRITE);
}

static les_transport_result_t
les_plain_shutdown_write(void *context)
{
    les_plain_transport_t *plain = (les_plain_transport_t *)context;
    les_transport_result_t result = { 0, LES_TRANSPORT_OK, 0 };
    if (shutdown(plain->fd, SHUT_WR) != 0) {
        result.status = LES_TRANSPORT_ERROR;
        result.error = errno;
    }
    return result;
}

static les_transport_result_t
les_plain_drive(void *context)
{
    les_transport_result_t result = { 0, LES_TRANSPORT_OK, 0 };
    (void)context;
    return result;
}

static int les_plain_is_ready(void *context) { (void)context; return 1; }
static const char *les_plain_error_string(void *context)
{ (void)context; return "plain transport error"; }

static const les_transport_ops_t les_plain_transport_ops = {
    LES_TRANSPORT_ABI_VERSION,
    "plain",
    les_plain_read,
    les_plain_write,
    les_plain_writev,
    les_plain_shutdown_write,
    les_plain_drive,
    les_plain_is_ready,
    les_plain_error_string
};

typedef struct les_write_seg_s {
    SV *sv;
    STRLEN off;
    STRLEN len;
    struct les_write_seg_s *next;
} les_write_seg_t;

typedef struct les_descriptor_s {
    size_t read_size;
    int read_mode;
    UV max_buffer;

    char *delimiter;
    size_t delimiter_len;
    int include_delimiter;
    int has_max_frame;
    UV max_frame;
    UV fixed_size;
    int prefix_bytes;
    int prefix_little;
    int include_prefix;

    UV high_watermark;
    UV low_watermark;
    UV max_pending_bytes;

    SV *deliver_cb;
    SV *message_cb;
    SV *drain_cb;
    SV *eof_cb;
    SV *read_error_cb;
    SV *write_error_cb;
    SV *output_limit_cb;
    SV *write_empty_cb;
    SV *framing_error_cb;
} les_descriptor_t;

typedef struct les_xsstate_s {
    int fd;
    les_plain_transport_t plain_transport;
    const les_transport_ops_t *transport_ops;
    void *transport_context;
    les_descriptor_t *descriptor;
    SV *descriptor_sv;
    SV *transport_provider_sv;

    /* Read engine. */
    char *read_buffer;      /* raw/deliver mode scratch storage */
    int read_paused;
    int read_eof;

    /* Native framed-input storage. Logical bytes are [input_start, input_start + input_len). */
    char *input_buffer;
    size_t input_start;
    size_t input_len;
    size_t input_cap;

    /* Per-connection delimiter scan state. */
    size_t delimiter_scan;

    /* Non-zero while an input callback/parser stack is active. A descriptor
     * transition swaps configuration immediately, but buffered bytes are not
     * dispatched recursively from inside the old callback. */
    int input_dispatch_depth;

    /* Shared lifetime. */
    int closed;
    SV *stream_sv;

    /* Write state. */
    int write_blocked;
    les_write_seg_t *whead;
    les_write_seg_t *wtail;
    UV pending_bytes;

    /* Optional established-connection deadline activity. The ordinary Stream
     * path leaves tracking disabled and therefore pays only one predictable
     * branch after successful transport progress. */
    int activity_tracking;
    unsigned long long last_read_ns;
    unsigned long long last_write_ns;
    unsigned long long activity_clock_calls;

    /* Read instrumentation. */
    unsigned long long read_ready_calls;
    unsigned long long read_calls;
    unsigned long long bytes_read;
    unsigned long long read_eagain_count;
    unsigned long long read_eintr_count;
    unsigned long long eof_count;
    unsigned long long read_error_count;
    unsigned long long delivery_calls;
    unsigned long long input_appends;
    unsigned long long input_compactions;
    unsigned long long input_peak_bytes;
    unsigned long long delimiter_searches;
    unsigned long long frames_emitted;
    unsigned long long framing_error_count;
    unsigned long long transition_count;

    /* Write instrumentation. */
    unsigned long long write_submit_calls;
    unsigned long long write_ready_calls;
    unsigned long long write_calls;
    unsigned long long writev_calls;
    unsigned long long bytes_written;
    unsigned long long write_eagain_count;
    unsigned long long write_eintr_count;
    unsigned long long write_error_count;
    unsigned long long output_limit_count;
    unsigned long long queued_segments;
    unsigned long long queue_peak_bytes;
    unsigned long long drain_calls;
    unsigned long long empty_calls;
} les_xsstate_t;

static unsigned long long
les_activity_now_ns(pTHX)
{
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0)
        croak("clock_gettime(CLOCK_MONOTONIC) failed: %s", strerror(errno));
    return (unsigned long long)now.tv_sec * 1000000000ULL
        + (unsigned long long)now.tv_nsec;
}

static void
les_note_read_activity(pTHX_ les_xsstate_t *st)
{
    if (!st->activity_tracking)
        return;
    st->last_read_ns = les_activity_now_ns(aTHX);
    st->activity_clock_calls++;
}

static void
les_note_write_activity(pTHX_ les_xsstate_t *st)
{
    if (!st->activity_tracking)
        return;
    st->last_write_ns = les_activity_now_ns(aTHX);
    st->activity_clock_calls++;
}

/* Keep the ordinary fd path direct and predictable. Provider indirection is
 * paid only after a future adjacent transport replaces the plain ops table. */
static les_transport_result_t
les_transport_read(les_xsstate_t *st, void *buffer, size_t length)
{
    if (st->transport_ops == &les_plain_transport_ops)
        return les_plain_result(read(st->fd, buffer, length),
            LES_TRANSPORT_WANT_READ);
    return st->transport_ops->read_bytes(
        st->transport_context, buffer, length);
}

static les_transport_result_t
les_transport_write(les_xsstate_t *st, const void *buffer, size_t length)
{
    if (st->transport_ops == &les_plain_transport_ops)
        return les_plain_result(write(st->fd, buffer, length),
            LES_TRANSPORT_WANT_WRITE);
    return st->transport_ops->write_bytes(
        st->transport_context, buffer, length);
}

static les_transport_result_t
les_transport_writev(les_xsstate_t *st, const struct iovec *vectors, int count)
{
    if (st->transport_ops == &les_plain_transport_ops)
        return les_plain_result(writev(st->fd, vectors, count),
            LES_TRANSPORT_WANT_WRITE);
    return st->transport_ops->write_vectors(
        st->transport_context, vectors, count);
}

static les_transport_result_t
les_transport_shutdown_write(les_xsstate_t *st)
{
    if (st->transport_ops == &les_plain_transport_ops)
        return les_plain_shutdown_write(&st->plain_transport);
    return st->transport_ops->shutdown_write(st->transport_context);
}

static les_xsstate_t *
les_state_from_sv(SV *sv)
{
    if (!sv_isobject(sv) || !SvROK(sv))
        croak("not a Linux::Event::Stream::XSState object");
    return INT2PTR(les_xsstate_t *, SvIV((SV *)SvRV(sv)));
}

static les_descriptor_t *
les_descriptor_from_sv(SV *sv)
{
    if (!sv_isobject(sv) || !SvROK(sv))
        croak("not a Linux::Event::Stream::XSDescriptor object");
    return INT2PTR(les_descriptor_t *, SvIV((SV *)SvRV(sv)));
}

static SV *
les_store_cb(SV *cb, const char *name)
{
    SV *cv;
    if (!cb || !SvOK(cb) || !SvROK(cb) || SvTYPE(SvRV(cb)) != SVt_PVCV)
        croak("%s must be a coderef", name);
    cv = SvRV(cb);
    SvREFCNT_inc(cv);
    return cv;
}

static SV *
les_store_optional_cb(SV *cb, const char *name)
{
    if (!cb || !SvOK(cb))
        return NULL;
    return les_store_cb(cb, name);
}

static void
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

static void
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

static void
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

static int
les_transport_ready(les_xsstate_t *st)
{
    return st->transport_ops == &les_plain_transport_ops
        || st->transport_ops->is_ready(st->transport_context);
}

static int
les_drive_transport(pTHX_ les_xsstate_t *st, const char *operation)
{
    les_transport_result_t result;

    if (les_transport_ready(st))
        return 1;
    result = st->transport_ops->drive(st->transport_context);
    les_call_transport_event(aTHX_ st, result.status, operation);
    return result.status == LES_TRANSPORT_OK && les_transport_ready(st);
}

static void
les_call_deliver(pTHX_ les_xsstate_t *st, SV *bytes)
{
    les_call_two(aTHX_ st->descriptor->deliver_cb, st->stream_sv, bytes);
    st->delivery_calls++;
}

static void
les_call_message(pTHX_ les_xsstate_t *st, SV *message)
{
    if (!st->descriptor->message_cb)
        return;
    st->frames_emitted++;
    les_call_two(aTHX_ st->descriptor->message_cb, st->stream_sv, message);
}

static void
les_call_framing_error(pTHX_ les_xsstate_t *st, const char *message)
{
    SV *msg;
    if (!st->descriptor->framing_error_cb)
        return;
    st->framing_error_count++;
    msg = sv_2mortal(newSVpv(message, 0));
    les_call_two(aTHX_ st->descriptor->framing_error_cb, st->stream_sv, msg);
}

static void
les_call_eof(pTHX_ les_xsstate_t *st)
{
    les_call_one(aTHX_ st->descriptor->eof_cb, st->stream_sv);
}

static void
les_call_read_error(pTHX_ les_xsstate_t *st, int err)
{
    SV *errno_sv = sv_2mortal(newSViv(err));
    les_call_two(aTHX_ st->descriptor->read_error_cb, st->stream_sv, errno_sv);
}

static void
les_call_write_error(pTHX_ les_xsstate_t *st, int err)
{
    SV *errno_sv = sv_2mortal(newSViv(err));
    les_call_two(aTHX_ st->descriptor->write_error_cb, st->stream_sv, errno_sv);
}

static void
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

static void
les_call_drain(pTHX_ les_xsstate_t *st)
{
    if (!st->descriptor->drain_cb)
        return;
    st->drain_calls++;
    les_call_one(aTHX_ st->descriptor->drain_cb, st->stream_sv);
}

static void
les_call_empty(pTHX_ les_xsstate_t *st)
{
    st->empty_calls++;
    les_call_one(aTHX_ st->descriptor->write_empty_cb, st->stream_sv);
}

static void
les_clear_write_queue(les_xsstate_t *st)
{
    les_write_seg_t *seg = st->whead;
    while (seg) {
        les_write_seg_t *next = seg->next;
        if (seg->sv)
            SvREFCNT_dec(seg->sv);
        free(seg);
        seg = next;
    }
    st->whead = NULL;
    st->wtail = NULL;
    st->pending_bytes = 0;
    st->write_blocked = 0;
}

static void
les_queue_bytes(les_xsstate_t *st, const char *data, STRLEN len)
{
    les_write_seg_t *seg;

    if (len == 0)
        return;

    seg = (les_write_seg_t *)calloc(1, sizeof(*seg));
    if (!seg)
        croak("calloc Stream write segment failed");

    seg->sv = newSVpvn(data, len);
    seg->off = 0;
    seg->len = len;

    if (st->wtail)
        st->wtail->next = seg;
    else
        st->whead = seg;
    st->wtail = seg;

    st->pending_bytes += (UV)len;
    st->queued_segments++;
    if ((unsigned long long)st->pending_bytes > st->queue_peak_bytes)
        st->queue_peak_bytes = (unsigned long long)st->pending_bytes;
}

static void
les_consume_written(les_xsstate_t *st, size_t count)
{
    size_t remaining = count;

    while (remaining && st->whead) {
        les_write_seg_t *seg = st->whead;
        size_t avail = (size_t)(seg->len - seg->off);

        if (remaining < avail) {
            seg->off += (STRLEN)remaining;
            st->pending_bytes -= (UV)remaining;
            return;
        }

        remaining -= avail;
        st->pending_bytes -= (UV)avail;
        st->whead = seg->next;
        if (!st->whead)
            st->wtail = NULL;
        SvREFCNT_dec(seg->sv);
        free(seg);
    }
}

/*
 * Clear the blocked state before invoking on_drain.  If the callback writes
 * enough data to cross the high watermark again, _write() establishes a new
 * blocked interval and a later drain transition can fire normally.
 */
static void
les_maybe_drain_transition(pTHX_ les_xsstate_t *st)
{
    if (!st->write_blocked)
        return;
    if (st->pending_bytes > st->descriptor->low_watermark)
        return;

    st->write_blocked = 0;
    les_call_drain(aTHX_ st);
}

static const char *
les_input_data(const les_xsstate_t *st)
{
    return st->input_buffer ? st->input_buffer + st->input_start : NULL;
}

static int
les_input_reserve(les_xsstate_t *st, size_t extra)
{
    size_t need;
    size_t cap;
    char *next;

    if (extra == 0)
        return 1;
    if (extra > (size_t)-1 - st->input_len)
        croak("Stream input buffer size overflow");
    need = st->input_len + extra;

    if (st->input_buffer && st->input_start + need <= st->input_cap)
        return 1;

    if (st->input_buffer && need <= st->input_cap) {
        if (st->input_len)
            memmove(st->input_buffer, st->input_buffer + st->input_start, st->input_len);
        st->input_start = 0;
        st->input_compactions++;
        return 1;
    }

    cap = st->input_cap ? st->input_cap : 4096;
    while (cap < need) {
        size_t grown = cap < ((size_t)-1 / 2) ? cap * 2 : need;
        if (grown < cap || grown < need)
            grown = need;
        cap = grown;
    }

    next = (char *)malloc(cap);
    if (!next)
        croak("malloc Stream input buffer failed");
    if (st->input_len)
        memcpy(next, les_input_data(st), st->input_len);
    free(st->input_buffer);
    st->input_buffer = next;
    st->input_cap = cap;
    st->input_start = 0;
    return 1;
}

static void
les_input_consume(les_xsstate_t *st, size_t count)
{
    if (count > st->input_len)
        croak("internal Stream input consume exceeds buffered bytes");
    st->input_start += count;
    st->input_len -= count;
    st->delimiter_scan = 0;
    if (st->input_len == 0)
        st->input_start = 0;
}

static size_t
les_find_bytes(const char *hay, size_t hlen, const char *needle, size_t nlen, size_t start)
{
    const unsigned char first = (unsigned char)needle[0];
    size_t pos;

    if (nlen == 0 || start > hlen || nlen > hlen)
        return (size_t)-1;
    if (start > hlen - nlen)
        return (size_t)-1;

    pos = start;
    while (pos <= hlen - nlen) {
        const void *found = memchr(hay + pos, first, hlen - nlen - pos + 1);
        if (!found)
            return (size_t)-1;
        pos = (size_t)((const char *)found - hay);
        if (nlen == 1 || memcmp(hay + pos, needle, nlen) == 0)
            return pos;
        pos++;
    }
    return (size_t)-1;
}

static void
les_process_delimiter(pTHX_ les_xsstate_t *st)
{
    les_descriptor_t *descriptor = st->descriptor;

    while (!st->closed && !st->read_paused && st->input_len > 0) {
        const char *data = les_input_data(st);
        size_t pos;

        st->delimiter_searches++;
        pos = les_find_bytes(data, st->input_len, st->descriptor->delimiter,
            st->descriptor->delimiter_len, st->delimiter_scan);

        if (pos == (size_t)-1) {
            if (st->descriptor->has_max_frame) {
                unsigned long long allowed = (unsigned long long)st->descriptor->max_frame
                    + (unsigned long long)st->descriptor->delimiter_len - 1ULL;
                if ((unsigned long long)st->input_len > allowed) {
                    char msg[128];
                    snprintf(msg, sizeof(msg),
                        "frame exceeds max_frame=%llu without delimiter",
                        (unsigned long long)st->descriptor->max_frame);
                    les_call_framing_error(aTHX_ st, msg);
                    return;
                }
            }

            if (st->descriptor->delimiter_len > 1
                && st->input_len >= st->descriptor->delimiter_len - 1)
                st->delimiter_scan = st->input_len
                    - (st->descriptor->delimiter_len - 1);
            else
                st->delimiter_scan = 0;
            return;
        }

        if (st->descriptor->has_max_frame && (UV)pos > st->descriptor->max_frame) {
            char msg[128];
            snprintf(msg, sizeof(msg), "frame exceeds max_frame=%llu",
                (unsigned long long)st->descriptor->max_frame);
            les_call_framing_error(aTHX_ st, msg);
            return;
        }

        {
            size_t consume = pos + st->descriptor->delimiter_len;
            size_t msglen = st->descriptor->include_delimiter ? consume : pos;
            SV *message = sv_2mortal(newSVpvn(data, (STRLEN)msglen));
            les_input_consume(st, consume);
            les_call_message(aTHX_ st, message);
            if (st->descriptor != descriptor)
                return;
        }
    }
}


static UV
les_decode_prefix(const unsigned char *p, int bytes, int little)
{
    UV value = 0;
    int i;

    if (little) {
        for (i = bytes - 1; i >= 0; i--)
            value = (value << 8) | (UV)p[i];
    } else {
        for (i = 0; i < bytes; i++)
            value = (value << 8) | (UV)p[i];
    }
    return value;
}

static int
les_frame_fits_buffer(pTHX_ les_xsstate_t *st, UV prefix_bytes, UV payload_len)
{
    if (st->descriptor->max_buffer && payload_len > st->descriptor->max_buffer) {
        char msg[160];
        snprintf(msg, sizeof(msg),
            "declared frame length=%llu exceeds max_buffer=%llu",
            (unsigned long long)payload_len,
            (unsigned long long)st->descriptor->max_buffer);
        les_call_framing_error(aTHX_ st, msg);
        return 0;
    }
    if (prefix_bytes > (UV)-1 - payload_len) {
        les_call_framing_error(aTHX_ st, "frame length overflow");
        return 0;
    }
    if (st->descriptor->max_buffer
        && prefix_bytes + payload_len > st->descriptor->max_buffer) {
        char msg[160];
        snprintf(msg, sizeof(msg),
            "framed message requires %llu bytes, exceeds max_buffer=%llu",
            (unsigned long long)(prefix_bytes + payload_len),
            (unsigned long long)st->descriptor->max_buffer);
        les_call_framing_error(aTHX_ st, msg);
        return 0;
    }
    return 1;
}

static void
les_process_fixed(pTHX_ les_xsstate_t *st)
{
    les_descriptor_t *descriptor = st->descriptor;
    size_t size = (size_t)st->descriptor->fixed_size;

    while (!st->closed && !st->read_paused && st->input_len >= size) {
        const char *data = les_input_data(st);
        SV *message = sv_2mortal(newSVpvn(data, (STRLEN)size));
        les_input_consume(st, size);
        les_call_message(aTHX_ st, message);
        if (st->descriptor != descriptor)
            return;
    }
}

static void
les_process_length(pTHX_ les_xsstate_t *st)
{
    les_descriptor_t *descriptor = st->descriptor;
    const size_t prefix = (size_t)st->descriptor->prefix_bytes;

    while (!st->closed && !st->read_paused) {
        const char *data;
        UV payload_len;
        UV total_uv;
        size_t total;
        size_t offset;
        size_t msglen;
        SV *message;

        if (st->input_len < prefix)
            return;

        data = les_input_data(st);
        payload_len = les_decode_prefix((const unsigned char *)data,
            st->descriptor->prefix_bytes, st->descriptor->prefix_little);

        if (st->descriptor->has_max_frame
            && payload_len > st->descriptor->max_frame) {
            char msg[128];
            snprintf(msg, sizeof(msg), "frame exceeds max_frame=%llu",
                (unsigned long long)st->descriptor->max_frame);
            les_call_framing_error(aTHX_ st, msg);
            return;
        }
        if (!les_frame_fits_buffer(aTHX_ st, (UV)prefix, payload_len))
            return;

        total_uv = (UV)prefix + payload_len;
        if (total_uv > (UV)(size_t)-1) {
            les_call_framing_error(aTHX_ st, "frame length exceeds native size_t");
            return;
        }
        total = (size_t)total_uv;
        if (st->input_len < total)
            return;

        offset = st->descriptor->include_prefix ? 0 : prefix;
        msglen = st->descriptor->include_prefix ? total : (size_t)payload_len;
        message = sv_2mortal(newSVpvn(data + offset, (STRLEN)msglen));
        les_input_consume(st, total);
        les_call_message(aTHX_ st, message);
        if (st->descriptor != descriptor)
            return;
    }
}

static void
les_process_netstring(pTHX_ les_xsstate_t *st)
{
    les_descriptor_t *descriptor = st->descriptor;

    while (!st->closed && !st->read_paused && st->input_len > 0) {
        const char *data = les_input_data(st);
        size_t i = 0;
        UV payload_len = 0;
        UV payload_offset_uv;
        UV total_uv;
        size_t payload_offset;
        size_t total;
        SV *message;

        if ((unsigned char)data[0] < '0' || (unsigned char)data[0] > '9') {
            les_call_framing_error(aTHX_ st, "invalid netstring length");
            return;
        }

        while (i < st->input_len && data[i] != ':') {
            unsigned char c = (unsigned char)data[i];
            if (c < '0' || c > '9') {
                les_call_framing_error(aTHX_ st, "invalid netstring length");
                return;
            }
            if (i >= 20) {
                les_call_framing_error(aTHX_ st, "netstring length field too long");
                return;
            }
            if (payload_len > ((UV)-1 - (UV)(c - '0')) / 10) {
                les_call_framing_error(aTHX_ st, "netstring length overflow");
                return;
            }
            payload_len = payload_len * 10 + (UV)(c - '0');
            i++;
        }

        if (i == st->input_len) {
            if (i > 20)
                les_call_framing_error(aTHX_ st, "netstring length field too long");
            return;
        }
        if (i == 0) {
            les_call_framing_error(aTHX_ st, "invalid netstring length");
            return;
        }
        if (i > 1 && data[0] == '0') {
            les_call_framing_error(aTHX_ st, "invalid netstring leading zero");
            return;
        }
        if (st->descriptor->has_max_frame
            && payload_len > st->descriptor->max_frame) {
            char msg[128];
            snprintf(msg, sizeof(msg), "frame exceeds max_frame=%llu",
                (unsigned long long)st->descriptor->max_frame);
            les_call_framing_error(aTHX_ st, msg);
            return;
        }

        payload_offset_uv = (UV)i + 1;
        if (payload_offset_uv > (UV)-1 - payload_len - 1) {
            les_call_framing_error(aTHX_ st, "netstring frame length overflow");
            return;
        }
        total_uv = payload_offset_uv + payload_len + 1;
        if (st->descriptor->max_buffer && total_uv > st->descriptor->max_buffer) {
            char msg[160];
            snprintf(msg, sizeof(msg),
                "framed message requires %llu bytes, exceeds max_buffer=%llu",
                (unsigned long long)total_uv,
                (unsigned long long)st->descriptor->max_buffer);
            les_call_framing_error(aTHX_ st, msg);
            return;
        }
        if (total_uv > (UV)(size_t)-1) {
            les_call_framing_error(aTHX_ st, "netstring frame length exceeds native size_t");
            return;
        }

        total = (size_t)total_uv;
        if (st->input_len < total)
            return;
        if (data[total - 1] != ',') {
            les_call_framing_error(aTHX_ st, "invalid netstring terminator");
            return;
        }

        payload_offset = (size_t)payload_offset_uv;
        message = sv_2mortal(newSVpvn(data + payload_offset, (STRLEN)payload_len));
        les_input_consume(st, total);
        les_call_message(aTHX_ st, message);
        if (st->descriptor != descriptor)
            return;
    }
}

/* Unsigned canonical LEB128 payload length, limited to a 64-bit wire value. */
static void
les_process_varint(pTHX_ les_xsstate_t *st)
{
    les_descriptor_t *descriptor = st->descriptor;

    while (!st->closed && !st->read_paused && st->input_len > 0) {
        const unsigned char *data = (const unsigned char *)les_input_data(st);
        const unsigned int uv_bits = (unsigned int)(sizeof(UV) * 8);
        UV payload_len = 0;
        size_t i;
        size_t prefix = 0;
        UV total_uv;
        size_t total;
        size_t offset;
        size_t msglen;
        SV *message;

        for (i = 0; i < st->input_len && i < 10; i++) {
            unsigned char byte = data[i];
            UV low = (UV)(byte & 0x7f);
            unsigned int shift = (unsigned int)(i * 7);

            if (i == 9 && (low > 1 || (byte & 0x80))) {
                les_call_framing_error(aTHX_ st, "varint length overflow");
                return;
            }
            if (low) {
                if (shift >= uv_bits || low > ((UV)-1 >> shift)) {
                    les_call_framing_error(aTHX_ st, "varint length exceeds native UV");
                    return;
                }
                payload_len |= low << shift;
            }
            if (!(byte & 0x80)) {
                if (i > 0 && low == 0) {
                    les_call_framing_error(aTHX_ st, "non-canonical varint length");
                    return;
                }
                prefix = i + 1;
                break;
            }
        }

        if (prefix == 0) {
            if (st->input_len >= 10)
                les_call_framing_error(aTHX_ st, "varint length prefix too long");
            return;
        }
        if (st->descriptor->has_max_frame
            && payload_len > st->descriptor->max_frame) {
            char msg[128];
            snprintf(msg, sizeof(msg), "frame exceeds max_frame=%llu",
                (unsigned long long)st->descriptor->max_frame);
            les_call_framing_error(aTHX_ st, msg);
            return;
        }
        if (!les_frame_fits_buffer(aTHX_ st, (UV)prefix, payload_len))
            return;

        total_uv = (UV)prefix + payload_len;
        if (total_uv > (UV)(size_t)-1) {
            les_call_framing_error(aTHX_ st, "varint frame length exceeds native size_t");
            return;
        }
        total = (size_t)total_uv;
        if (st->input_len < total)
            return;

        offset = st->descriptor->include_prefix ? 0 : prefix;
        msglen = st->descriptor->include_prefix ? total : (size_t)payload_len;
        message = sv_2mortal(newSVpvn((const char *)data + offset, (STRLEN)msglen));
        les_input_consume(st, total);
        les_call_message(aTHX_ st, message);
        if (st->descriptor != descriptor)
            return;
    }
}

/* ASCII decimal payload length followed by one configured separator byte. */
static void
les_process_decimal_length(pTHX_ les_xsstate_t *st)
{
    les_descriptor_t *descriptor = st->descriptor;
    const unsigned char separator = (unsigned char)st->descriptor->delimiter[0];

    while (!st->closed && !st->read_paused && st->input_len > 0) {
        const unsigned char *data = (const unsigned char *)les_input_data(st);
        size_t i = 0;
        size_t prefix;
        UV payload_len = 0;
        UV total_uv;
        size_t total;
        size_t offset;
        size_t msglen;
        SV *message;

        while (i < st->input_len && data[i] != separator) {
            unsigned char c = data[i];
            if (c < '0' || c > '9') {
                les_call_framing_error(aTHX_ st, "invalid decimal length");
                return;
            }
            if (i >= 20) {
                les_call_framing_error(aTHX_ st, "decimal length field too long");
                return;
            }
            if (payload_len > ((UV)-1 - (UV)(c - '0')) / 10) {
                les_call_framing_error(aTHX_ st, "decimal length overflow");
                return;
            }
            payload_len = payload_len * 10 + (UV)(c - '0');
            i++;
        }

        if (i == st->input_len) {
            if (i > 20)
                les_call_framing_error(aTHX_ st, "decimal length field too long");
            return;
        }
        if (i == 0) {
            les_call_framing_error(aTHX_ st, "invalid decimal length");
            return;
        }
        if (i > 1 && data[0] == '0') {
            les_call_framing_error(aTHX_ st, "invalid decimal length leading zero");
            return;
        }
        if (st->descriptor->has_max_frame
            && payload_len > st->descriptor->max_frame) {
            char msg[128];
            snprintf(msg, sizeof(msg), "frame exceeds max_frame=%llu",
                (unsigned long long)st->descriptor->max_frame);
            les_call_framing_error(aTHX_ st, msg);
            return;
        }

        prefix = i + 1;
        if (!les_frame_fits_buffer(aTHX_ st, (UV)prefix, payload_len))
            return;
        total_uv = (UV)prefix + payload_len;
        if (total_uv > (UV)(size_t)-1) {
            les_call_framing_error(aTHX_ st, "decimal frame length exceeds native size_t");
            return;
        }
        total = (size_t)total_uv;
        if (st->input_len < total)
            return;

        offset = st->descriptor->include_prefix ? 0 : prefix;
        msglen = st->descriptor->include_prefix ? total : (size_t)payload_len;
        message = sv_2mortal(newSVpvn((const char *)data + offset, (STRLEN)msglen));
        les_input_consume(st, total);
        les_call_message(aTHX_ st, message);
        if (st->descriptor != descriptor)
            return;
    }
}

static void
les_process_buffered(pTHX_ les_xsstate_t *st)
{
    if (st->descriptor->read_mode == LES_READ_DELIMITER)
        les_process_delimiter(aTHX_ st);
    else if (st->descriptor->read_mode == LES_READ_FIXED)
        les_process_fixed(aTHX_ st);
    else if (st->descriptor->read_mode == LES_READ_LENGTH)
        les_process_length(aTHX_ st);
    else if (st->descriptor->read_mode == LES_READ_NETSTRING)
        les_process_netstring(aTHX_ st);
    else if (st->descriptor->read_mode == LES_READ_VARINT)
        les_process_varint(aTHX_ st);
    else if (st->descriptor->read_mode == LES_READ_DECIMAL)
        les_process_decimal_length(aTHX_ st);
}

/*
 * Dispatch bytes that were already in native storage when the Stream changed
 * protocol. Framed-to-framed transitions reinterpret the untouched suffix
 * with the new parser. Framed-to-raw transitions deliver that suffix once as
 * an ordinary raw chunk. A callback may transition again; in that case the
 * loop restarts under the newest descriptor without recursive parser entry.
 */
static void
les_process_existing_input(pTHX_ les_xsstate_t *st)
{
    while (!st->closed && !st->read_paused && !st->read_eof && st->input_len) {
        les_descriptor_t *descriptor = st->descriptor;

        if (descriptor->read_mode == LES_READ_DELIVER) {
            const char *data = les_input_data(st);
            size_t len = st->input_len;
            SV *bytes = sv_2mortal(newSVpvn(data, (STRLEN)len));
            les_input_consume(st, len);
            les_call_deliver(aTHX_ st, bytes);
        } else {
            les_process_buffered(aTHX_ st);
        }

        if (st->descriptor != descriptor)
            continue;
        return;
    }
}

/*
 * Swap only immutable protocol/type configuration. The connection fd,
 * watcher-owned XSState, queued output, application object, instrumentation,
 * pause/EOF state, and unread native input remain connection-local and live.
 * No callbacks are invoked here; Perl reblesses the Stream and updates its
 * descriptor hash before asking XS to dispatch buffered bytes.
 */
static void
les_transition_descriptor(pTHX_ les_xsstate_t *st, SV *descriptor_obj,
    SV *input_sv)
{
    les_descriptor_t *next_descriptor;
    SV *next_descriptor_sv;
    SV *old_descriptor_sv;
    const char *injected = NULL;
    STRLEN injected_len = 0;
    size_t total_input;
    char *next_input_buffer = NULL;
    size_t next_input_cap = 0;
    char *next_read_buffer = NULL;

    if (!st || st->closed)
        croak("transition_to(): stream is closed");

    next_descriptor = les_descriptor_from_sv(descriptor_obj);
    if (!next_descriptor)
        croak("transition_to(): target descriptor is closed");
    if (next_descriptor == st->descriptor)
        croak("transition_to(): target Stream type is already active");

    if (input_sv && SvOK(input_sv))
        injected = SvPVbyte(input_sv, injected_len);
    if ((size_t)injected_len > (size_t)-1 - st->input_len)
        croak("transition_to(): input size overflow");
    total_input = st->input_len + (size_t)injected_len;

    if (next_descriptor->read_mode != LES_READ_DELIVER
        && next_descriptor->max_buffer
        && (UV)total_input > next_descriptor->max_buffer)
        croak("transition_to(): preserved input exceeds target max_buffer");
    if (next_descriptor->max_pending_bytes
        && st->pending_bytes > next_descriptor->max_pending_bytes)
        croak("transition_to(): queued output exceeds target max_pending_bytes");

    /* Allocate every replacement before mutating live state. A failed
     * transition therefore leaves the old descriptor and buffers intact. */
    if (next_descriptor->read_mode == LES_READ_DELIVER) {
        next_read_buffer = (char *)malloc(next_descriptor->read_size);
        if (!next_read_buffer)
            croak("transition_to(): malloc raw read buffer failed");
    }

    if (injected_len) {
        next_input_cap = total_input < 4096 ? 4096 : total_input;
        next_input_buffer = (char *)malloc(next_input_cap);
        if (!next_input_buffer) {
            free(next_read_buffer);
            croak("transition_to(): malloc preserved input buffer failed");
        }
        if (st->input_len)
            memcpy(next_input_buffer, les_input_data(st), st->input_len);
        memcpy(next_input_buffer + st->input_len, injected,
            (size_t)injected_len);
    }

    next_descriptor_sv = newSVsv(descriptor_obj);
    old_descriptor_sv = st->descriptor_sv;

    if (injected_len) {
        free(st->input_buffer);
        st->input_buffer = next_input_buffer;
        st->input_cap = next_input_cap;
        st->input_start = 0;
        st->input_len = total_input;
        st->input_appends++;
        if ((unsigned long long)st->input_len > st->input_peak_bytes)
            st->input_peak_bytes = (unsigned long long)st->input_len;
    }

    free(st->read_buffer);
    st->read_buffer = next_read_buffer;
    st->descriptor = next_descriptor;
    st->descriptor_sv = next_descriptor_sv;
    st->delimiter_scan = 0;
    st->write_blocked = st->pending_bytes > next_descriptor->high_watermark;
    st->transition_count++;

    if (old_descriptor_sv)
        SvREFCNT_dec(old_descriptor_sv);
}

static void les_write_ready(pTHX_ les_xsstate_t *st);

static void
les_read_ready(pTHX_ les_xsstate_t *st)
{
    if (!st || st->closed || st->read_eof)
        return;

    if (st->transport_ops != &les_plain_transport_ops
        && !les_drive_transport(aTHX_ st, "handshake"))
        return;
    if (st->read_paused) {
        if (st->transport_ops != &les_plain_transport_ops) {
            if (st->pending_bytes)
                les_write_ready(aTHX_ st);
            if (!st->closed)
                les_call_transport_event(aTHX_ st, LES_TRANSPORT_OK,
                    "progress");
        }
        return;
    }

    ENTER;
    SAVEINT(st->input_dispatch_depth);
    st->input_dispatch_depth++;
    st->read_ready_calls++;

    while (!st->closed && !st->read_paused && !st->read_eof) {
        les_transport_result_t result;
        char *target;
        size_t want;

        /* A parser callback may have changed the descriptor while leaving an
         * already-read suffix in native storage. Reinterpret that suffix
         * before requesting more kernel data. */
        les_process_existing_input(aTHX_ st);
        if (st->closed || st->read_paused || st->read_eof)
            break;

        want = st->descriptor->read_size;

        if (st->descriptor->read_mode == LES_READ_DELIVER) {
            target = st->read_buffer;
        } else {
            if (st->descriptor->max_buffer) {
                if (st->input_len >= st->descriptor->max_buffer) {
                    char msg[128];
                    snprintf(msg, sizeof(msg), "input buffer exceeds max_buffer=%llu",
                        (unsigned long long)st->descriptor->max_buffer);
                    les_call_framing_error(aTHX_ st, msg);
                    break;
                }
                if ((UV)want > st->descriptor->max_buffer - (UV)st->input_len)
                    want = (size_t)(st->descriptor->max_buffer - (UV)st->input_len);
            }
            les_input_reserve(st, want);
            target = st->input_buffer + st->input_start + st->input_len;
        }

        st->read_calls++;
        result = les_transport_read(st, target, want);

        if (st->transport_ops != &les_plain_transport_ops
            && result.status != LES_TRANSPORT_INTERRUPT)
            les_call_transport_event(aTHX_ st, result.status, "read");

        if (result.status == LES_TRANSPORT_OK && result.count > 0) {
            st->bytes_read += (unsigned long long)result.count;
            les_note_read_activity(aTHX_ st);

            if (st->descriptor->read_mode == LES_READ_DELIVER) {
                SV *bytes = sv_2mortal(newSVpvn(
                    st->read_buffer, (STRLEN)result.count));
                les_call_deliver(aTHX_ st, bytes);
            } else {
                st->input_len += (size_t)result.count;
                st->input_appends++;
                if ((unsigned long long)st->input_len > st->input_peak_bytes)
                    st->input_peak_bytes = (unsigned long long)st->input_len;
            }
            continue;
        }

        if (result.status == LES_TRANSPORT_EOF) {
            st->read_eof = 1;
            st->eof_count++;
            les_call_eof(aTHX_ st);
            break;
        }

        if (result.status == LES_TRANSPORT_INTERRUPT) {
            st->read_eintr_count++;
            continue;
        }

        if (result.status == LES_TRANSPORT_WANT_READ
            || result.status == LES_TRANSPORT_WANT_WRITE) {
            st->read_eagain_count++;
            break;
        }

        {
            int err = result.error;
            st->read_error_count++;
            les_call_read_error(aTHX_ st, err);
            break;
        }
    }

    LEAVE;

    if (!st->closed && st->transport_ops != &les_plain_transport_ops
        && st->pending_bytes)
        les_write_ready(aTHX_ st);
    if (!st->closed && st->transport_ops != &les_plain_transport_ops)
        les_call_transport_event(aTHX_ st, LES_TRANSPORT_OK, "progress");
}

/*
 * Submit application bytes.  This function preserves write ordering: direct
 * write() is attempted only when no older bytes are queued.  Queued data is
 * copied into an owned segment only for the partial/EAGAIN path.
 */
static int
les_write_submit(pTHX_ les_xsstate_t *st, SV *bytes_sv)
{
    STRLEN len;
    const char *data;
    STRLEN off = 0;

    if (!st || st->closed)
        return 0;

    data = SvPVbyte(bytes_sv, len);
    if (len == 0)
        return LES_WRITE_FLOW_OK;

    st->write_submit_calls++;

    if (st->pending_bytes == 0) {
        /*
         * Match the reference Stream's latency/fairness policy: make one
         * successful immediate write attempt.  EINTR is retried, but a partial
         * success queues the remainder instead of monopolizing the caller.
         */
        while (1) {
            les_transport_result_t result;

            st->write_calls++;
            result = les_transport_write(st, data, (size_t)len);

            if (st->transport_ops != &les_plain_transport_ops
                && result.status != LES_TRANSPORT_INTERRUPT)
                les_call_transport_event(aTHX_ st, result.status, "write");

            if (result.status == LES_TRANSPORT_OK && result.count > 0) {
                off = (STRLEN)result.count;
                st->bytes_written += (unsigned long long)result.count;
                les_note_write_activity(aTHX_ st);
                break;
            }

            if (result.status == LES_TRANSPORT_EOF)
                break;

            if (result.status == LES_TRANSPORT_INTERRUPT) {
                st->write_eintr_count++;
                continue;
            }

            if (result.status == LES_TRANSPORT_WANT_READ
                || result.status == LES_TRANSPORT_WANT_WRITE) {
                st->write_eagain_count++;
                break;
            }

            {
                int err = result.error;
                st->write_error_count++;
                les_call_write_error(aTHX_ st, err);
                return 0;
            }
        }

        if (off == len)
            return LES_WRITE_FLOW_OK;
    }

    if (!st->closed && off < len) {
        UV remaining = (UV)(len - off);
        UV limit = st->descriptor->max_pending_bytes;

        if (limit && (remaining > limit
            || st->pending_bytes > limit - remaining)) {
            UV attempted = st->pending_bytes;
            if (UV_MAX - attempted < remaining)
                attempted = UV_MAX;
            else
                attempted += remaining;
            les_call_output_limit(aTHX_ st, attempted);
            return 0;
        }
        les_queue_bytes(st, data + off, len - off);
    }

    if (!st->write_blocked
        && st->pending_bytes > st->descriptor->high_watermark)
        st->write_blocked = 1;

    return (st->write_blocked ? 0 : LES_WRITE_FLOW_OK)
         | (st->pending_bytes ? LES_WRITE_QUEUED : 0);
}

static void
les_write_ready(pTHX_ les_xsstate_t *st)
{
    int had_pending;

    if (!st || st->closed)
        return;

    had_pending = st->pending_bytes ? 1 : 0;
    if (!had_pending) {
        if (st->transport_ops != &les_plain_transport_ops) {
            if (les_drive_transport(aTHX_ st, "handshake"))
                les_call_transport_event(aTHX_ st, LES_TRANSPORT_OK,
                    "handshake");
        }
        return;
    }

    st->write_ready_calls++;

    while (!st->closed && st->pending_bytes > 0) {
        struct iovec iov[LES_IOV_MAX];
        les_write_seg_t *seg;
        int iovcnt = 0;
        les_transport_result_t result;

        for (seg = st->whead; seg && iovcnt < LES_IOV_MAX; seg = seg->next) {
            STRLEN pvlen;
            const char *pv = SvPV(seg->sv, pvlen);
            STRLEN avail = seg->len - seg->off;

            /* seg->sv is created by newSVpvn(), so pvlen should equal len. */
            if (seg->off > pvlen || avail > pvlen - seg->off)
                croak("internal Stream write segment bounds corrupted");

            iov[iovcnt].iov_base = (void *)(pv + seg->off);
            iov[iovcnt].iov_len = (size_t)avail;
            iovcnt++;
        }

        if (iovcnt == 0)
            break;

        st->writev_calls++;
        result = les_transport_writev(st, iov, iovcnt);

        if (st->transport_ops != &les_plain_transport_ops
            && result.status != LES_TRANSPORT_INTERRUPT)
            les_call_transport_event(aTHX_ st, result.status, "write");

        if (result.status == LES_TRANSPORT_OK && result.count > 0) {
            st->bytes_written += (unsigned long long)result.count;
            les_note_write_activity(aTHX_ st);
            les_consume_written(st, (size_t)result.count);
            les_maybe_drain_transition(aTHX_ st);
            continue;
        }

        if (result.status == LES_TRANSPORT_EOF)
            return;

        if (result.status == LES_TRANSPORT_INTERRUPT) {
            st->write_eintr_count++;
            continue;
        }

        if (result.status == LES_TRANSPORT_WANT_READ
            || result.status == LES_TRANSPORT_WANT_WRITE) {
            st->write_eagain_count++;
            return;
        }

        {
            int err = result.error;
            st->write_error_count++;
            les_call_write_error(aTHX_ st, err);
            return;
        }
    }

    if (!st->closed && had_pending && st->pending_bytes == 0) {
        les_maybe_drain_transition(aTHX_ st);
        if (!st->closed)
            les_call_empty(aTHX_ st);
    }
}

MODULE = Linux::Event::Stream    PACKAGE = Linux::Event::Stream::XSDescriptor
PROTOTYPES: DISABLE

SV *
new(CLASS, read_size, high_watermark, low_watermark, max_pending_bytes, max_buffer, read_mode, deliver_cb, message_cb, drain_cb, eof_cb, read_error_cb, write_error_cb, output_limit_cb, write_empty_cb, framing_error_cb, delimiter_sv, include_delimiter, max_frame_sv, fixed_size, prefix_bytes, prefix_little, include_prefix)
    const char *CLASS
    UV read_size
    UV high_watermark
    UV low_watermark
    UV max_pending_bytes
    UV max_buffer
    int read_mode
    SV *deliver_cb
    SV *message_cb
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
    if (low_watermark > high_watermark)
        croak("low_watermark must be <= high_watermark");
    if (read_mode != LES_READ_DELIVER
        && (read_mode < LES_READ_DELIMITER || read_mode > LES_READ_DECIMAL))
        croak("invalid Stream native read mode");
    if (read_mode == LES_READ_DELIVER
        && (!deliver_cb || !SvOK(deliver_cb)))
        croak("on_data callback required for raw Stream descriptor");
    if (read_mode != LES_READ_DELIVER
        && (!message_cb || !SvOK(message_cb)))
        croak("on_message callback required for framed Stream descriptor");
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
    st = les_state_from_sv(state_obj);
    if (!st->closed && !st->read_eof) {
        st->read_paused = 0;
        if (st->input_dispatch_depth == 0 && st->input_len) {
            ENTER;
            SAVEINT(st->input_dispatch_depth);
            st->input_dispatch_depth++;
            les_process_existing_input(aTHX_ st);
            LEAVE;
        }
    }

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
    st = les_state_from_sv(state_obj);
    if (!st->closed && !st->read_paused && !st->read_eof
        && st->input_dispatch_depth == 0 && st->input_len) {
        ENTER;
        SAVEINT(st->input_dispatch_depth);
        st->input_dispatch_depth++;
        les_process_existing_input(aTHX_ st);
        LEAVE;
    }

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
    hv_stores(hv, "input_appends", newSVuv(st->input_appends));
    hv_stores(hv, "input_compactions", newSVuv(st->input_compactions));
    hv_stores(hv, "input_peak_bytes", newSVuv(st->input_peak_bytes));
    hv_stores(hv, "input_buffered_bytes", newSVuv(st->input_len));
    hv_stores(hv, "delimiter_searches", newSVuv(st->delimiter_searches));
    hv_stores(hv, "frames_emitted", newSVuv(st->frames_emitted));
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
