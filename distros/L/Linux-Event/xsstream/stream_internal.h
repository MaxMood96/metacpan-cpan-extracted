#ifndef LINUX_EVENT_STREAM_INTERNAL_H
#define LINUX_EVENT_STREAM_INTERNAL_H

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/uio.h>

#include "stream_transport_abi.h"

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

typedef struct les_plain_transport_s {
    int fd;
} les_plain_transport_t;

typedef struct les_write_seg_s {
    SV *sv;
    STRLEN off;
    STRLEN len;
    struct les_write_seg_s *next;
} les_write_seg_t;

typedef struct les_descriptor_s {
    size_t read_size;
    UV read_batch_bytes;
    UV message_batch_size;
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
    SV *message_batch_cb;
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

    /* Native framed-input storage. Logical bytes begin at input_start and
     * continue for input_len bytes. */
    char *input_buffer;
    size_t input_start;
    size_t input_len;
    size_t input_cap;

    /* Per-connection delimiter scan state. */
    size_t delimiter_scan;

    /* A framed batch exists only while native input is being drained. The AV
     * owns its message SVs and is detached before entering Perl, so callback
     * exceptions cannot leave a live batch pointing at mortal storage. */
    AV *message_batch;
    UV message_batch_count;
    UV message_batch_bytes;

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
    unsigned long long read_batch_flushes;
    unsigned long long read_batch_peak_bytes;
    unsigned long long input_appends;
    unsigned long long input_compactions;
    unsigned long long input_peak_bytes;
    unsigned long long delimiter_searches;
    unsigned long long frames_emitted;
    unsigned long long message_callback_calls;
    unsigned long long message_batch_calls;
    unsigned long long message_batch_peak_messages;
    unsigned long long message_batch_peak_bytes;
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


extern const les_transport_ops_t les_plain_transport_ops;

les_xsstate_t *les_state_from_sv(SV *sv);
les_descriptor_t *les_descriptor_from_sv(SV *sv);
SV *les_store_cb(SV *cb, const char *name);
SV *les_store_optional_cb(SV *cb, const char *name);

unsigned long long les_activity_now_ns(pTHX);
void les_note_read_activity(pTHX_ les_xsstate_t *st);
void les_note_write_activity(pTHX_ les_xsstate_t *st);

les_transport_result_t les_transport_read(
    les_xsstate_t *st, void *buffer, size_t length);
les_transport_result_t les_transport_write(
    les_xsstate_t *st, const void *buffer, size_t length);
les_transport_result_t les_transport_writev(
    les_xsstate_t *st, const struct iovec *vectors, int count);
les_transport_result_t les_transport_shutdown_write(les_xsstate_t *st);
int les_transport_ready(les_xsstate_t *st);
int les_drive_transport(pTHX_ les_xsstate_t *st, const char *operation);

void les_call_transport_event(
    pTHX_ les_xsstate_t *st, int status, const char *operation);
void les_call_one(pTHX_ SV *cb, SV *arg);
void les_call_two(pTHX_ SV *cb, SV *a, SV *b);
void les_call_deliver(pTHX_ les_xsstate_t *st, SV *bytes);
void les_call_framing_error(
    pTHX_ les_xsstate_t *st, const char *message);
void les_call_eof(pTHX_ les_xsstate_t *st);
void les_call_read_error(pTHX_ les_xsstate_t *st, int err);
void les_call_write_error(pTHX_ les_xsstate_t *st, int err);
void les_call_output_limit(
    pTHX_ les_xsstate_t *st, UV pending_bytes);
void les_call_drain(pTHX_ les_xsstate_t *st);
void les_call_empty(pTHX_ les_xsstate_t *st);

void les_discard_message_batch(les_xsstate_t *st);
void les_flush_message_batch(pTHX_ les_xsstate_t *st);
void les_emit_message(pTHX_ les_xsstate_t *st, SV *message);
void les_flush_raw_batch(pTHX_ les_xsstate_t *st);

void les_clear_write_queue(les_xsstate_t *st);
void les_queue_bytes(
    les_xsstate_t *st, const char *data, STRLEN len);
void les_consume_written(les_xsstate_t *st, size_t count);
void les_maybe_drain_transition(pTHX_ les_xsstate_t *st);

const char *les_input_data(const les_xsstate_t *st);
int les_input_reserve(les_xsstate_t *st, size_t extra);
void les_input_consume(les_xsstate_t *st, size_t count);
int les_frame_fits_buffer(
    pTHX_ les_xsstate_t *st, UV prefix_bytes, UV payload_len);

void les_process_delimiter(pTHX_ les_xsstate_t *st);
void les_process_fixed(pTHX_ les_xsstate_t *st);
void les_process_length(pTHX_ les_xsstate_t *st);
void les_process_netstring(pTHX_ les_xsstate_t *st);
void les_process_varint(pTHX_ les_xsstate_t *st);
void les_process_decimal_length(pTHX_ les_xsstate_t *st);
void les_process_buffered(pTHX_ les_xsstate_t *st);
void les_process_existing_input(
    pTHX_ les_xsstate_t *st, int flush_batch);

void les_transition_descriptor(
    pTHX_ les_xsstate_t *st, SV *descriptor_obj, SV *input_sv);
void les_read_ready(pTHX_ les_xsstate_t *st);
int les_write_submit(pTHX_ les_xsstate_t *st, SV *bytes_sv);
void les_write_ready(pTHX_ les_xsstate_t *st);

#endif
