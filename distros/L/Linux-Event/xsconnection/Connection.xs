/*
 * Linux::Event::Stream internal connection deadline helper
 * =============================================
 *
 * Connection policy and candidate management remain in Perl because they run
 * once per connection. Linux-specific timerfd mechanics live here so Connect
 * can provide deadlines and deferred terminal delivery without blocking the
 * reactor or adding a general scheduler to XSLoop.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <errno.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include <sys/timerfd.h>

static void
lec_timer_value(double seconds, struct itimerspec *timer)
{
    time_t whole;
    long nanoseconds;

    memset(timer, 0, sizeof(*timer));
    if (seconds <= 0.0)
        return;
    whole = (time_t)seconds;
    nanoseconds = (long)((seconds - (double)whole) * 1000000000.0);
    if (nanoseconds < 0)
        nanoseconds = 0;
    if (nanoseconds > 999999999L)
        nanoseconds = 999999999L;
    if (whole == 0 && nanoseconds == 0)
        nanoseconds = 1;
    timer->it_value.tv_sec = whole;
    timer->it_value.tv_nsec = nanoseconds;
}

MODULE = Linux::Event::Stream::_Connection    PACKAGE = Linux::Event::Stream::_Connection
PROTOTYPES: DISABLE

int
_timerfd_new(CLASS)
    const char *CLASS
  CODE:
    (void)CLASS;
    RETVAL = timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC);
    if (RETVAL < 0)
        croak("timerfd_create for Stream connection failed: %s", strerror(errno));
  OUTPUT:
    RETVAL

void
_timerfd_arm(CLASS, fd, seconds)
    const char *CLASS
    int fd
    double seconds
  PREINIT:
    struct itimerspec timer;
  CODE:
    (void)CLASS;
    lec_timer_value(seconds, &timer);
    if (timerfd_settime(fd, 0, &timer, NULL) != 0)
        croak("timerfd_settime for Stream connection failed: %s", strerror(errno));

void
_timerfd_consume(CLASS, fd)
    const char *CLASS
    int fd
  PREINIT:
    uint64_t expirations;
    ssize_t count;
  CODE:
    (void)CLASS;
    do {
        count = read(fd, &expirations, sizeof(expirations));
    } while (count < 0 && errno == EINTR);
    if (count < 0 && errno != EAGAIN && errno != EWOULDBLOCK)
        croak("read Stream connection timerfd failed: %s", strerror(errno));

void
_timerfd_close(CLASS, fd)
    const char *CLASS
    int fd
  CODE:
    (void)CLASS;
    if (fd >= 0)
        close(fd);
