/* po_manifest.h - which segments are current, crash-safe by construction.
 *
 * A block directory holds segments from N workers plus whatever compaction
 * has produced. Something has to say which set is authoritative, and it has
 * to survive being interrupted.
 *
 * The answer is an APPEND-ONLY file of generations. Each generation is one
 * line: a number, a count, the segment names, and a terminator. The newest
 * COMPLETE generation wins; a torn last line is ignored because it has no
 * terminator. There is no lock, no rewrite, and no window in which the file
 * is neither the old state nor the new one.
 *
 * The bus notification in phase 4 is an accelerant on top of this, not a
 * substitute: losing a bus message costs a directory rescan, because THIS is
 * the truth.
 */
#ifndef PO_MANIFEST_H
#define PO_MANIFEST_H

#include "punk_observe/po_compat.h"

#include <stdio.h>
#include <errno.h>
#ifndef _WIN32
#  include <unistd.h>
#  include <fcntl.h>
#endif

#define PO_MAN_EOL '\n'
#define PO_MAN_END "#\n"          /* the terminator that makes a line whole */

/* Append a generation. Every name is written, then the terminator, then the
 * whole thing is flushed - so a crash mid-append leaves a line without a
 * terminator, which the reader skips. */
static int po_manifest_append(const char *path, po_u64 gen,
                              const char *const *names, size_t n) {
    int fd;
    char buf[256];
    size_t i;

#ifdef _WIN32
    fd = open(path, O_WRONLY | O_CREAT | O_APPEND | O_BINARY, 0644);
#else
    fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
#endif
    if (fd < 0) return 0;

    {
        int k = sprintf(buf, "g %llu %llu\n",
                        (unsigned long long)gen, (unsigned long long)n);
        if (write(fd, buf, (size_t)k) != k) { close(fd); return 0; }
    }
    for (i = 0; i < n; i++) {
        size_t l = strlen(names[i]);
        if (write(fd, names[i], l) != (ssize_t)l) { close(fd); return 0; }
        if (write(fd, "\n", 1) != 1) { close(fd); return 0; }
    }
    if (write(fd, PO_MAN_END, 2) != 2) { close(fd); return 0; }
#ifndef _WIN32
    if (fsync(fd) != 0) { close(fd); return 0; }
#endif
    close(fd);
    return 1;
}

/* The newest complete generation. Returns its number, or 0 if there is none.
 * `out` receives the offset and length of the names region within `buf`. */
static po_u64 po_manifest_latest(const char *buf, size_t len,
                                 size_t *names_off, size_t *names_len,
                                 size_t *count) {
    size_t i = 0;
    po_u64 best = 0;
    size_t best_off = 0, best_len = 0, best_n = 0;

    while (i < len) {
        size_t line_end = i;
        po_u64 gen = 0, n = 0;
        size_t body, j, seen = 0;
        int complete = 0;

        while (line_end < len && buf[line_end] != PO_MAN_EOL) line_end++;
        if (line_end >= len) break;                 /* torn header line */

        if (line_end - i < 3 || buf[i] != 'g') { i = line_end + 1; continue; }
        {
            const char *p = buf + i + 2;
            while (p < buf + line_end && *p >= '0' && *p <= '9')
                { gen = gen * 10 + (po_u64)(*p - '0'); p++; }
            while (p < buf + line_end && *p == ' ') p++;
            while (p < buf + line_end && *p >= '0' && *p <= '9')
                { n = n * 10 + (po_u64)(*p - '0'); p++; }
        }

        body = line_end + 1;
        j = body;
        while (j < len && seen < n) {
            size_t e = j;
            while (e < len && buf[e] != PO_MAN_EOL) e++;
            if (e >= len) break;
            j = e + 1;
            seen++;
        }
        /* Complete only if every promised name arrived AND the terminator
         * follows. Either missing means the writer was interrupted. */
        if (seen == n && j + 1 < len && buf[j] == '#' && buf[j + 1] == PO_MAN_EOL)
            complete = 1;

        if (complete && gen >= best) {
            best = gen; best_off = body; best_len = j - body; best_n = (size_t)n;
        }
        if (!complete) break;                       /* the torn tail */
        i = j + 2;
    }

    if (names_off) *names_off = best_off;
    if (names_len) *names_len = best_len;
    if (count)     *count     = best_n;
    return best;
}

#endif /* PO_MANIFEST_H */
