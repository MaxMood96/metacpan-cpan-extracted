#include "stream_internal.h"

void
les_process_fixed(pTHX_ les_xsstate_t *st)
{
    les_descriptor_t *descriptor = st->descriptor;
    size_t size = (size_t)st->descriptor->fixed_size;

    while (!st->closed && !LES_INPUT_PAUSED(st) && st->input_len >= size) {
        const char *data = les_input_data(st);
        SV *message = sv_2mortal(newSVpvn(data, (STRLEN)size));
        les_input_consume(st, size);
        les_emit_message(aTHX_ st, message);
        if (st->descriptor != descriptor)
            return;
    }
}
