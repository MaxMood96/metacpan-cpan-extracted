#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/eventfd.h>

MODULE = Linux::Event::Kernel::Event    PACKAGE = Linux::Event::Kernel::Event

PROTOTYPES: DISABLE

UV
_interpreter_id()
    CODE:
#ifdef PERL_IMPLICIT_CONTEXT
        RETVAL = PTR2UV(aTHX);
#else
        RETVAL = 0;
#endif
    OUTPUT:
        RETVAL

int
_new_fd()
    CODE:
        RETVAL = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
        if (RETVAL < 0)
            croak("eventfd: %s", Strerror(errno));
    OUTPUT:
        RETVAL

int
_dup_fd(fd)
        int fd
    CODE:
        do {
            RETVAL = fcntl(fd, F_DUPFD_CLOEXEC, 0);
        } while (RETVAL < 0 && errno == EINTR);
        if (RETVAL < 0)
            croak("duplicate eventfd: %s", Strerror(errno));
    OUTPUT:
        RETVAL

void
_signal_fd(fd, increment = 1)
        int fd
        UV increment
    PREINIT:
        uint64_t value;
        ssize_t written;
    CODE:
        if (increment == 0 || increment == UINT64_MAX)
            croak("signal(): increment must be between 1 and 18446744073709551614");
        value = (uint64_t)increment;
        do {
            written = write(fd, &value, sizeof(value));
        } while (written < 0 && errno == EINTR);
        if (written != (ssize_t)sizeof(value))
            croak("signal(): eventfd write failed: %s", Strerror(errno));

UV
_drain_fd(fd)
        int fd
    PREINIT:
        uint64_t value;
        ssize_t got;
    CODE:
        do {
            got = read(fd, &value, sizeof(value));
        } while (got < 0 && errno == EINTR);
        if (got == (ssize_t)sizeof(value))
            RETVAL = (UV)value;
        else if (got < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
            RETVAL = 0;
        else if (got == 0)
            RETVAL = 0;
        else
            croak("eventfd read failed: %s", Strerror(errno));
    OUTPUT:
        RETVAL

void
_close_fd(fd)
        int fd
    CODE:
        if (close(fd) < 0 && errno != EBADF)
            croak("close eventfd: %s", Strerror(errno));
