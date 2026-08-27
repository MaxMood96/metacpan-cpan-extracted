/* po_time.h - clocks, and the seam that keeps later phases testable.
 *
 * Two clocks, and they are not interchangeable.
 *
 * The WALL clock produces a record's timestamp. It is what OTLP carries and
 * what a chart's x axis means. It also steps: NTP corrects it, an operator
 * sets it, a VM resumes with a stale one. So it is read for a timestamp and
 * never for an interval.
 *
 * The MONOTONIC clock produces every interval this distribution measures -
 * segment rotation, the head-flush timer, the fsync coalescer, a query's
 * deadline. It cannot step. Using the wall clock for one of these is how a
 * block ends up with min_ts > max_ts, which is a block no query will find.
 *
 * And one seam: po_now_ns is a FUNCTION POINTER. Every timer in this dist
 * reads the clock through it, so a test moves time instead of sleeping.
 * A fixed sleep before asserting that a timer fired FAILS on a smoker running
 * forty parallel builds, which is how this ecosystem has lost releases before.
 * The seam is here, in phase 0, so that no later phase has to invent one.
 */
#ifndef PO_TIME_H
#define PO_TIME_H

#include "punk_observe/po_compat.h"

#include <time.h>
#ifndef _WIN32
#  include <sys/time.h>
#endif
#ifdef _WIN32
#  include <windows.h>
#endif

#define PO_NS_PER_SEC  ((po_u64)1000000000)
#define PO_NS_PER_MSEC ((po_u64)1000000)

/* Wall clock, unix nanoseconds. */
static po_u64 po_wall_ns_real(void) {
#if defined(PO_HAVE_CLOCK_GETTIME)
    struct timespec ts;
    if (clock_gettime(CLOCK_REALTIME, &ts) == 0)
        return (po_u64)ts.tv_sec * PO_NS_PER_SEC + (po_u64)ts.tv_nsec;
    return 0;
#elif defined(_WIN32)
    /* FILETIME is 100ns ticks since 1601-01-01; 11644473600 seconds to epoch. */
    FILETIME ft; ULARGE_INTEGER u;
    GetSystemTimeAsFileTime(&ft);
    u.LowPart = ft.dwLowDateTime; u.HighPart = ft.dwHighDateTime;
    return ((po_u64)u.QuadPart - (po_u64)116444736000000000ULL) * 100;
#else
    struct timeval tv;
    if (gettimeofday(&tv, NULL) == 0)
        return (po_u64)tv.tv_sec * PO_NS_PER_SEC + (po_u64)tv.tv_usec * 1000;
    return 0;
#endif
}

/* Monotonic nanoseconds. The zero point is arbitrary and means nothing; only
 * differences are defined. Where the platform has no monotonic clock this
 * falls back to the wall clock, which is wrong in exactly the way described
 * above - so po_have_monotonic() lets a caller say so rather than pretend. */
static po_u64 po_mono_ns(void) {
#if defined(PO_HAVE_CLOCK_MONOTONIC)
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) == 0)
        return (po_u64)ts.tv_sec * PO_NS_PER_SEC + (po_u64)ts.tv_nsec;
    return 0;
#elif defined(_WIN32)
    LARGE_INTEGER f, c;
    if (QueryPerformanceFrequency(&f) && QueryPerformanceCounter(&c) && f.QuadPart)
        return (po_u64)((double)c.QuadPart / (double)f.QuadPart * 1e9);
    return po_wall_ns_real();
#else
    return po_wall_ns_real();
#endif
}

static int po_have_monotonic(void) {
#if defined(PO_HAVE_CLOCK_MONOTONIC) || defined(_WIN32)
    return 1;
#else
    return 0;
#endif
}

/* The seam. Tests replace these; production never touches them. */
typedef po_u64 (*po_clock_fn)(void);

static po_clock_fn po_now_ns  = po_wall_ns_real;   /* timestamps */
static po_clock_fn po_tick_ns = po_mono_ns;        /* intervals  */

/* A test clock: set it, step it, and every timer in the dist moves with it. */
static po_u64 po_fake_now = 0;
static po_u64 po_fake_clock(void) { return po_fake_now; }

static void po_clock_freeze(po_u64 at) {
    po_fake_now = at;
    po_now_ns   = po_fake_clock;
    po_tick_ns  = po_fake_clock;
}
static void po_clock_step(po_u64 by) { po_fake_now += by; }
static void po_clock_real(void) {
    po_now_ns  = po_wall_ns_real;
    po_tick_ns = po_mono_ns;
}

/* Block alignment. Blocks are two hours, epoch-aligned, so that a block's
 * identity is a pure function of a timestamp and two workers never disagree
 * about which block a record belongs to. */
#define PO_BLOCK_NS ((po_u64)2 * 3600 * PO_NS_PER_SEC)

static po_u64 po_block_start(po_u64 t_ns) { return t_ns - (t_ns % PO_BLOCK_NS); }

/* An interval, clamped. A wall clock that stepped backwards mid-span gives
 * end < start; in a uint64_t that subtraction is not a small negative number,
 * it is about 1.8e19. Clamping to zero and counting it is the only safe
 * reading, and phase 7 counts them. */
static po_u64 po_duration(po_u64 start_ns, po_u64 end_ns) {
    return end_ns >= start_ns ? end_ns - start_ns : 0;
}

#endif /* PO_TIME_H */
