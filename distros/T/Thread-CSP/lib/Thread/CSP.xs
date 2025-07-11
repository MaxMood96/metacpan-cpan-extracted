#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define NEED_mg_findext
#include "ppport.h"

#include "channel.h"
#include "mthread.h"

typedef struct channel* Thread__CSP__Channel;
typedef struct promise* Thread__CSP__Promise;

MODULE = Thread::CSP              PACKAGE = Thread::CSP  PREFIX = thread_

BOOT:
	global_init(aTHX);

Thread::CSP::Promise thread_spawn(SV* class, AV* slurpy, ...)
	C_ARGS:
		slurpy

MODULE = Thread::CSP              PACKAGE = Thread::CSP::Promise  PREFIX = promise_

SV* promise_get(Thread::CSP::Promise promise)

bool promise_is_finished(Thread::CSP::Promise promise)

SV* promise_finished_fh(Thread::CSP::Promise promise)

MODULE = Thread::CSP              PACKAGE = Thread::CSP::Channel  PREFIX = channel_

Thread::CSP::Channel channel_new(SV* class)

void channel_send(Thread::CSP::Channel channel, SV* argument)

SV* channel_receive(Thread::CSP::Channel channel)

SV* channel_receive_ready_fh(Thread::CSP::Channel channel)

SV* channel_send_ready_fh(Thread::CSP::Channel channel)

void channel_close(Thread::CSP::Channel channel)
