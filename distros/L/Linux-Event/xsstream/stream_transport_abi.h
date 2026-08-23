#ifndef LINUX_EVENT_STREAM_TRANSPORT_ABI_H
#define LINUX_EVENT_STREAM_TRANSPORT_ABI_H

#include <stddef.h>
#include <sys/types.h>
#include <sys/uio.h>

#define LES_TRANSPORT_ABI_VERSION 1U

#define LES_TRANSPORT_OK         0
#define LES_TRANSPORT_EOF        1
#define LES_TRANSPORT_WANT_READ  2
#define LES_TRANSPORT_WANT_WRITE 3
#define LES_TRANSPORT_INTERRUPT  4
#define LES_TRANSPORT_ERROR      5

typedef struct les_transport_result_s {
    ssize_t count;
    int status;
    int error;
} les_transport_result_t;

typedef struct les_transport_ops_s {
    unsigned int abi_version;
    const char *name;
    les_transport_result_t (*read_bytes)(void *, void *, size_t);
    les_transport_result_t (*write_bytes)(void *, const void *, size_t);
    les_transport_result_t (*write_vectors)(void *, const struct iovec *, int);
    les_transport_result_t (*shutdown_write)(void *);
    les_transport_result_t (*drive)(void *);
    int (*is_ready)(void *);
    const char *(*error_string)(void *);
} les_transport_ops_t;

#endif
