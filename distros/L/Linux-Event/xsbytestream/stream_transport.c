#include "stream_internal.h"

/*
 * Native transport boundary
 * -------------------------
 * Stream owns buffering, framing, backpressure, and lifecycle semantics. A
 * transport owns the mechanical byte movement beneath them. The plain-fd
 * provider below preserves the original read/write/writev behavior. The TLS
 * extension supplies the same operations without teaching the parser, queue,
 * or XSLoop about encryption policy.
 */

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
    if (plain->read_fd < 0) {
        les_transport_result_t result = { 0, LES_TRANSPORT_ERROR, EBADF };
        return result;
    }
    return les_plain_result(read(plain->read_fd, buffer, length),
        LES_TRANSPORT_WANT_READ);
}

static les_transport_result_t
les_plain_write(void *context, const void *buffer, size_t length)
{
    les_plain_transport_t *plain = (les_plain_transport_t *)context;
    if (plain->write_fd < 0) {
        les_transport_result_t result = { 0, LES_TRANSPORT_ERROR, EBADF };
        return result;
    }
    return les_plain_result(write(plain->write_fd, buffer, length),
        LES_TRANSPORT_WANT_WRITE);
}

static les_transport_result_t
les_plain_writev(void *context, const struct iovec *vectors, int count)
{
    les_plain_transport_t *plain = (les_plain_transport_t *)context;
    if (plain->write_fd < 0) {
        les_transport_result_t result = { 0, LES_TRANSPORT_ERROR, EBADF };
        return result;
    }
    return les_plain_result(writev(plain->write_fd, vectors, count),
        LES_TRANSPORT_WANT_WRITE);
}

static les_transport_result_t
les_plain_shutdown_write(void *context)
{
    les_plain_transport_t *plain = (les_plain_transport_t *)context;
    les_transport_result_t result = { 0, LES_TRANSPORT_OK, 0 };
    if (plain->write_fd < 0) {
        result.status = LES_TRANSPORT_ERROR;
        result.error = EBADF;
        return result;
    }
    if (shutdown(plain->write_fd, SHUT_WR) != 0) {
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

const les_transport_ops_t les_plain_transport_ops = {
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

unsigned long long
les_activity_now_ns(pTHX)
{
    struct timespec now;
    if (clock_gettime(CLOCK_MONOTONIC, &now) != 0)
        croak("clock_gettime(CLOCK_MONOTONIC) failed: %s", strerror(errno));
    return (unsigned long long)now.tv_sec * 1000000000ULL
        + (unsigned long long)now.tv_nsec;
}

void
les_note_read_activity(pTHX_ les_xsstate_t *st)
{
    if (!st->activity_tracking)
        return;
    st->last_read_ns = les_activity_now_ns(aTHX);
    LES_STAT(st, activity_clock_calls)++;
}

void
les_note_write_activity(pTHX_ les_xsstate_t *st)
{
    if (!st->activity_tracking)
        return;
    st->last_write_ns = les_activity_now_ns(aTHX);
    LES_STAT(st, activity_clock_calls)++;
}

/* Keep the ordinary fd path direct and predictable. Provider indirection is
 * paid only after a future adjacent transport replaces the plain ops table. */
les_transport_result_t
les_transport_read(les_xsstate_t *st, void *buffer, size_t length)
{
    if (st->transport_ops == &les_plain_transport_ops)
        return les_plain_result(read(st->read_fd, buffer, length),
            LES_TRANSPORT_WANT_READ);
    return st->transport_ops->read_bytes(
        st->transport_context, buffer, length);
}

les_transport_result_t
les_transport_write(les_xsstate_t *st, const void *buffer, size_t length)
{
    if (st->transport_ops == &les_plain_transport_ops)
        return les_plain_result(write(st->write_fd, buffer, length),
            LES_TRANSPORT_WANT_WRITE);
    return st->transport_ops->write_bytes(
        st->transport_context, buffer, length);
}

les_transport_result_t
les_transport_writev(les_xsstate_t *st, const struct iovec *vectors, int count)
{
    if (st->transport_ops == &les_plain_transport_ops)
        return les_plain_result(writev(st->write_fd, vectors, count),
            LES_TRANSPORT_WANT_WRITE);
    return st->transport_ops->write_vectors(
        st->transport_context, vectors, count);
}

les_transport_result_t
les_transport_shutdown_write(les_xsstate_t *st)
{
    if (st->transport_ops == &les_plain_transport_ops)
        return les_plain_shutdown_write(&st->plain_transport);
    return st->transport_ops->shutdown_write(st->transport_context);
}

int
les_transport_ready(les_xsstate_t *st)
{
    return st->transport_ops == &les_plain_transport_ops
        || st->transport_ops->is_ready(st->transport_context);
}

int
les_drive_transport(pTHX_ les_xsstate_t *st, const char *operation)
{
    les_transport_result_t result;

    if (les_transport_ready(st))
        return 1;
    result = st->transport_ops->drive(st->transport_context);
    les_call_transport_event(aTHX_ st, result.status, operation);
    return result.status == LES_TRANSPORT_OK && les_transport_ready(st);
}
