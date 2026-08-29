#include "stream_internal.h"

/*
 * Swap only immutable protocol/type configuration. The connection fd,
 * watcher-owned XSState, queued output, application object, instrumentation,
 * pause/EOF state, and unread native input remain connection-local and live.
 * No callbacks are invoked here; Perl reblesses the Stream and updates its
 * descriptor hash before asking XS to dispatch buffered bytes.
 */

void
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
