/* po_pb_read.h - a generic protobuf wire reader.
 *
 * The ecosystem has a writer and had no reader. otel_pb.h is 250 lines that
 * encode correctly and have no inverse; the only decoder anywhere was 92
 * lines of test-only Perl. Since http/protobuf is OTLP's DEFAULT transport,
 * without this header the server cannot accept what the SDK next door sends
 * out of the box.
 *
 * This mirrors otel_pb.h's shape deliberately, so the two read side by side.
 * It knows nothing about OTLP: schema lives in po_otlp_in.h.
 *
 * Everything borrows. po_pbr_bytes hands back a pointer INTO the caller's
 * buffer and copies nothing, so decoding a 4MB batch costs about one pass
 * over 4MB and the whole ingest path holds one allocation.
 */
#ifndef PO_PB_READ_H
#define PO_PB_READ_H

#include "punk_observe/po_compat.h"

/* Wire types. 0, 2 and 5 are what OTLP uses; 1 appears for fixed64. */
#define PO_PB_VARINT  0
#define PO_PB_FIXED64 1
#define PO_PB_BYTES   2
#define PO_PB_SGROUP  3         /* deprecated groups - see po_pbr_next */
#define PO_PB_EGROUP  4
#define PO_PB_FIXED32 5

typedef struct {
    const uint8_t *p;
    const uint8_t *end;
    int            err;         /* sticky: once set, every call fails */
} po_pbr;

#define PO_PB_OK      0
#define PO_PB_ETRUNC  1         /* ran off the end of the buffer      */
#define PO_PB_EVARINT 2         /* varint longer than ten bytes       */
#define PO_PB_EWIRE   3         /* a wire type OTLP never uses        */
#define PO_PB_EFIELD  4         /* field number 0, which is illegal   */

static void po_pbr_init(po_pbr *r, const void *buf, size_t len) {
    r->p   = (const uint8_t *)buf;
    r->end = r->p + len;
    r->err = PO_PB_OK;
}

static int po_pbr_done(const po_pbr *r) { return r->p >= r->end; }

/* A varint is at most ten bytes.
 *
 * The cap is not decoration. A corrupt or hostile stream can present an
 * unbounded run of continuation bits, and a loop with no bound here is a hang
 * on a malicious body - from an endpoint that is, by design, unauthenticated
 * on a self-hosted install. The tenth byte may also only carry one meaningful
 * bit; anything above bit 0 in it would overflow a uint64_t, so it is
 * REFUSED rather than allowed to wrap. */
static int po_pbr_varint(po_pbr *r, po_u64 *out) {
    po_u64 v = 0;
    int shift = 0, n = 0;

    if (r->err) return 0;
    while (r->p < r->end) {
        uint8_t b = *r->p++;
        n++;
        if (n == 10) {
            /* Only bit 0 can survive a 63-bit shift. */
            if (b > 1) { r->err = PO_PB_EVARINT; return 0; }
        }
        v |= (po_u64)(b & 0x7F) << shift;
        if (!(b & 0x80)) { *out = v; return 1; }
        if (n == 10) { r->err = PO_PB_EVARINT; return 0; }
        shift += 7;
    }
    r->err = PO_PB_ETRUNC;
    return 0;
}

/* A negative int32 is encoded SIGN-EXTENDED to ten bytes: -1 is
 * ff ff ff ff ff ff ff ff ff 01. OTLP uses int32 for SeverityNumber,
 * StatusCode and SpanKind, so a reader that assumes five bytes reads garbage,
 * and one that reads the varint unsigned reports 4294967295 for -1. */
static int po_pbr_int32(po_pbr *r, int32_t *out) {
    po_u64 v;
    if (!po_pbr_varint(r, &v)) return 0;
    *out = (int32_t)(uint32_t)(v & 0xFFFFFFFFu);
    return 1;
}

static int po_pbr_fixed64(po_pbr *r, po_u64 *out) {
    po_u64 v;
    if (r->err) return 0;
    if ((size_t)(r->end - r->p) < 8) { r->err = PO_PB_ETRUNC; return 0; }
    memcpy(&v, r->p, 8);        /* memcpy, not a cast: alignment */
    r->p += 8;
    *out = po_le64(v);          /* protobuf fixed64 is little-endian */
    return 1;
}

static int po_pbr_fixed32(po_pbr *r, uint32_t *out) {
    uint32_t v;
    if (r->err) return 0;
    if ((size_t)(r->end - r->p) < 4) { r->err = PO_PB_ETRUNC; return 0; }
    memcpy(&v, r->p, 4);
    r->p += 4;
    *out = po_le32(v);
    return 1;
}

static int po_pbr_double(po_pbr *r, double *out) {
    po_u64 bits;
    if (!po_pbr_fixed64(r, &bits)) return 0;
    memcpy(out, &bits, 8);      /* bit pattern, so NaN payloads survive */
    return 1;
}

static int po_pbr_float(po_pbr *r, float *out) {
    uint32_t bits;
    if (!po_pbr_fixed32(r, &bits)) return 0;
    memcpy(out, &bits, 4);
    return 1;
}

/* Borrows. The returned pointer is valid only while the caller's buffer is.
 *
 * A length-delimited field can claim a length past the end of the buffer, and
 * the answer is an ERROR, never a clamp: clamping turns a truncated body into
 * a shorter valid-looking one, which is a wrong answer rather than a refusal. */
static int po_pbr_bytes(po_pbr *r, const uint8_t **p, size_t *len) {
    po_u64 n;
    if (!po_pbr_varint(r, &n)) return 0;
    if (n > (po_u64)(r->end - r->p)) { r->err = PO_PB_ETRUNC; return 0; }
    *p   = r->p;
    *len = (size_t)n;
    r->p += (size_t)n;
    return 1;
}

/* A nested message, read in place with no allocation. */
static int po_pbr_sub(po_pbr *r, po_pbr *sub) {
    const uint8_t *p;
    size_t len;
    if (!po_pbr_bytes(r, &p, &len)) return 0;
    po_pbr_init(sub, p, len);
    return 1;
}

/* Advance past a field of the given wire type without interpreting it.
 *
 * Skipping unknown fields is the compatibility contract, not a convenience.
 * A reader that errors on a field it does not recognise breaks on the OTLP
 * release AFTER the one it was written for, and it breaks by rejecting data
 * rather than by ignoring an addition. */
static int po_pbr_skip(po_pbr *r, uint32_t wire) {
    po_u64 v;
    const uint8_t *p;
    size_t len;
    if (r->err) return 0;
    switch (wire) {
        case PO_PB_VARINT:  return po_pbr_varint(r, &v);
        case PO_PB_FIXED64: return po_pbr_fixed64(r, &v);
        case PO_PB_FIXED32: { uint32_t f; return po_pbr_fixed32(r, &f); }
        case PO_PB_BYTES:   return po_pbr_bytes(r, &p, &len);
        default:            r->err = PO_PB_EWIRE; return 0;
    }
}

/* The iterator. Returns 1 on a field, 0 at the end of the buffer or on error
 * (check r->err to tell them apart).
 *
 * Wire types 3 and 4 are the deprecated group encodings. OTLP does not use
 * them and they carry no length prefix, so a reader cannot skip one - it
 * would have to understand the schema to find the matching end tag. Their
 * presence means the bytes are not OTLP, so the message is refused rather
 * than half-read. */
static int po_pbr_next(po_pbr *r, uint32_t *field, uint32_t *wire) {
    po_u64 tag;
    if (r->err || r->p >= r->end) return 0;
    if (!po_pbr_varint(r, &tag)) return 0;
    *field = (uint32_t)(tag >> 3);
    *wire  = (uint32_t)(tag & 7);
    if (*field == 0)  { r->err = PO_PB_EFIELD; return 0; }
    if (*wire == PO_PB_SGROUP || *wire == PO_PB_EGROUP) {
        r->err = PO_PB_EWIRE;
        return 0;
    }
    return 1;
}

/* Packed repeated numerics.
 *
 * A repeated numeric field may arrive packed (one length-delimited blob) or
 * unpacked (one tag per value), and BOTH must be accepted always. otel_pb.h
 * writes packed; a conforming older encoder may not, and a reader that
 * handles only packed gets empty histogram buckets from valid input.
 *
 * The caller loops: begin, then repeated step calls.
 */
typedef struct { po_pbr inner; int packed; } po_pb_packed;

static int po_pb_packed_begin(po_pbr *r, uint32_t wire, po_pb_packed *it) {
    if (wire == PO_PB_BYTES) {          /* packed */
        it->packed = 1;
        return po_pbr_sub(r, &it->inner);
    }
    it->packed = 0;                     /* unpacked: this tag is one value */
    return 1;
}

static int po_pb_packed_varint(po_pbr *r, po_pb_packed *it, po_u64 *out) {
    if (it->packed) {
        if (po_pbr_done(&it->inner) || it->inner.err) return 0;
        return po_pbr_varint(&it->inner, out);
    }
    return po_pbr_varint(r, out);
}

static int po_pb_packed_double(po_pbr *r, po_pb_packed *it, double *out) {
    if (it->packed) {
        if (po_pbr_done(&it->inner) || it->inner.err) return 0;
        return po_pbr_double(&it->inner, out);
    }
    return po_pbr_double(r, out);
}

/* Propagate a sub-reader's error to its parent, so a fault deep in a nested
 * message is not lost when the sub goes out of scope. */
static void po_pbr_join(po_pbr *parent, const po_pbr *sub) {
    if (!parent->err && sub->err) parent->err = sub->err;
}

static const char *po_pbr_errstr(int err) {
    switch (err) {
        case PO_PB_OK:      return "ok";
        case PO_PB_ETRUNC:  return "truncated";
        case PO_PB_EVARINT: return "varint too long";
        case PO_PB_EWIRE:   return "unsupported wire type";
        case PO_PB_EFIELD:  return "field number 0";
        default:            return "unknown";
    }
}

#endif /* PO_PB_READ_H */
