#include "stream_internal.h"

void
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
        if (st->descriptor->read_mode != LES_READ_DELIVER
            || !st->descriptor->read_batch_bytes)
            les_process_existing_input(aTHX_ st, 0);
        if (st->closed || st->read_paused || st->read_eof)
            break;

        want = st->descriptor->read_size;

        if (st->descriptor->read_mode == LES_READ_DELIVER) {
            if (st->descriptor->read_batch_bytes) {
                UV remaining;

                if ((UV)st->input_len >= st->descriptor->read_batch_bytes) {
                    les_flush_raw_batch(aTHX_ st);
                    continue;
                }
                remaining = st->descriptor->read_batch_bytes - (UV)st->input_len;
                if ((UV)want > remaining)
                    want = (size_t)remaining;
                les_input_reserve(st, want);
                target = st->input_buffer + st->input_start + st->input_len;
            } else {
                target = st->read_buffer;
            }
        } else {
            if (st->descriptor->max_buffer) {
                if (st->input_len >= st->descriptor->max_buffer) {
                    les_descriptor_t *descriptor = st->descriptor;
                    char msg[128];
                    snprintf(msg, sizeof(msg), "input buffer exceeds max_buffer=%llu",
                        (unsigned long long)st->descriptor->max_buffer);
                    les_call_framing_error(aTHX_ st, msg);
                    if (!st->closed && !st->read_paused
                        && st->descriptor != descriptor)
                        continue;
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
                if (st->descriptor->read_batch_bytes) {
                    st->input_len += (size_t)result.count;
                    if ((UV)st->input_len >= st->descriptor->read_batch_bytes)
                        les_flush_raw_batch(aTHX_ st);
                } else {
                    SV *bytes = sv_2mortal(newSVpvn(
                        st->read_buffer, (STRLEN)result.count));
                    les_call_deliver(aTHX_ st, bytes);
                }
            } else {
                st->input_len += (size_t)result.count;
                st->input_appends++;
                if ((unsigned long long)st->input_len > st->input_peak_bytes)
                    st->input_peak_bytes = (unsigned long long)st->input_len;
            }
            continue;
        }

        if (result.status == LES_TRANSPORT_EOF) {
            les_descriptor_t *descriptor = st->descriptor;
            if (descriptor->read_mode == LES_READ_DELIVER)
                les_flush_raw_batch(aTHX_ st);
            else
                les_flush_message_batch(aTHX_ st);
            if (st->closed || st->read_paused)
                break;
            if (st->descriptor != descriptor)
                continue;
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
            les_descriptor_t *descriptor = st->descriptor;
            st->read_eagain_count++;
            if (descriptor->read_mode == LES_READ_DELIVER)
                les_flush_raw_batch(aTHX_ st);
            else
                les_flush_message_batch(aTHX_ st);
            if (!st->closed && !st->read_paused
                && st->descriptor != descriptor)
                continue;
            break;
        }

        {
            int err = result.error;
            les_descriptor_t *descriptor = st->descriptor;
            st->read_error_count++;
            if (descriptor->read_mode == LES_READ_DELIVER)
                les_flush_raw_batch(aTHX_ st);
            else
                les_flush_message_batch(aTHX_ st);
            if (st->closed || st->read_paused)
                break;
            if (st->descriptor != descriptor)
                continue;
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
