#include "stream_internal.h"

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

void
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
            les_emit_message(aTHX_ st, message);
            if (st->descriptor != descriptor)
                return;
        }
    }
}
