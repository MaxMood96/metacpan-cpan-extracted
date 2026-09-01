/*
 * arch_compat.h - the POSIX calls the extractor needs, on the platforms
 * that have them and on Windows, which spells some of them differently
 * and does not have the rest.
 *
 * Every name here is arch_-prefixed on purpose. Strawberry perl is built
 * with PERL_IMPLICIT_SYS, under which XSUB.h rewrites the PLAIN names -
 * mkdir, chmod, open, close, read, write, lstat, utime, unlink, stat -
 * into macros that dereference my_perl. A shim defining the plain names
 * would collide with those macros in any translation unit that includes
 * XSUB.h, and would silently re-plumb calls that were meant to reach
 * perl's own layer. Prefixed names cannot do either.
 */

#ifndef ARCH_COMPAT_H
#define ARCH_COMPAT_H

#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef _WIN32
#  include <direct.h>
#  include <io.h>
#  include <sys/utime.h>
#else
#  include <unistd.h>
#  include <utime.h>
#endif

/* Windows opens text-mode by default, which would turn every LF in an
 * extracted file into CRLF. Everything this dist writes is bytes. */
#ifdef O_BINARY
#  define ARCH_O_BINARY O_BINARY
#else
#  define ARCH_O_BINARY 0
#endif

#ifndef ENOSYS
#  define ENOSYS EINVAL
#endif

/* mkdir(2). Windows takes no mode - the permission bits have no meaning
 * on NTFS - so the caller's mode is dropped there, exactly as it is for
 * an existing directory on POSIX. */
static int
arch_mkdir(const char *path, unsigned int mode)
{
#ifdef _WIN32
    (void)mode;
    return _mkdir(path);
#else
    return mkdir(path, (mode_t)mode);
#endif
}

/* lstat(2). Windows has no symlink for it to decline to follow, so stat
 * is the whole story there. */
static int
arch_lstat(const char *path, struct stat *st)
{
#ifdef _WIN32
    return stat(path, st);
#else
    return lstat(path, st);
#endif
}

static int
arch_is_symlink(const struct stat *st)
{
#ifdef S_ISLNK
    return S_ISLNK(st->st_mode) ? 1 : 0;
#else
    (void)st;
    return 0;
#endif
}

/* symlink(2). Refused on Windows rather than faked: creating one needs a
 * privilege an ordinary account does not have, and writing a copy of the
 * target instead would extract a different archive than the one asked
 * for. The caller warns and carries on to the next entry. */
static int
arch_symlink(const char *target, const char *path)
{
#ifdef _WIN32
    (void)target;
    (void)path;
    errno = ENOSYS;
    return -1;
#else
    return symlink(target, path);
#endif
}

/* fchmod(2). Windows has no descriptor-based mode at all, and the only
 * bit its by-path _chmod carries is read-only. Extraction must not fail
 * over permission bits the filesystem cannot hold, so this succeeds
 * without doing anything there. */
static int
arch_fchmod(int fd, unsigned int mode)
{
#ifdef _WIN32
    (void)fd;
    (void)mode;
    return 0;
#else
    return fchmod(fd, (mode_t)mode);
#endif
}

#endif /* ARCH_COMPAT_H */
