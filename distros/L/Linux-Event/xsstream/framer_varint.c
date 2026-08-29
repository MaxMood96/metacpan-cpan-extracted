#include "stream_internal.h"

/* Unsigned canonical LEB128 payload length, limited to a 64-bit wire value. */

void
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
        les_emit_message(aTHX_ st, message);
        if (st->descriptor != descriptor)
            return;
    }
}
