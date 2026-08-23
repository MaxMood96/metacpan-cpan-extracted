#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <errno.h>
#include <netdb.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/eventfd.h>
#include <sys/socket.h>

typedef struct ler_request {
    uint64_t id;
    char *host;
    char *service;
    int socktype;
    struct ler_request *next;
} ler_request;

typedef struct ler_candidate {
    int family;
    int protocol;
    socklen_t length;
    unsigned char *address;
    struct ler_candidate *next;
} ler_candidate;

typedef struct ler_completion {
    uint64_t id;
    int resolver_error;
    int system_errno;
    char *message;
    ler_candidate *head;
    ler_candidate *tail;
    struct ler_completion *next;
} ler_completion;

typedef struct ler_resolver {
    pthread_mutex_t mutex;
    pthread_cond_t condition;
    pthread_t *workers;
    unsigned worker_count;
    int stopping;
    int event_fd;
    pid_t owner_pid;
    uint64_t next_id;
    ler_request *request_head;
    ler_request *request_tail;
    ler_completion *completion_head;
    ler_completion *completion_tail;
} ler_resolver;

static ler_resolver *
ler_from_sv(SV *object)
{
    SV *inner;
    if (!SvROK(object) || !sv_derived_from(object,
            "Linux::Event::Stream::_Resolver::_Native"))
        croak("invalid native resolver object");
    inner = SvRV(object);
    return INT2PTR(ler_resolver *, SvIV(inner));
}

static void
ler_free_request(ler_request *request)
{
    if (!request) return;
    free(request->host);
    free(request->service);
    free(request);
}

static void
ler_free_completion(ler_completion *completion)
{
    ler_candidate *candidate, *next;
    if (!completion) return;
    for (candidate = completion->head; candidate; candidate = next) {
        next = candidate->next;
        free(candidate->address);
        free(candidate);
    }
    free(completion->message);
    free(completion);
}

static void
ler_notify(int fd)
{
    uint64_t one = 1;
    ssize_t count;
    do {
        count = write(fd, &one, sizeof(one));
    } while (count < 0 && errno == EINTR);
    /* EAGAIN means the counter is already saturated: readiness is preserved. */
}

static void *
ler_worker(void *argument)
{
    ler_resolver *resolver = (ler_resolver *)argument;
    sigset_t blocked;

    sigfillset(&blocked);
    pthread_sigmask(SIG_BLOCK, &blocked, NULL);

    for (;;) {
        ler_request *request;
        ler_completion *completion;
        struct addrinfo hints, *addresses = NULL, *address;
        int error;

        pthread_mutex_lock(&resolver->mutex);
        while (!resolver->stopping && !resolver->request_head)
            pthread_cond_wait(&resolver->condition, &resolver->mutex);
        if (resolver->stopping) {
            pthread_mutex_unlock(&resolver->mutex);
            break;
        }
        request = resolver->request_head;
        resolver->request_head = request->next;
        if (!resolver->request_head)
            resolver->request_tail = NULL;
        pthread_mutex_unlock(&resolver->mutex);

        completion = (ler_completion *)calloc(1, sizeof(*completion));
        if (!completion) {
            struct timespec retry_delay = { 0, 1000000 };
            pthread_mutex_lock(&resolver->mutex);
            request->next = resolver->request_head;
            resolver->request_head = request;
            if (!resolver->request_tail)
                resolver->request_tail = request;
            pthread_mutex_unlock(&resolver->mutex);
            nanosleep(&retry_delay, NULL);
            continue;
        }
        completion->id = request->id;
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_UNSPEC;
        hints.ai_socktype = request->socktype;
        error = getaddrinfo(request->host, request->service, &hints, &addresses);
        completion->resolver_error = error;
        completion->system_errno = error == EAI_SYSTEM ? errno : 0;
        completion->message = strdup(error ? gai_strerror(error) : "");

        if (!error) {
            for (address = addresses; address; address = address->ai_next) {
                ler_candidate *candidate;
                if (!address->ai_addr || !address->ai_addrlen)
                    continue;
                candidate = (ler_candidate *)calloc(1, sizeof(*candidate));
                if (!candidate)
                    continue;
                candidate->address = (unsigned char *)malloc(address->ai_addrlen);
                if (!candidate->address) {
                    free(candidate);
                    continue;
                }
                memcpy(candidate->address, address->ai_addr, address->ai_addrlen);
                candidate->length = (socklen_t)address->ai_addrlen;
                candidate->family = address->ai_family;
                candidate->protocol = address->ai_protocol;
                if (completion->tail)
                    completion->tail->next = candidate;
                else
                    completion->head = candidate;
                completion->tail = candidate;
            }
            freeaddrinfo(addresses);
        }
        ler_free_request(request);

        pthread_mutex_lock(&resolver->mutex);
        if (resolver->completion_tail)
            resolver->completion_tail->next = completion;
        else
            resolver->completion_head = completion;
        resolver->completion_tail = completion;
        pthread_mutex_unlock(&resolver->mutex);
        ler_notify(resolver->event_fd);
    }
    return NULL;
}

MODULE = Linux::Event::Stream::_Resolver    PACKAGE = Linux::Event::Stream::_Resolver::_Native
PROTOTYPES: DISABLE

SV *
new(CLASS, worker_count = 2)
    const char *CLASS
    unsigned worker_count
  PREINIT:
    ler_resolver *resolver;
    unsigned started = 0;
    SV *inner;
  CODE:
    if (worker_count == 0 || worker_count > 32)
        croak("resolver worker count must be between 1 and 32");
    resolver = (ler_resolver *)calloc(1, sizeof(*resolver));
    if (!resolver)
        croak("cannot allocate native resolver");
    resolver->event_fd = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC);
    resolver->owner_pid = getpid();
    resolver->next_id = 1;
    resolver->worker_count = worker_count;
    resolver->workers = (pthread_t *)calloc(worker_count, sizeof(pthread_t));
    if (resolver->event_fd < 0 || !resolver->workers) {
        if (resolver->event_fd >= 0)
            close(resolver->event_fd);
        free(resolver->workers);
        free(resolver);
        croak("cannot initialize native resolver");
    }
    if (pthread_mutex_init(&resolver->mutex, NULL) != 0) {
        close(resolver->event_fd);
        free(resolver->workers);
        free(resolver);
        croak("cannot initialize native resolver mutex");
    }
    if (pthread_cond_init(&resolver->condition, NULL) != 0) {
        pthread_mutex_destroy(&resolver->mutex);
        close(resolver->event_fd);
        free(resolver->workers);
        free(resolver);
        croak("cannot initialize native resolver condition");
    }
    for (started = 0; started < worker_count; started++) {
        if (pthread_create(&resolver->workers[started], NULL,
                ler_worker, resolver) != 0)
            break;
    }
    if (started != worker_count) {
        pthread_mutex_lock(&resolver->mutex);
        resolver->stopping = 1;
        pthread_cond_broadcast(&resolver->condition);
        pthread_mutex_unlock(&resolver->mutex);
        while (started) pthread_join(resolver->workers[--started], NULL);
        pthread_cond_destroy(&resolver->condition);
        pthread_mutex_destroy(&resolver->mutex);
        close(resolver->event_fd);
        free(resolver->workers);
        free(resolver);
        croak("cannot start native resolver worker");
    }
    inner = newSViv(PTR2IV(resolver));
    RETVAL = newRV_noinc(inner);
    sv_bless(RETVAL, gv_stashpv(CLASS, GV_ADD));
  OUTPUT:
    RETVAL

int
event_fd(self)
    SV *self
  PREINIT:
    ler_resolver *resolver;
  CODE:
    resolver = ler_from_sv(self);
    RETVAL = resolver ? resolver->event_fd : -1;
  OUTPUT:
    RETVAL

UV
submit(self, host, service, socktype = SOCK_STREAM)
    SV *self
    SV *host
    SV *service
    int socktype
  PREINIT:
    ler_resolver *resolver;
    ler_request *request;
    STRLEN host_length, service_length;
    const char *host_bytes, *service_bytes;
    uint64_t id;
  CODE:
    resolver = ler_from_sv(self);
    if (!resolver || resolver->owner_pid != getpid())
        croak("native resolver cannot be used after fork");
    if (socktype != SOCK_STREAM && socktype != SOCK_DGRAM)
        croak("resolver socktype must be SOCK_STREAM or SOCK_DGRAM");
    host_bytes = SvPV(host, host_length);
    service_bytes = SvPV(service, service_length);
    if (memchr(host_bytes, '\0', host_length) || memchr(service_bytes, '\0', service_length))
        croak("resolver host and service cannot contain NUL bytes");
    request = (ler_request *)calloc(1, sizeof(*request));
    if (!request)
        croak("cannot allocate resolver request");
    request->host = strndup(host_bytes, host_length);
    request->service = strndup(service_bytes, service_length);
    request->socktype = socktype;
    if (!request->host || !request->service) {
        ler_free_request(request);
        croak("cannot copy resolver request");
    }
    pthread_mutex_lock(&resolver->mutex);
    request->id = resolver->next_id++;
    if (!request->id) request->id = resolver->next_id++;
    id = request->id;
    if (resolver->request_tail)
        resolver->request_tail->next = request;
    else
        resolver->request_head = request;
    resolver->request_tail = request;
    pthread_cond_signal(&resolver->condition);
    pthread_mutex_unlock(&resolver->mutex);
    RETVAL = id;
  OUTPUT:
    RETVAL

SV *
drain(self)
    SV *self
  PREINIT:
    ler_resolver *resolver;
    ler_completion *completion, *next_completion;
    uint64_t counter;
    ssize_t count;
    AV *results;
  CODE:
    resolver = ler_from_sv(self);
    if (!resolver || resolver->owner_pid != getpid())
        croak("native resolver cannot be drained after fork");
    do {
        count = read(resolver->event_fd, &counter, sizeof(counter));
    } while (count < 0 && errno == EINTR);
    pthread_mutex_lock(&resolver->mutex);
    completion = resolver->completion_head;
    resolver->completion_head = resolver->completion_tail = NULL;
    pthread_mutex_unlock(&resolver->mutex);
    results = newAV();
    while (completion) {
        HV *result = newHV();
        AV *candidates = newAV();
        ler_candidate *candidate;
        next_completion = completion->next;
        hv_stores(result, "id", newSVuv((UV)completion->id));
        hv_stores(result, "error_code", newSViv(completion->resolver_error));
        hv_stores(result, "system_errno", newSViv(completion->system_errno));
        hv_stores(result, "message", newSVpv(completion->message ? completion->message : "", 0));
        for (candidate = completion->head; candidate; candidate = candidate->next) {
            HV *item = newHV();
            hv_stores(item, "family", newSViv(candidate->family));
            hv_stores(item, "protocol", newSViv(candidate->protocol));
            hv_stores(item, "sockaddr", newSVpvn((char *)candidate->address,
                (STRLEN)candidate->length));
            av_push(candidates, newRV_noinc((SV *)item));
        }
        hv_stores(result, "candidates", newRV_noinc((SV *)candidates));
        av_push(results, newRV_noinc((SV *)result));
        ler_free_completion(completion);
        completion = next_completion;
    }
    RETVAL = newRV_noinc((SV *)results);
  OUTPUT:
    RETVAL

void
DESTROY(self)
    SV *self
  PREINIT:
    ler_resolver *resolver;
    ler_request *request, *next_request;
    ler_completion *completion, *next_completion;
    unsigned index;
  CODE:
    resolver = ler_from_sv(self);
    if (!resolver) XSRETURN_EMPTY;
    sv_setiv(SvRV(self), 0);
    if (resolver->owner_pid != getpid()) {
        for (request = resolver->request_head; request; request = next_request) {
            next_request = request->next;
            ler_free_request(request);
        }
        for (completion = resolver->completion_head; completion; completion = next_completion) {
            next_completion = completion->next;
            ler_free_completion(completion);
        }
        if (resolver->event_fd >= 0) close(resolver->event_fd);
        /* Mutexes and pthread IDs inherited across fork cannot be safely used. */
        free(resolver->workers);
        free(resolver);
        XSRETURN_EMPTY;
    }
    pthread_mutex_lock(&resolver->mutex);
    resolver->stopping = 1;
    pthread_cond_broadcast(&resolver->condition);
    pthread_mutex_unlock(&resolver->mutex);
    for (index = 0; index < resolver->worker_count; index++)
        pthread_join(resolver->workers[index], NULL);
    for (request = resolver->request_head; request; request = next_request) {
        next_request = request->next;
        ler_free_request(request);
    }
    for (completion = resolver->completion_head; completion; completion = next_completion) {
        next_completion = completion->next;
        ler_free_completion(completion);
    }
    close(resolver->event_fd);
    pthread_cond_destroy(&resolver->condition);
    pthread_mutex_destroy(&resolver->mutex);
    free(resolver->workers);
    free(resolver);
