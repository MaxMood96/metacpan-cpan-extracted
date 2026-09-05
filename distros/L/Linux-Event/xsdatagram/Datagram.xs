#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

MODULE = Linux::Event::_Socket::Dgram    PACKAGE = Linux::Event::_Socket::Dgram

PROTOTYPES: DISABLE

SV *
_recv_batch(fd, maximum_size, maximum_count)
    int fd
    UV maximum_size
    UV maximum_count
  PREINIT:
    unsigned char *buffer;
    AV *batch;
    UV received = 0;
    int saved_errno = 0;
  CODE:
    if (maximum_size == 0 || maximum_size > 16777216)
        croak("maximum datagram size must be between 1 and 16777216 bytes");
    buffer = (unsigned char *)malloc((size_t)maximum_size);
    if (!buffer)
        croak("cannot allocate datagram receive buffer");
    batch = newAV();
    av_push(batch, newSViv(0));
    while (maximum_count == 0 || received < maximum_count) {
        struct sockaddr_storage peer;
        struct iovec iov;
        struct msghdr message;
        ssize_t length;
        int truncated;

        memset(&peer, 0, sizeof(peer));
        memset(&message, 0, sizeof(message));
        iov.iov_base = buffer;
        iov.iov_len = (size_t)maximum_size;
        message.msg_name = &peer;
        message.msg_namelen = sizeof(peer);
        message.msg_iov = &iov;
        message.msg_iovlen = 1;
        do {
            length = recvmsg(fd, &message, MSG_DONTWAIT | MSG_TRUNC);
        } while (length < 0 && errno == EINTR);
        if (length < 0) {
            if (errno != EAGAIN && errno != EWOULDBLOCK)
                saved_errno = errno;
            break;
        }
        truncated = (message.msg_flags & MSG_TRUNC) != 0
            || (UV)length > maximum_size;
        if (truncated)
            av_push(batch, newSV(0));
        else
            av_push(batch, newSVpvn((const char *)buffer, (STRLEN)length));
        av_push(batch, newSVpvn((const char *)&peer,
            (STRLEN)message.msg_namelen));
        av_push(batch, newSVuv((UV)length));
        av_push(batch, newSViv(truncated));
        received++;
    }
    free(buffer);
    sv_setiv(*av_fetch(batch, 0, 0), saved_errno);
    RETVAL = newRV_noinc((SV *)batch);
  OUTPUT:
    RETVAL

void
_send_packet(fd, payload, address = &PL_sv_undef)
    int fd
    SV *payload
    SV *address
  PREINIT:
    STRLEN payload_length, address_length = 0;
    const char *payload_bytes, *address_bytes = NULL;
    ssize_t sent;
    int saved_errno = 0;
  PPCODE:
    payload_bytes = SvPVbyte(payload, payload_length);
    if (SvOK(address))
        address_bytes = SvPVbyte(address, address_length);
    do {
        if (address_bytes) {
            sent = sendto(fd, payload_bytes, payload_length,
                MSG_DONTWAIT | MSG_NOSIGNAL,
                (const struct sockaddr *)address_bytes,
                (socklen_t)address_length);
        } else {
            sent = send(fd, payload_bytes, payload_length,
                MSG_DONTWAIT | MSG_NOSIGNAL);
        }
    } while (sent < 0 && errno == EINTR);
    if (sent < 0)
        saved_errno = errno;
    EXTEND(SP, 2);
    PUSHs(sv_2mortal(newSViv((IV)sent)));
    PUSHs(sv_2mortal(newSViv(saved_errno)));
