/* po_storeio.h - the store's own file layer.
 *
 * Paths, the directory listing, the sidecar index and sealing. The Perl this
 * replaces was orchestration over C that already existed - po_wal.h could
 * replay and seal, po_sgraph.h could build the map, po_tattr.h could
 * summarise a trace - and every one of those calls crossed the XS boundary
 * once per record to do it.
 *
 * THE DIRECTORY LISTING IS WHERE THE PORTABILITY LIVES.
 *
 * `opendir` and `DIR` are POSIX and do not exist on MSVC. Declaring either
 * one in a header that a Windows build also compiles is how a distribution
 * spends three releases on the same mistake, because the failure is a link
 * error a long way from the cause. So the shim below is self-prefixed
 * throughout - po_dir, po_opendir - and never names the ambient types, and
 * the Windows half calls FindFirstFile rather than pretending to be POSIX.
 */
#ifndef PO_STOREIO_H
#define PO_STOREIO_H

#include "punk_observe/po_compat.h"
#include "punk_observe/po_nsarith.h"
#include "punk_observe/po_wal.h"

#include <stdio.h>
#include <sys/stat.h>

#ifdef _WIN32
#  include <windows.h>
#  include <direct.h>
#  include <process.h>
#  define po_getpid() _getpid()
#else
#  include <dirent.h>
#  include <unistd.h>
#  define po_getpid() getpid()
#endif

#define PO_PATHMAX 4096

/* ---- a directory, without naming POSIX ------------------------------------ */

typedef struct {
#ifdef _WIN32
    HANDLE h;
    WIN32_FIND_DATAA fd;
    int first;
#else
    DIR *d;
#endif
    int open;
} po_dir;

static int po_opendir(po_dir *o, const char *path) {
    memset(o, 0, sizeof(*o));
#ifdef _WIN32
    {
        char pat[PO_PATHMAX];
        size_t n = strlen(path);
        if (n + 3 >= sizeof(pat)) return 0;
        memcpy(pat, path, n);
        memcpy(pat + n, "\\*", 3);
        o->h = FindFirstFileA(pat, &o->fd);
        if (o->h == INVALID_HANDLE_VALUE) return 0;
        o->first = 1;
    }
#else
    o->d = opendir(path);
    if (!o->d) return 0;
#endif
    o->open = 1;
    return 1;
}

/* The next name, or NULL. Borrowed, and valid until the next call. */
static const char *po_readdir(po_dir *o) {
    if (!o->open) return NULL;
#ifdef _WIN32
    if (o->first) { o->first = 0; return o->fd.cFileName; }
    if (!FindNextFileA(o->h, &o->fd)) return NULL;
    return o->fd.cFileName;
#else
    {
        struct dirent *e = readdir(o->d);
        return e ? e->d_name : NULL;
    }
#endif
}

static void po_closedir(po_dir *o) {
    if (!o->open) return;
#ifdef _WIN32
    FindClose(o->h);
#else
    closedir(o->d);
#endif
    o->open = 0;
}

/* ---- paths ---------------------------------------------------------------- */

/* Joined with a forward slash on every platform, Windows included: it accepts
 * one, and a store written on one machine and read on another must produce
 * the same names. */
static size_t po_path_join(char *out, size_t cap, const char *a, const char *b) {
    size_t an = a ? strlen(a) : 0, bn = b ? strlen(b) : 0;
    if (an && (a[an - 1] == '/' || a[an - 1] == '\\')) an--;
    if (an + 1 + bn + 1 > cap) return 0;
    if (an) memcpy(out, a, an);
    out[an] = '/';
    if (bn) memcpy(out + an + 1, b, bn);
    out[an + 1 + bn] = '\0';
    return an + 1 + bn;
}

static int po_file_size(const char *path, po_u64 *out) {
    struct stat st;
    if (stat(path, &st) != 0) return 0;
    if (out) *out = (po_u64)st.st_size;
    return 1;
}

static int po_is_dir(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) return 0;
#ifdef S_ISDIR
    return S_ISDIR(st.st_mode) ? 1 : 0;
#else
    return (st.st_mode & S_IFDIR) ? 1 : 0;
#endif
}

/* Every component, like `mkdir -p`. A store root that does not exist yet is
 * the ordinary case on a first run, not an error. */
static int po_mkpath(const char *path) {
    char buf[PO_PATHMAX];
    size_t n = strlen(path), i;
    if (n >= sizeof(buf)) return 0;
    memcpy(buf, path, n + 1);
    for (i = 1; i <= n; i++) {
        if (buf[i] != '/' && buf[i] != '\\' && buf[i] != '\0') continue;
        {
            char c = buf[i];
            buf[i] = '\0';
            if (!po_is_dir(buf)) {
#ifdef _WIN32
                _mkdir(buf);
#else
                mkdir(buf, 0777);
#endif
            }
            buf[i] = c;
        }
    }
    return po_is_dir(path);
}

/* ---- the sidecar ----------------------------------------------------------
 *
 * One key per line, tab separated, and the graph as one edge per line. A
 * summary that needed a parser to read would be a summary nobody read while
 * debugging a store at three in the morning, which is the only time anybody
 * reads one. */
static size_t po_idx_esc(const char *s, size_t n, char *out, size_t cap) {
    size_t i, o = 0;
    for (i = 0; i < n; i++) {
        unsigned char c = (unsigned char)s[i];
        if (c == '\t' || c == '\n' || c == '\\') {
            static const char hex[] = "0123456789abcdef";
            if (o + 3 >= cap) break;
            out[o++] = '\\';
            out[o++] = hex[c >> 4];
            out[o++] = hex[c & 15];
        }
        else {
            if (o + 1 >= cap) break;
            out[o++] = (char)c;
        }
    }
    out[o] = '\0';
    return o;
}

static size_t po_idx_unesc(const char *s, size_t n, char *out, size_t cap) {
    size_t i = 0, o = 0;
    while (i < n && o + 1 < cap) {
        if (s[i] == '\\' && i + 2 < n) {
            int hi = -1, lo = -1;
            char a = s[i + 1], b = s[i + 2];
            if (a >= '0' && a <= '9') hi = a - '0';
            else if (a >= 'a' && a <= 'f') hi = a - 'a' + 10;
            if (b >= '0' && b <= '9') lo = b - '0';
            else if (b >= 'a' && b <= 'f') lo = b - 'a' + 10;
            if (hi >= 0 && lo >= 0) {
                out[o++] = (char)((hi << 4) | lo);
                i += 3;
                continue;
            }
        }
        out[o++] = s[i++];
    }
    out[o] = '\0';
    return o;
}

/* ---- sealing --------------------------------------------------------------
 *
 * A SEALED LOG IS THE UNIT OF THE READ SIDE. The live log is being appended
 * to by the worker that owns it, so a reader gets whatever complete frames
 * exist at the moment it looks - correct, but not stable, and not something
 * to build an index over.
 *
 * Sealing writes the trailer, renames the file out of the way, and the caller
 * computes the summary beside it. After that the file never changes again, so
 * its index can never be stale. */
static int po_seal_rename(const char *from, const char *to) {
    /* rename(2) within a directory is atomic, so a reader either sees the
     * live log or the sealed segment and never a file mid-rename. */
    return rename(from, to) == 0;
}

/* The write-then-rename the index uses, for the same reason: a reader must
 * never see half a sidecar. */
static int po_atomic_write(const char *path, const char *bytes, size_t n) {
    char tmp[PO_PATHMAX];
    FILE *f;
    size_t w;
    int len = snprintf(tmp, sizeof(tmp), "%s.tmp%ld", path, (long)po_getpid());
    if (len <= 0 || (size_t)len >= sizeof(tmp)) return 0;
    f = fopen(tmp, "wb");
    if (!f) return 0;
    w = n ? fwrite(bytes, 1, n, f) : 0;
    fclose(f);
    if (w != n) { remove(tmp); return 0; }
    remove(path);                 /* Windows rename refuses an existing target */
    if (rename(tmp, path) != 0) { remove(tmp); return 0; }
    return 1;
}

/* Read a whole file. Returns malloc'd bytes, or NULL. */
static char *po_slurp(const char *path, size_t *out_len) {
    FILE *f;
    po_u64 sz = 0;
    char *buf;
    size_t got;

    if (!po_file_size(path, &sz)) return NULL;
    f = fopen(path, "rb");
    if (!f) return NULL;
    buf = (char *)malloc((size_t)sz + 1);
    if (!buf) { fclose(f); return NULL; }
    got = sz ? fread(buf, 1, (size_t)sz, f) : 0;
    fclose(f);
    buf[got] = '\0';
    if (out_len) *out_len = got;
    return buf;
}

#endif /* PO_STOREIO_H */
