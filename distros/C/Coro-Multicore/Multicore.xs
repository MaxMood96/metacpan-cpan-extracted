/* most win32 perls are beyond fixing, requiring dTHX */
/* even for ISO-C functions such as malloc. avoid! avoid! avoid! */
/* and fail to define numerous symbols, but still overrwide them */
/* with non-working versions (e.g. setjmp). */
#ifdef _WIN32
/*# define PERL_CORE 1 fixes some, breaks others */
#else
# define PERL_NO_GET_CONTEXT
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define X_STACKSIZE 1024 * sizeof (void *)

#include "CoroAPI.h"
#include "perlmulticore.h"
#include "schmorp.h"
#include "xthread.h"

#ifdef _WIN32
  #ifndef sigset_t
    #define sigset_t int
  #endif
#endif

#ifndef SvREFCNT_dec_NN
  #define SvREFCNT_dec_NN(sv) SvREFCNT_dec (sv)
#endif

#ifndef SvREFCNT_dec_simple_void_NN
  #define SvREFCNT_dec_simple_void_NN(sv) SvREFCNT_dec (sv)
#endif

#ifndef SvREFCNT_inc_NN
  #define SvREFCNT_inc_NN(sv) SvREFCNT_inc (sv)
#endif

#ifndef RECURSION_CHECK
  #define RECURSION_CHECK 0
#endif

static X_TLS_DECLARE(current_key);
#if RECURSION_CHECK
static X_TLS_DECLARE(check_key);
#endif

static void
fatal (const char *msg)
{
  write (2, msg, strlen (msg));
  abort ();
}

static s_epipe ep;
static void *perl_thx;
static sigset_t cursigset, fullsigset;

static int global_enable = 0;
static int thread_enable; /* 0 undefined, 1 disabled, 2 enabled */

/* assigned to a thread for each release/acquire */
struct tctx
{
  void *coro;
  int wait_f;
  xcond_t acquire_c;
  int jeret;
};

static struct tctx *tctx_free;

static struct tctx *
tctx_get (void)
{
  struct tctx *ctx;

  if (!tctx_free)
    {
      ctx = malloc (sizeof (*tctx_free));
      X_COND_CREATE (ctx->acquire_c);
    }
  else
    {
      ctx = tctx_free;
      tctx_free = tctx_free->coro;
    }

  return ctx;
}

static void
tctx_put (struct tctx *ctx)
{
  ctx->coro = tctx_free;
  tctx_free = ctx;
}

/* a stack of tctxs */
struct tctxs
{
  struct tctx **ctxs;
  int cur, max;
};

static struct tctx *
tctxs_get (struct tctxs *ctxs)
{
  return ctxs->ctxs[--ctxs->cur];
}

static void
tctxs_put (struct tctxs *ctxs, struct tctx *ctx)
{
  if (ctxs->cur >= ctxs->max)
    {
      ctxs->max = ctxs->max ? ctxs->max * 2 : 16;
      ctxs->ctxs = realloc (ctxs->ctxs, ctxs->max * sizeof (ctxs->ctxs[0]));
    }

  ctxs->ctxs[ctxs->cur++] = ctx;
}

static xmutex_t release_m = X_MUTEX_INIT;
static xcond_t release_c = X_COND_INIT;
static struct tctxs releasers;
static int idle;
static int min_idle = 1;
static int curthreads, max_threads = 1; /* protected by release_m */

static xmutex_t acquire_m = X_MUTEX_INIT;
static struct tctxs acquirers;

X_THREAD_PROC(thread_proc)
{
  PERL_SET_CONTEXT (perl_thx);

  {
    dTHXa (perl_thx);
    dJMPENV;
    struct tctx *ctx;
    int catchret;

    X_LOCK (release_m);

    for (;;)
      {
        while (!releasers.cur)
          if (idle <= min_idle || 1)
            X_COND_WAIT (release_c, release_m);
          else
            {
              struct timespec ts = { time (0) + idle - min_idle, 0 };

              if (X_COND_TIMEDWAIT (release_c, release_m, ts) == ETIMEDOUT)
                if (idle > min_idle && !releasers.cur)
                  break;
            }

        ctx = tctxs_get (&releasers);
        --idle;
        X_UNLOCK (release_m);

        if (!ctx) /* timed out? */
          break;

        pthread_sigmask (SIG_SETMASK, &cursigset, 0);
        JMPENV_PUSH (ctx->jeret);

        if (!ctx->jeret)
          while (ctx->coro)
            CORO_SCHEDULE;

        JMPENV_POP;
        pthread_sigmask (SIG_SETMASK, &fullsigset, &cursigset);

        X_LOCK (acquire_m);
        ctx->wait_f = 1;
        X_COND_SIGNAL (ctx->acquire_c);
        X_UNLOCK (acquire_m);

        X_LOCK (release_m);
        ++idle;
      }
  }
}

static void
start_thread (void)
{
  xthread_t tid;

  if (!curthreads)
    {
      X_UNLOCK (release_m);
      {
        dTHX;
        dSP;

        PUSHSTACKi (PERLSI_REQUIRE);

        eval_pv ("Coro::Multicore::init", 1);

        POPSTACK;
      }
      X_LOCK (release_m);
    }

  if (curthreads >= max_threads && 0)
    return;

  ++curthreads;
  ++idle;
  xthread_create (&tid, thread_proc, 0);
}

static void
pmapi_release (void)
{
  if (! ((thread_enable ? thread_enable : global_enable) & 1))
    {
      X_TLS_SET (current_key, 0);
      return;
    }

  #if RECURSION_CHECK
  if (X_TLS_GET (check_key))
    fatal ("FATAL: perlinterp_release () called without valid perl context");

  X_TLS_SET (check_key, &check_key);
  #endif

  struct tctx *ctx = tctx_get ();
  ctx->coro = SvREFCNT_inc_simple_NN (CORO_CURRENT);
  ctx->wait_f = 0;

  X_TLS_SET (current_key, ctx);
  pthread_sigmask (SIG_SETMASK, &fullsigset, &cursigset);

  X_LOCK (release_m);

  if (idle <= min_idle)
    start_thread ();

  tctxs_put (&releasers, ctx);
  X_COND_SIGNAL (release_c);

  while (!idle && releasers.cur)
    {
      X_UNLOCK (release_m);
      X_LOCK (release_m);
    }

  X_UNLOCK (release_m);
}

static void
pmapi_acquire (void)
{
  int jeret;
  struct tctx *ctx = X_TLS_GET (current_key);

  if (!ctx)
    return;

  #if RECURSION_CHECK
  if (X_TLS_GET (check_key) != &check_key)
    fatal ("FATAL: perlinterp_acquire () called with valid perl context");

  X_TLS_SET (check_key, 0);
  #endif

  X_LOCK (acquire_m);

  tctxs_put (&acquirers, ctx);

  s_epipe_signal (&ep);
  while (!ctx->wait_f)
    X_COND_WAIT (ctx->acquire_c, acquire_m);
  X_UNLOCK (acquire_m);

  jeret = ctx->jeret;
  tctx_put (ctx);
  pthread_sigmask (SIG_SETMASK, &cursigset, 0);

  if (jeret)
    {
      dTHX;
      JMPENV_JUMP (jeret);
    }
}

static void
set_thread_enable (pTHX_ void *arg)
{
  thread_enable = PTR2IV (arg);
}

static void
atfork_child (void)
{
  s_epipe_renew (&ep);
}

MODULE = Coro::Multicore		PACKAGE = Coro::Multicore

PROTOTYPES: DISABLE

BOOT:
{
#ifndef _WIN32
	sigfillset (&fullsigset);
#endif

        X_TLS_INIT (current_key);
#if RECURSION_CHECK
        X_TLS_INIT (check_key);
#endif

        if (s_epipe_new (&ep))
          croak ("Coro::Multicore: unable to initialise event pipe.\n");

        pthread_atfork (0, 0, atfork_child);

        perl_thx = PERL_GET_CONTEXT;

	I_CORO_API ("Coro::Multicore");

        if (0) { /*D*/
        X_LOCK (release_m);
        while (idle < min_idle)
          start_thread ();
        X_UNLOCK (release_m);
        }

        /* not perfectly efficient to do it this way, but it is simple */
	perl_multicore_init (); /* calls release */
        perl_multicore_api->pmapi_release = pmapi_release;
        perl_multicore_api->pmapi_acquire = pmapi_acquire;
}

bool
enable (bool enable = NO_INIT)
	CODE:
        RETVAL = global_enable;
        if (items)
          global_enable = enable;
        OUTPUT:
        RETVAL

void
scoped_enable ()
	CODE:
        LEAVE; /* see Guard.xs */
        CORO_ENTERLEAVE_SCOPE_HOOK (set_thread_enable, (void *)1, set_thread_enable, (void *)0);
        ENTER; /* see Guard.xs */

void
scoped_disable ()
	CODE:
        LEAVE; /* see Guard.xs */
        CORO_ENTERLEAVE_SCOPE_HOOK (set_thread_enable, (void *)2, set_thread_enable, (void *)0);
        ENTER; /* see Guard.xs */

#if 0

U32
min_idle_threads (U32 min = NO_INIT)
	CODE:
        X_LOCK (acquire_m);
        RETVAL = min_idle;
        if (items)
	  min_idle = min;
        X_UNLOCK (acquire_m);
        OUTPUT:
        RETVAL

#endif

int
fd ()
	CODE:
        RETVAL = s_epipe_fd (&ep);
	OUTPUT:
        RETVAL

void
poll (...)
	CODE:
        s_epipe_drain (&ep);
	X_LOCK (acquire_m);
        while (acquirers.cur)
          {
            struct tctx *ctx = tctxs_get (&acquirers);
            CORO_READY ((SV *)ctx->coro);
            SvREFCNT_dec_simple_void_NN ((SV *)ctx->coro);
            ctx->coro = 0;
          }
	X_UNLOCK (acquire_m);

void
sleep (NV seconds)
	CODE:
        perlinterp_release ();
	{
          int nsec = seconds;
          if (nsec) sleep (nsec);
          nsec = (seconds - nsec) * 1e9;
          if (nsec) usleep (nsec);
        }
        perlinterp_acquire ();

