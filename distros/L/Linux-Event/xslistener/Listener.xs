/* Linux::Event private listener accept drain. */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>

MODULE = Linux::Event::_Socket::Listener    PACKAGE = Linux::Event::_Socket::Listener
PROTOTYPES: DISABLE

SV *
_accept4_batch(CLASS, listener_fd, maximum)
    const char *CLASS
    int listener_fd
    int maximum
  PREINIT:
    AV *result;
    int error = 0;
    int accepted_count = 0;
  CODE:
    (void)CLASS;
    if (listener_fd < 0)
        croak("listener fd must be non-negative");
    if (maximum < 0)
        croak("maximum accepts must be non-negative");

    result = newAV();
    while (maximum == 0 || accepted_count < maximum) {
        struct sockaddr_storage peer;
        socklen_t peer_length = sizeof(peer);
        int fd = accept4(listener_fd, (struct sockaddr *)&peer, &peer_length,
            SOCK_NONBLOCK | SOCK_CLOEXEC);

        if (fd >= 0) {
            av_push(result, newSViv(fd));
            av_push(result, newSVpvn((const char *)&peer, (STRLEN)peer_length));
            accepted_count++;
            continue;
        }
        if (errno == EINTR || errno == ECONNABORTED)
            continue;
        if (errno != EAGAIN && errno != EWOULDBLOCK)
            error = errno;
        break;
    }

    av_unshift(result, 1);
    av_store(result, 0, newSViv(error));
    RETVAL = newRV_noinc((SV *)result);
  OUTPUT:
    RETVAL

void
_close_fd(CLASS, fd)
    const char *CLASS
    int fd
  CODE:
    (void)CLASS;
    if (fd >= 0)
        close(fd);
