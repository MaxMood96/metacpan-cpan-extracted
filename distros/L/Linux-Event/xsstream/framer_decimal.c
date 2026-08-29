#include "stream_internal.h"

/* ASCII decimal payload length followed by one configured separator byte. */

void
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
        les_emit_message(aTHX_ st, message);
        if (st->descriptor != descriptor)
            return;
    }
}
