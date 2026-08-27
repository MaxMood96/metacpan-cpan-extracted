/* po_wal.h - the per-worker write-ahead log.
 *
 * This is the ingest path's only write, and the whole reason the compactor
 * exists is so that it stays short:
 *
 *     decode the body      -> records + arena, one pass, no allocation
 *     apply the limits     -> a rejected count for partial_success
 *     po_wal_append        -> ONE writev of [header][records][arena]
 *     reply 200
 *
 * One syscall for the data. Hyperman is syscall-bound - 73% of the request
 * path is read plus writev - and this runs per ingested batch, so turning one
 * writev into three writes shows up directly as CPU per megabyte.
 *
 * A WAL file is owned by exactly one worker and is append-only. Nobody locks
 * it, because nobody else writes it. That is what phase 0 bought by choosing
 * per-worker files over a dedicated writer.
 */
#ifndef PO_WAL_H
#define PO_WAL_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_rec.h"
#include "punk_observe/po_time.h"
#include "punk_observe/po_crc32c.h"

#include <stdio.h>
#include <errno.h>
#ifndef _WIN32
#  include <unistd.h>
#  include <fcntl.h>
#  include <sys/uio.h>
#  include <sys/stat.h>
#else
#  include <io.h>
#  include <fcntl.h>
#endif

#define PO_WAL_MAGIC   0x4C574F4Fu     /* "OOWL" little-endian */

/* Version 2 carries the WHOLE record. Version 1 wrote a po_rec whose only
 * populated fields were t_unix_nano, kind and the body offsets: severity, the
 * trace and span ids, the duration, the value and the attribute block were
 * all zeroed on the way in. A log line written by a v1 writer cannot be
 * filtered on severity or joined to its trace, because those bytes were never
 * stored - so a v1 frame is REFUSED at replay rather than read into records
 * that are quietly empty. */
#define PO_WAL_VERSION 2

/* frame flags */
#define PO_WAL_F_SEALED 0x0001         /* the trailer: no more frames follow */

/* fsync policy */
#define PO_FSYNC_NEVER    0
#define PO_FSYNC_INTERVAL 1            /* the default */
#define PO_FSYNC_ALWAYS   2

/* Every field little-endian on disk. The READER byte-swaps, not the writer,
 * because the writer is the hot path and every box that matters is already
 * little-endian. */
typedef struct {
    uint32_t magic;
    uint32_t frame_len;    /* bytes following this header                  */
    uint32_t n_recs;
    uint32_t arena_len;
    po_u64   t_min;        /* the frame's timestamp span, so that a reader */
    po_u64   t_max;        /* can skip a frame without scanning it         */
    uint32_t crc;          /* CRC-32C over records + arena, padding incl.  */
    uint16_t flags;
    uint16_t version;
} po_wal_frame;

#define PO_WAL_HDR 40      /* asserted in t/0004-wal.t, not assumed */

typedef struct {
    int    fd;
    po_u64 last_fsync_ns;
    int    policy;
    po_u64 interval_ns;
    /* Counters, so the tests assert the policy by COUNTING rather than by
     * timing. A timing assertion on a loaded smoker is a flake. */
    po_u64 frames_written;
    po_u64 bytes_written;
    po_u64 fsyncs;
    int    sealed;
} po_wal;

static int po_wal_open(po_wal *w, const char *path, int policy,
                       po_u64 interval_ns) {
    int fd;
    memset(w, 0, sizeof(*w));
#ifdef _WIN32
    fd = open(path, O_WRONLY | O_CREAT | O_APPEND | O_BINARY, 0644);
#else
    fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
#endif
    if (fd < 0) return 0;
    w->fd            = fd;
    w->policy        = policy;
    w->interval_ns   = interval_ns ? interval_ns : 200 * PO_NS_PER_MSEC;
    w->last_fsync_ns = po_tick_ns();
    return 1;
}

static void po_wal_close(po_wal *w) {
    if (w->fd >= 0) { close(w->fd); w->fd = -1; }
}

/* Write all of a buffer, looping on a short write.
 *
 * A partial write is legal on a signal, and writev additionally caps at
 * IOV_MAX iovecs (1024 on Linux, 16 on some BSDs). Leaving a frame
 * half-written is fine ONLY because the length prefix and the CRC let a
 * reader detect it; it is never fine to stop and pretend it succeeded. */
static int po_write_all(int fd, const char *p, size_t n) {
    while (n) {
        ssize_t k = write(fd, p, n);
        if (k < 0) {
            if (errno == EINTR) continue;
            return 0;
        }
        if (k == 0) return 0;
        p += (size_t)k; n -= (size_t)k;
    }
    return 1;
}

static int po_wal_do_fsync(po_wal *w) {
#ifdef _WIN32
    if (_commit(w->fd) != 0) return 0;
#elif defined(F_FULLFSYNC)
    /* macOS: fsync(2) does NOT flush the drive's own write cache, so a power
     * cut can still lose it. F_FULLFSYNC is the one that means it. */
    if (fcntl(w->fd, F_FULLFSYNC, 0) < 0 && fsync(w->fd) != 0) return 0;
#else
    if (fdatasync(w->fd) != 0) return 0;
#endif
    w->fsyncs++;
    w->last_fsync_ns = po_tick_ns();
    return 1;
}

/* Append one frame. Returns 1, or 0 with errno set.
 *
 * An empty batch writes NOTHING. A frame with zero records would carry
 * t_min = 0 and t_max = UINT64_MAX or similar nonsense, and a reader that
 * prunes on those skips or opens exactly the wrong frames. A body that
 * decodes to no records is a 200 and no append. */
static int po_wal_append(po_wal *w, const po_rec *recs, size_t n,
                         const char *arena, size_t arena_len) {
    po_wal_frame h;
    char hdr[PO_WAL_HDR];
    po_u64 t_min = PO_U64_MAX, t_max = 0;
    size_t i, reclen;
    uint32_t crc = 0;
    static const char pad[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    size_t padlen;

    if (n == 0) return 1;
    if (w->sealed) { errno = EPERM; return 0; }

    for (i = 0; i < n; i++) {
        po_u64 t = recs[i].t_unix_nano;
        if (t < t_min) t_min = t;
        if (t > t_max) t_max = t;
    }

    reclen = n * sizeof(po_rec);
    /* Pad the arena to an 8-byte boundary so the next frame header is
     * aligned. The padding is ZEROED and is INSIDE the CRC, or a reader
     * recomputing the checksum over what it read disagrees with the writer. */
    padlen = (8 - (arena_len & 7)) & 7;

    crc = po_crc32c(0, recs, reclen);
    if (arena_len) crc = po_crc32c(crc, arena, arena_len);
    if (padlen)    crc = po_crc32c(crc, pad, padlen);

    h.magic     = PO_WAL_MAGIC;
    h.frame_len = (uint32_t)(reclen + arena_len + padlen);
    h.n_recs    = (uint32_t)n;
    h.arena_len = (uint32_t)arena_len;
    h.t_min     = t_min;
    h.t_max     = t_max;
    h.crc       = crc;
    h.flags     = 0;
    h.version   = PO_WAL_VERSION;

    {   /* Serialise the header field by field rather than writing the struct,
         * so the on-disk layout is this code's decision and not the
         * compiler's padding. */
        char *q = hdr;
        uint32_t u32; po_u64 u64; uint16_t u16;
#define PUT32(v) do { u32 = po_le32(v); memcpy(q, &u32, 4); q += 4; } while (0)
#define PUT64(v) do { u64 = po_le64(v); memcpy(q, &u64, 8); q += 8; } while (0)
#define PUT16(v) do { u16 = (uint16_t)(v); \
                      q[0] = (char)(u16 & 0xFF); q[1] = (char)((u16 >> 8) & 0xFF); \
                      q += 2; } while (0)
        PUT32(h.magic); PUT32(h.frame_len); PUT32(h.n_recs); PUT32(h.arena_len);
        PUT64(h.t_min); PUT64(h.t_max);
        PUT32(h.crc);   PUT16(h.flags); PUT16(h.version);
#undef PUT32
#undef PUT64
#undef PUT16
    }

#ifndef _WIN32
    {   /* One writev. Four iovecs at most, so IOV_MAX is never in question -
         * the records and the arena are each ONE contiguous buffer by
         * construction, which is what po_rec's offsets-not-pointers rule and
         * the arena bought. */
        struct iovec iov[4];
        int niov = 0;
        size_t total = PO_WAL_HDR + h.frame_len;
        ssize_t k;

        iov[niov].iov_base = hdr;              iov[niov].iov_len = PO_WAL_HDR; niov++;
        iov[niov].iov_base = (void *)recs;     iov[niov].iov_len = reclen;     niov++;
        if (arena_len) { iov[niov].iov_base = (void *)arena;
                         iov[niov].iov_len = arena_len; niov++; }
        if (padlen)    { iov[niov].iov_base = (void *)pad;
                         iov[niov].iov_len = padlen; niov++; }

        for (;;) {
            k = writev(w->fd, iov, niov);
            if (k < 0 && errno == EINTR) continue;
            if (k < 0) return 0;
            if ((size_t)k == total) break;
            /* Short write: finish the remainder with ordinary writes rather
             * than rebuilding the iovec array. Rare, and correctness beats
             * cleverness on a path that only runs when something odd
             * happened. */
            {
                size_t done = (size_t)k, off = 0;
                int j;
                for (j = 0; j < niov; j++) {
                    size_t len = iov[j].iov_len;
                    if (done >= off + len) { off += len; continue; }
                    {
                        size_t skip = done > off ? done - off : 0;
                        if (!po_write_all(w->fd,
                                (const char *)iov[j].iov_base + skip,
                                len - skip)) return 0;
                    }
                    off += len;
                }
                break;
            }
        }
        w->bytes_written += total;
    }
#else
    if (!po_write_all(w->fd, hdr, PO_WAL_HDR)) return 0;
    if (!po_write_all(w->fd, (const char *)recs, reclen)) return 0;
    if (arena_len && !po_write_all(w->fd, arena, arena_len)) return 0;
    if (padlen && !po_write_all(w->fd, pad, padlen)) return 0;
    w->bytes_written += PO_WAL_HDR + h.frame_len;
#endif

    w->frames_written++;

    /* Durability policy. What a 200 MEANS is decided here, and the POD says
     * so rather than implying the default is safe in general:
     *
     *  always   - flushed before the caller replies. Survives a power cut.
     *  interval - flushed on a timer (default 200ms). A process crash loses
     *             nothing, because the write already reached the page cache;
     *             a POWER CUT can lose up to the interval.
     *  never    - the OS decides.
     *
     * The default is `interval` because of what the data IS. Losing 200ms of
     * telemetry on a power cut is an acceptable trade in a way that losing
     * 200ms of a job queue is not, and Punk::Queue correctly chooses the
     * other way. */
    if (w->policy == PO_FSYNC_ALWAYS) {
        if (!po_wal_do_fsync(w)) return 0;
    }
    else if (w->policy == PO_FSYNC_INTERVAL) {
        po_u64 now = po_tick_ns();
        if (now - w->last_fsync_ns >= w->interval_ns)
            if (!po_wal_do_fsync(w)) return 0;
    }
    return 1;
}

/* Seal. The trailer is a zero-record frame with PO_WAL_F_SEALED and the
 * file's total record count in n_recs - the one frame allowed to have no
 * records, because it carries no timestamps to prune on.
 *
 * The compactor only consumes SEALED files, so it never races a writer. */
static int po_wal_seal(po_wal *w, po_u64 total_records) {
    char hdr[PO_WAL_HDR];
    char *q = hdr;
    uint32_t u32; po_u64 u64;

    if (w->sealed) return 1;
#define PUT32(v) do { u32 = po_le32(v); memcpy(q, &u32, 4); q += 4; } while (0)
#define PUT64(v) do { u64 = po_le64(v); memcpy(q, &u64, 8); q += 8; } while (0)
    PUT32(PO_WAL_MAGIC); PUT32(0);
    PUT32((uint32_t)total_records); PUT32(0);
    PUT64(0); PUT64(0);
    PUT32(0);
#undef PUT32
#undef PUT64
    q[0] = (char)(PO_WAL_F_SEALED & 0xFF);
    q[1] = (char)((PO_WAL_F_SEALED >> 8) & 0xFF);
    q[2] = (char)(PO_WAL_VERSION & 0xFF);
    q[3] = (char)((PO_WAL_VERSION >> 8) & 0xFF);

    if (!po_write_all(w->fd, hdr, PO_WAL_HDR)) return 0;
    if (!po_wal_do_fsync(w)) return 0;      /* a seal is always durable */
    w->sealed = 1;
    return 1;
}

/* ---- replay -------------------------------------------------------------- */

typedef struct {
    po_u64 frames;
    po_u64 records;
    po_u64 bytes_ok;        /* bytes of complete, verified frames        */
    po_u64 bytes_truncated; /* what was left over and could not be read  */
    int    sealed;
    int    stopped_reason;  /* PO_REPLAY_*                               */
} po_wal_replay;

#define PO_REPLAY_EOF     0    /* clean end of file                      */
#define PO_REPLAY_SHORT   1    /* a partial frame at the tail            */
#define PO_REPLAY_CRC     2    /* a frame that did not verify            */
#define PO_REPLAY_MAGIC   3    /* not a frame header at all              */
#define PO_REPLAY_SEALED  4    /* hit the seal trailer                   */
#define PO_REPLAY_VERSION 5    /* a frame this build cannot read         */

typedef void (*po_replay_cb)(void *ud, const po_rec *recs, size_t n,
                             const char *arena, size_t arena_len);

/* Replay a WAL from a buffer (the caller mmaps or slurps it).
 *
 * THE RULE: this reads frames until one fails its magic, its bounds or its
 * CRC, then STOPS and reports how far it got. That is a success, not an
 * error.
 *
 * A WAL being appended to is SUPPOSED to have a ragged end, and a crash
 * guarantees one. A recovery path that errors on a truncated tail turns "the
 * last 40ms did not make it" into "the server will not start" - the data was
 * already lost, and now the service is too. That is the wrong-way failure,
 * and it is why bytes_truncated is reported and logged rather than raised. */
static void po_wal_replay_buf(const char *buf, size_t len,
                              po_wal_replay *out,
                              po_replay_cb cb, void *ud) {
    size_t off = 0;
    memset(out, 0, sizeof(*out));

    for (;;) {
        uint32_t magic, frame_len, n_recs, arena_len, crc, want;
        uint16_t flags, version;
        po_u64 t_min, t_max;
        const char *h;
        size_t reclen, padlen;

        if (len - off < PO_WAL_HDR) {
            out->stopped_reason = (len - off == 0) ? PO_REPLAY_EOF : PO_REPLAY_SHORT;
            out->bytes_truncated = (po_u64)(len - off);
            return;
        }
        h = buf + off;
        memcpy(&magic, h, 4);          magic     = po_le32(magic);
        if (magic != PO_WAL_MAGIC) {
            out->stopped_reason  = PO_REPLAY_MAGIC;
            out->bytes_truncated = (po_u64)(len - off);
            return;
        }
        memcpy(&frame_len, h + 4, 4);  frame_len = po_le32(frame_len);
        memcpy(&n_recs,    h + 8, 4);  n_recs    = po_le32(n_recs);
        memcpy(&arena_len, h + 12, 4); arena_len = po_le32(arena_len);
        memcpy(&t_min,     h + 16, 8); t_min     = po_le64(t_min);
        memcpy(&t_max,     h + 24, 8); t_max     = po_le64(t_max);
        memcpy(&crc,       h + 32, 4); crc       = po_le32(crc);
        flags   = (uint16_t)((unsigned char)h[36] | ((unsigned char)h[37] << 8));
        version = (uint16_t)((unsigned char)h[38] | ((unsigned char)h[39] << 8));
        (void)t_min; (void)t_max;

        /* Checked BEFORE the frame is read, and before the seal trailer is
         * honoured. A version this build does not know is not a ragged tail:
         * the bytes are intact and mean something else, so reading them as
         * po_rec would hand back records whose fields are whatever the older
         * writer happened to leave there. Stopping is the honest answer. */
        if (version != PO_WAL_VERSION) {
            out->stopped_reason  = PO_REPLAY_VERSION;
            out->bytes_truncated = (po_u64)(len - off);
            return;
        }

        if (flags & PO_WAL_F_SEALED) {
            out->sealed = 1;
            out->stopped_reason = PO_REPLAY_SEALED;
            out->bytes_ok += PO_WAL_HDR;
            return;
        }

        if (len - off - PO_WAL_HDR < (size_t)frame_len) {
            out->stopped_reason  = PO_REPLAY_SHORT;
            out->bytes_truncated = (po_u64)(len - off);
            return;
        }

        reclen = (size_t)n_recs * sizeof(po_rec);
        padlen = (8 - (arena_len & 7)) & 7;
        /* The header's own arithmetic must agree with itself before a single
         * byte of it is trusted. A frame_len that does not equal
         * records + arena + padding is a corrupt header, not a long frame. */
        if (reclen + arena_len + padlen != (size_t)frame_len) {
            out->stopped_reason  = PO_REPLAY_CRC;
            out->bytes_truncated = (po_u64)(len - off);
            return;
        }

        want = po_crc32c(0, h + PO_WAL_HDR, (size_t)frame_len);
        if (want != crc) {
            /* Stop HERE. Not "skip this frame and try the next": a bad CRC
             * means the bytes are not what was written, so the length that
             * would find the next frame is not trustworthy either. */
            out->stopped_reason  = PO_REPLAY_CRC;
            out->bytes_truncated = (po_u64)(len - off);
            return;
        }

        if (cb) cb(ud, (const po_rec *)(h + PO_WAL_HDR), (size_t)n_recs,
                   h + PO_WAL_HDR + reclen, (size_t)arena_len);

        out->frames++;
        out->records  += n_recs;
        out->bytes_ok += PO_WAL_HDR + frame_len;
        off += PO_WAL_HDR + frame_len;
    }
}

static const char *po_replay_reason(int r) {
    switch (r) {
        case PO_REPLAY_EOF:    return "eof";
        case PO_REPLAY_SHORT:  return "short";
        case PO_REPLAY_CRC:    return "crc";
        case PO_REPLAY_MAGIC:  return "magic";
        case PO_REPLAY_SEALED: return "sealed";
        case PO_REPLAY_VERSION: return "version";
        default:               return "unknown";
    }
}

#endif /* PO_WAL_H */
