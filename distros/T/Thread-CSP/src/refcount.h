#ifndef XS_REFCOUNT_H
#define XS_REFCOUNT_H


/* C11 atomics based implementation */

#if defined(__clang__)
#	if __has_feature(cxx_atomic)
#		define HAS_ATOMICS
#	endif
#elif __GNUC__ > 4
#	define HAS_ATOMICS
#endif

#ifdef HAS_ATOMICS

#include <stdatomic.h>

typedef atomic_size_t Refcount;

#define refcount_load(counter) atomic_load(counter)
#define refcount_init(counter, value) atomic_init(counter, value)
#define refcount_inc(counter) atomic_fetch_add_explicit(counter, 1, memory_order_relaxed)
static inline size_t refcount_dec(Refcount* refcount) {
	atomic_size_t result = atomic_fetch_sub_explicit(refcount, 1, memory_order_release);
	if (result == 1)
		atomic_thread_fence(memory_order_acquire);
	return result;
}
#	define refcount_destroy(count) ((void)0)

#elif defined(_MSC_VER)

/* Visual C++ doesn't support C11 atomics yet. However, Windows documentation
 * guarantees that simple reads and writes are atomic:
 * https://docs.microsoft.com/en-us/windows/win32/sync/interlocked-variable-access
 */
#include <windows.h>

#define HAS_ATOMICS
typedef volatile size_t Refcount;

#define refcount_load(counter) *(counter)
#define refcount_init(counter, value) do { *(counter) = (value); } while (0)
#define refcount_destroy(count) ((void)0)

#ifdef _WIN64
#	define refcount_inc(counter) InterlockedExchangeAdd64((LONG64*)(counter), 1)
#	define refcount_dec(counter) InterlockedExchangeAdd64((LONG64*)(counter), -1)
#else
#	define refcount_inc(counter) InterlockedExchangeAdd((LONG*)(counter), 1)
#	define refcount_dec(counter) InterlockedExchangeAdd((LONG*)(counter), -1)
#endif

#elif defined(USE_THREADS)
/* Mutex based fallback implementation for threaded perls */

typedef struct {
	perl_mutex mutex;
	UV counter;
} Refcount;

static inline UV S_refcount_load(pTHX_ Refcount* refcount) {
	MUTEX_LOCK(&refcount->mutex);
	UV result = refcount->counter;
	MUTEX_UNLOCK(&refcount->mutex);
	return result;
}
#define refcount_load(counter) S_refcount_load(aTHX_ counter)

static inline void S_refcount_init(pTHX_ Refcount* refcount, UV value) {
	MUTEX_INIT(&refcount->mutex);
	refcount->counter = value;
}
#define refcount_init(counter, value) S_refcount_init(aTHX_ counter, value)

static inline void S_refcount_inc(pTHX_ Refcount* refcount) {
	MUTEX_LOCK(&refcount->mutex);
	++refcount->counter;
	MUTEX_UNLOCK(&refcount->mutex);
}
#define refcount_inc(refcount) S_refcount_inc(aTHX_ refcount)

static inline UV S_refcount_dec(pTHX_ Refcount* refcount) {
	MUTEX_LOCK(&refcount->mutex);
	UV result = refcount->counter--;
	MUTEX_UNLOCK(&refcount->mutex);
	return result;
}
#define refcount_dec(refcount) S_refcount_dec(aTHX_ refcount)

static inline void S_refcount_destroy(pTHX_ Refcount* refcount) {
	MUTEX_DESTROY(&refcount->mutex);
}
#define refcount_destroy(refcount) S_refcount_destroy(aTHX_ refcount)

#else

/* Non-atomic fallback implementation for non-threaded perls */
typedef unsigned long Refcount;

#define refcount_load(counter) (*(counter))
#define refcount_init(counter, value) do { *(counter) = (value); } while (0)
#define refcount_inc(counter) ((*(counter))++)
#define refcount_dec(counter) ((*(counter))--)
#define refcount_destroy(count) ((void)0)

#endif

#endif
