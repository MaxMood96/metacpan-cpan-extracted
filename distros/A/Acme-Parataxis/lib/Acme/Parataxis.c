/**
 * @file Parataxis.c
 * @brief Low-level Green Threads and Hybrid Thread Pool for Perl.
 *
 * Goals:
 * - Cooperative Multitasking (Fibers): User-mode stack switching
 *   - Implemented via Windows Fibers API or POSIX ucontext
 *   - Manually swap Perl's interpreter internals (stacks, scopes, pads, etc.)
 *
 * - Preemptive Multitasking (Thread Pool): Kernel-mode background tasks
 *   - A fixed pool of native OS threads (pthread/CreateThread)
 *   - Used for blocking C operations (Sleep, Math, IO) to keep the main Perl interpreter responsive
 */

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#else
#ifndef _XOPEN_SOURCE
#define _XOPEN_SOURCE 600
#endif
#ifdef __APPLE__
#ifndef _DARWIN_C_SOURCE
#define _DARWIN_C_SOURCE
#endif
#endif
#endif

#define PERL_NO_GET_CONTEXT
#define NO_XSLOCKS
#include "EXTERN.h"
#include "XSUB.h"
#include "perl.h"

#ifdef _WIN32
#define DLLEXPORT __declspec(dllexport)
typedef LPVOID coro_handle_t;
typedef HANDLE para_thread_t;
typedef CRITICAL_SECTION para_mutex_t;
#define LOCK(m) EnterCriticalSection(&m)
#define UNLOCK(m) LeaveCriticalSection(&m)
#define LOCK_INIT(m) InitializeCriticalSection(&m)
#else
#include <pthread.h>
#include <sched.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <ucontext.h>
#include <unistd.h>
#if defined(__APPLE__) || defined(__FreeBSD__)
#include <sys/sysctl.h>
#include <sys/types.h>
#endif
#define DLLEXPORT __attribute__((visibility("default")))
typedef ucontext_t coro_handle_t;
typedef pthread_t para_thread_t;
typedef pthread_mutex_t para_mutex_t;
#define LOCK(m) pthread_mutex_lock(&m)
#define UNLOCK(m) pthread_mutex_unlock(&m)
#define LOCK_INIT(m) pthread_mutex_init(&m, NULL)
#endif

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Forward declarations
DLLEXPORT SV * coro_yield(SV * ret_val);
DLLEXPORT SV * coro_transfer(int id, SV * args);
DLLEXPORT void destroy_coro(int id);

// Identity and affinity Helpers
/**
 * @brief Get the Operating System's unique Thread ID.
 *
 * Useful for debugging to prove that background tasks are running on
 * different OS threads than the main Perl interpreter.
 *
 * @return int The TID (Windows) or LWP ID (Linux).
 */
int get_os_thread_id() {
#ifdef _WIN32
    return (int)GetCurrentThreadId();
#elif defined(__APPLE__)
    uint64_t tid;
    pthread_threadid_np(NULL, &tid);
    return (int)tid;
#elif defined(SYS_gettid)
    return (int)syscall(SYS_gettid);
#else
    return (int)(intptr_t)pthread_self();
#endif
}

/**
 * @brief Pin the current thread to a specific CPU core.
 *
 * Used by the Thread Pool to ensure worker threads are distributed
 * across available hardware cores for maximum parallelism.
 *
 * @param core_id The zero-based index of the CPU core.
 */
void pin_to_core(int core_id) {
#ifdef _WIN32
    DWORD_PTR mask = (1ULL << core_id);
    SetThreadAffinityMask(GetCurrentThread(), mask);
#elif defined(__linux__)
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(core_id, &cpuset);
    pthread_setaffinity_np(pthread_self(), sizeof(cpu_set_t), &cpuset);
#else
    (void)core_id; /* Not supported on macOS/BSD standard APIs */
#endif
}

/**
 * @brief Get the index of the CPU core currently executing this thread.
 * @return int Core ID (0..N) or -1 if unsupported.
 */
int get_current_cpu() {
#ifdef _WIN32
    return GetCurrentProcessorNumber();
#elif defined(__linux__)
    return sched_getcpu();
#else
    return -1;
#endif
}

/**
 * @brief Detects the number of logical cores available.
 */
int get_cpu_count() {
#ifdef _WIN32
    SYSTEM_INFO sysinfo;
    GetSystemInfo(&sysinfo);
    int count = sysinfo.dwNumberOfProcessors;
    return (count > 0) ? count : 1;
#elif defined(__APPLE__) || defined(__FreeBSD__)
    int nm[2];
    size_t len = 4;
    uint32_t count;
    nm[0] = CTL_HW;
    nm[1] = HW_NCPU;
    sysctl(nm, 2, &count, &len, NULL, 0);
    return (count > 0) ? (int)count : 1;
#else
    long count = sysconf(_SC_NPROCESSORS_ONLN);
    return (count > 0) ? (int)count : 1;
#endif
}

/**
 * @struct my_coro_t
 * @brief The complete context of a Perl Fiber.
 *
 * This structure holds both the OS-level machine state (registers/stack)
 * AND the Perl interpreter's internal state pointers. We must swap both
 * to allow Perl code to pause and resume transparently.
 */
typedef struct {
    // OS state
    coro_handle_t context; /**< OS-specific context handle */

#ifndef _WIN32
    void * stack_p;  /**< Dynamically allocated stack */
    size_t stack_sz; /**< Size of the stack */
#endif

    /*
     * These pointers track the current scope, stack depth, and eval context.
     * Swapping these essentially "pages out" the current Perl execution
     * and "pages in" the target fiber's execution state.
     */
    PERL_SI * si;   /**< Stack Info (recursion frames) */
    AV * curstack;  /**< The Argument Stack (AV*) */
    SV ** stack_sp; /**< The Stack Pointer */

    I32 * markstack;     /**< Mark Stack Base */
    I32 * markstack_ptr; /**< Mark Stack Pointer */
    I32 * markstack_max; /**< Mark Stack Limit */

    I32 * scopestack;   /**< Scope Stack Base */
    I32 scopestack_ix;  /**< Scope Stack Index */
    I32 scopestack_max; /**< Scope Stack Limit */

    ANY * savestack;   /**< Save Stack Base (local/my) */
    I32 savestack_ix;  /**< Save Stack Index */
    I32 savestack_max; /**< Save Stack Limit */

    SV ** tmps_stack; /**< Mortal Stack Base */
    I32 tmps_ix;      /**< Mortal Index */
    I32 tmps_floor;   /**< Mortal Floor */
    I32 tmps_max;     /**< Mortal Limit */

    JMPENV * top_env; /**< Exception Environment (eval/die) */
    COP * curcop;     /**< Current Op Pointer */
    OP * op;          /**< Current Operation */
    PAD * comppad;    /**< Pad (Lexicals) */
    SV ** curpad;     /**< Current Pad Array */
    PMOP * curpm;     /**< Current Pattern Match */

    // Fiber metadata
    SV * user_cv;  /**< The user's code SV (CV*) */
    SV * self_ref; /**< The Acme::Parataxis Perl object */

    SV * transfer_data; /**< Arguments passed during yield/transfer/call */

    int id;          /**< Unique numeric Fiber ID */
    int finished;    /**< Flag: 1 if returned, 0 if running */
    int parent_id;   /**< ID of the caller (for asymmetric yield) */
    int last_sender; /**< ID of the fiber that last transferred control here */
} my_coro_t;

// Thread pool definitions
#define JOB_FREE 0
#define JOB_NEW 1
#define JOB_BUSY 2
#define JOB_DONE 3

#define TASK_SLEEP 0
#define TASK_GET_CPU 1
#define TASK_READ 2
#define TASK_WRITE 3

/**
 * @union value_t
 * @brief Generic container for C-level job arguments/results.
 */
typedef union {
    int64_t i;
    double d;
    char * s;
} value_t;

/**
 * @struct job_t
 * @brief Represents a task submitted to the background thread pool.
 */
typedef struct {
    int fiber_id;      /**< ID of the Fiber waiting for this job */
    int target_thread; /**< Which worker thread should handle this? */
    int type;          /**< Type of task (TASK_SLEEP, etc.) */
    value_t input;     /**< Input Data */
    value_t output;    /**< Output Data (Populated by worker) */
    int timeout_ms;    /**< Timeout for the task in milliseconds */
    int status;        /**< Current status (JOB_NEW -> JOB_DONE) */
} job_t;

// Global state

#define MAX_COROS 128
static my_coro_t * coroutines[MAX_COROS]; /**< Registry of active fibers */
static int coroutine_count = 0;           /**< High-water mark for IDs (unused now) */
static my_coro_t main_context;            /**< Storage for the Main Thread context */
static int current_coro_index = -1;       /**< Currently running Fiber (-1 = Main) */

#define MAX_JOBS 1024
static job_t job_slots[MAX_JOBS]; /**< Fixed-size Job Queue */
static para_mutex_t queue_lock;   /**< Queue protection */

/* Preemption state */
static long long preempt_threshold = 0;
static long long preempt_count = 0;

/* Dynamic Thread Pool State */
#define MAX_THREADS 64
static para_thread_t thread_handles[MAX_THREADS];
static int thread_pool_size = 0;
static volatile int threads_keep_running = 1;

#ifdef _WIN32
static void * main_fiber = NULL;
#endif

/**
 * @brief Background Worker Thread Loop.
 * Pins to a core, polls job_slots, executes C tasks.
 */
#ifdef _WIN32
DWORD WINAPI worker_thread(LPVOID arg) {
#else
void * worker_thread(void * arg) {
#endif
    int thread_id = (int)(intptr_t)arg;
    pin_to_core(thread_id);

    while (threads_keep_running) {
        int found_idx = -1;

        LOCK(queue_lock);
        for (int i = 0; i < MAX_JOBS; i++) {
            if (job_slots[i].status == JOB_NEW && job_slots[i].target_thread == thread_id) {
                job_slots[i].status = JOB_BUSY;
                found_idx = i;
                break;
            }
        }
        UNLOCK(queue_lock);

        if (found_idx != -1) {
            job_t * job = &job_slots[found_idx];

            if (job->type == TASK_SLEEP) {
                int ms = (int)job->input.i;
#ifdef _WIN32
                Sleep(ms);
#else
                usleep(ms * 1000);
#endif
                job->output.i = ms;
            }
            else if (job->type == TASK_GET_CPU) {
                int cpu = get_current_cpu();
                job->output.i = cpu;
            }
            else if (job->type == TASK_READ || job->type == TASK_WRITE) {
                fd_set fds;
                FD_ZERO(&fds);
#ifdef _WIN32
                SOCKET s = (SOCKET)job->input.i;
                FD_SET(s, &fds);
#else
                int fd = (int)job->input.i;
                FD_SET(fd, &fds);
#endif
                // Reset tv inside the loop because select updates it on Linux
                struct timeval tv;
                int res;

                int elapsed_ms = 0;
                int timeout = job->timeout_ms > 0 ? job->timeout_ms : 5000;  // Default 5s

                while (threads_keep_running) {
                    tv.tv_sec = 0;
                    tv.tv_usec = 10000;  // 10ms poll

                    fd_set work_fds = fds;  // Use a copy of the FD set
                    if (job->type == TASK_READ)
#ifdef _WIN32
                        res = select(0, &work_fds, NULL, NULL, &tv);
#else
                        res = select(fd + 1, &work_fds, NULL, NULL, &tv);
#endif
                    else
#ifdef _WIN32
                        res = select(0, NULL, &work_fds, NULL, &tv);
#else
                        res = select(fd + 1, NULL, &work_fds, NULL, &tv);
#endif

                    if (res != 0)
                        break;

                    elapsed_ms += 10;
                    if (elapsed_ms >= timeout)
                        break;
                }
                job->output.i = (res > 0) ? 1 : -1;
            }

            LOCK(queue_lock);
            job->status = JOB_DONE;
            UNLOCK(queue_lock);
        }
        else {
#ifdef _WIN32
            Sleep(1);
#else
            usleep(1000);
#endif
        }
    }
    return 0;
}

DLLEXPORT void init_threads() {
    dTHX;
    LOCK_INIT(queue_lock);
    for (int i = 0; i < MAX_JOBS; i++)
        job_slots[i].status = JOB_FREE;

    // Detect hardware count
    thread_pool_size = get_cpu_count();
    if (thread_pool_size > MAX_THREADS)
        thread_pool_size = MAX_THREADS;

    for (int i = 0; i < thread_pool_size; i++) {
#ifdef _WIN32
        thread_handles[i] = CreateThread(NULL, 0, worker_thread, (LPVOID)(intptr_t)i, 0, NULL);
#else
        pthread_create(&thread_handles[i], NULL, worker_thread, (void *)(intptr_t)i);
        pthread_detach(thread_handles[i]);
#endif
    }
}

/**
 * @brief Submits a task to the background queue.
 * @return int Job index or -1 if queue full.
 */
DLLEXPORT int submit_c_job(int type, int64_t arg, int timeout_ms) {
    static int next_thread = 0;
    int idx = -1;
    LOCK(queue_lock);
    for (int i = 0; i < MAX_JOBS; i++) {
        if (job_slots[i].status == JOB_FREE) {
            idx = i;
            break;
        }
    }
    if (idx != -1) {
        job_slots[idx].fiber_id = current_coro_index;
        job_slots[idx].target_thread = next_thread;
        next_thread = (next_thread + 1) % thread_pool_size;
        job_slots[idx].type = type;
        job_slots[idx].input.i = arg;
        job_slots[idx].timeout_ms = timeout_ms;
        job_slots[idx].status = JOB_NEW;
    }
    UNLOCK(queue_lock);
    return idx;
}

/**
 * @brief Checks if any background jobs have finished.
 * @return int The Job Index that finished, or -1.
 */
DLLEXPORT int check_for_completion() {
    int job_idx = -1;
    LOCK(queue_lock);
    for (int i = 0; i < MAX_JOBS; i++) {
        if (job_slots[i].status == JOB_DONE) {
            job_idx = i;
            break;
        }
    }
    UNLOCK(queue_lock);
    return job_idx;
}

/**
 * @brief Retrieves the result SV from a specific job.
 * @return SV* The result.
 */
DLLEXPORT SV * get_job_result(int idx) {
    dTHX;
    if (idx < 0 || idx >= MAX_JOBS)
        return &PL_sv_undef;
    SV * res = &PL_sv_undef;
    LOCK(queue_lock);
    if (job_slots[idx].status == JOB_DONE || job_slots[idx].status == JOB_BUSY) {
        if (job_slots[idx].type == TASK_SLEEP || job_slots[idx].type == TASK_GET_CPU ||
            job_slots[idx].type == TASK_READ || job_slots[idx].type == TASK_WRITE) {
            res = newSViv(job_slots[idx].output.i);
            sv_2mortal(res);
        }
    }
    UNLOCK(queue_lock);
    return res;
}

DLLEXPORT int get_job_coro_id(int idx) {
    if (idx < 0 || idx >= MAX_JOBS)
        return -1;
    return job_slots[idx].fiber_id;
}

DLLEXPORT void free_job_slot(int idx) {
    if (idx < 0 || idx >= MAX_JOBS)
        return;
    LOCK(queue_lock);
    job_slots[idx].status = JOB_FREE;
    UNLOCK(queue_lock);
}

DLLEXPORT void force_depth_zero(SV * cv_ref) {
    dTHX;
    CV * cv = NULL;
    if (SvROK(cv_ref))
        cv = (CV *)SvRV(cv_ref);
    else if (SvTYPE(cv_ref) == SVt_PVCV)
        cv = (CV *)cv_ref;
    if (cv && SvTYPE((SV *)cv) == SVt_PVCV)
        ((XPVCV *)MUTABLE_PTR(SvANY(cv)))->xcv_depth = 0;
}

DLLEXPORT int get_current_parataxis_id() { return current_coro_index; }
DLLEXPORT int get_os_thread_id_export() { return get_os_thread_id(); }
DLLEXPORT int get_thread_pool_size() { return thread_pool_size; }

DLLEXPORT void set_preempt_threshold(int64_t threshold) { preempt_threshold = threshold; }

DLLEXPORT int64_t get_preempt_count() { return preempt_count; }

DLLEXPORT SV * maybe_yield() {
    dTHX;
    preempt_count++;
    if (preempt_threshold > 0 && preempt_count >= preempt_threshold) {
        preempt_count = 0;
        return coro_yield(&PL_sv_undef);
    }
    return &PL_sv_undef;
}

/**
 * @brief Activates subroutines in the current context stack by restoring their depths.
 *
 * Each fiber needs its own view of the call depth for subroutines it is currently
 * executing. This *should* prevent assertion failures in Perl's pad management (see
 * https://www.cpantesters.org/cpan/report/6b3fa766-0c98-11f1-83fe-bd6d137c6e88) and ensures
 * that recursive calls or multiple fibers running the same sub use distinct pads.
 */
static void _activate_current_depths(pTHX) {
    PERL_SI * si = PL_curstackinfo;
    if (!si || !si->si_cxstack)
        return;
    for (I32 i = 0; i <= si->si_cxix; i++) {
        PERL_CONTEXT * cx = &(si->si_cxstack[i]);
        if (CxTYPE(cx) == CXt_SUB) {
            CV * cv = cx->blk_sub.cv;
            if (cv && SvTYPE((SV *)cv) == SVt_PVCV) {
                // Restore CvDEPTH to the depth this context expects.
                // The current depth is exactly olddepth + 1
                CvDEPTH(cv) = cx->blk_sub.olddepth + 1;
            }
        }
    }
}

/**
 * @brief Swaps the complete Perl Interpreter state between two contexts.
 *
 * This function manually saves and restores the global pointers that the
 * Perl interpreter uses to track execution state. This allows us to
 * pause execution in one fiber and resume in another seamlessly.
 *
 * @param from The context we are leaving (save state here).
 * @param to     The context we are entering (restore state from here).
 */
void swap_perl_state(my_coro_t * from, my_coro_t * to) {
    dTHX; /* Access to the current interpreter */

    // Stack Info (Recursion info, stack bounds)
    from->si = PL_curstackinfo;

    // The Argument Stack (Main Perl stack)
    from->curstack = PL_curstack;
    from->stack_sp = PL_stack_sp;

    // The Mark Stack (Tracks where lists begin on the argument stack)
    from->markstack = PL_markstack;
    from->markstack_ptr = PL_markstack_ptr;
    from->markstack_max = PL_markstack_max;

    // The Scope Stack (Tracks block entry/exit for cleanup)
    from->scopestack = PL_scopestack;
    from->scopestack_ix = PL_scopestack_ix;
    from->scopestack_max = PL_scopestack_max;

    // The Save Stack (Tracks 'local' variables and destructors)
    from->savestack = PL_savestack;
    from->savestack_ix = PL_savestack_ix;
    from->savestack_max = PL_savestack_max;

    // The Mortal Stack (Tracks temporary SVs that need decrementing)
    from->tmps_stack = PL_tmps_stack;
    from->tmps_ix = PL_tmps_ix;
    from->tmps_floor = PL_tmps_floor;
    from->tmps_max = PL_tmps_max;

    // Exception Environment (setjmp/longjmp buffers for eval/die)
    from->top_env = PL_top_env;

    // Op and Pad pointers (Where we are in the bytecode)
    from->curcop = PL_curcop;
    from->op = PL_op;
    from->comppad = PL_comppad;
    from->curpad = PL_curpad;
    from->curpm = PL_curpm;

    // Load target stack
    PL_curstackinfo = to->si;
    PL_curstack = to->curstack;

    // Re-calculate stack bounds based on the new array (AV)
    PL_stack_base = AvARRAY(PL_curstack);
    PL_stack_max = PL_stack_base + AvMAX(PL_curstack);
    PL_stack_sp = to->stack_sp;

    PL_markstack = to->markstack;
    PL_markstack_ptr = to->markstack_ptr;
    PL_markstack_max = to->markstack_max;

    PL_scopestack = to->scopestack;
    PL_scopestack_ix = to->scopestack_ix;
    PL_scopestack_max = to->scopestack_max;

    PL_savestack = to->savestack;
    PL_savestack_ix = to->savestack_ix;
    PL_savestack_max = to->savestack_max;

    PL_tmps_stack = to->tmps_stack;
    PL_tmps_ix = to->tmps_ix;
    PL_tmps_floor = to->tmps_floor;
    PL_tmps_max = to->tmps_max;

    PL_top_env = to->top_env;
    PL_curcop = to->curcop;
    PL_op = to->op;
    PL_comppad = to->comppad;
    PL_curpm = to->curpm;

    if (PL_comppad)
        PL_curpad = AvARRAY(PL_comppad);
    else
        PL_curpad = to->curpad;

    // Restore depths for the newly loaded SI.
    _activate_current_depths(aTHX);
}

/**
 * @brief Allocates and initializes new Perl stacks for a fresh fiber.
 *
 * Each fiber needs its own set of control stacks to operate independently.
 * We allocate them using Perl's internal allocators (Newx) to ensure
 * compatibility with the interpreter's memory management.
 *
 * @param c The fiber context to initialize.
 */
void init_perl_stacks(my_coro_t * c) {
    dTHX;

    // Allocate Stack Info (SI)
    Newxz(c->si, 1, PERL_SI);
    c->si->si_cxmax = 64;

    // Use Newxz to ensure the context stack is zeroed.
    Newxz(c->si->si_cxstack, c->si->si_cxmax, PERL_CONTEXT);
    c->si->si_cxix = -1;
    c->si->si_type = PERLSI_MAIN;

    // Allocate Argument Stack (AV)
    c->curstack = newAV();
    AvREAL_off(c->curstack);
    av_extend(c->curstack, 128);
    c->stack_sp = AvARRAY(c->curstack) - 1;

    // Link the SI to the AV. Perl uses this linkage during stack unwinding/garbage collection.
    c->si->si_stack = c->curstack;

    // Allocate Control Stacks
    I32 sz = 2048;  // Depth of 2048 to support Test2::Vx and, well, unknown depth recursions in general

    Newx(c->markstack, sz, I32);
    c->markstack_ptr = c->markstack;
    *c->markstack_ptr = 0;
    c->markstack_max = c->markstack + sz - 1;

    Newx(c->scopestack, sz, I32);
    c->scopestack_ix = 0;
    c->scopestack_max = sz;

    Newx(c->savestack, sz, ANY);
    c->savestack_ix = 0;
    c->savestack_max = sz;

    Newx(c->tmps_stack, sz, SV *);
    c->tmps_ix = -1;
    c->tmps_floor = -1;
    c->tmps_max = sz;

    // Inherit Initial Environment
    c->curcop = PL_curcop;
    c->op = PL_op;
    c->top_env = PL_top_env;
    c->curpm = PL_curpm;

    // Start with fresh pads to avoid interfering with caller.
    c->comppad = NULL;
    c->curpad = NULL;
}

DLLEXPORT int init_system() {
    dTHX;
    main_context.si = PL_curstackinfo;
    main_context.transfer_data = &PL_sv_undef;
    main_context.id = -1;
    main_context.finished = 0;
    main_context.last_sender = -1;
#ifdef _WIN32
    if (!main_fiber) {
        main_fiber = ConvertThreadToFiber(NULL);
        if (!main_fiber) {
            if (GetLastError() == ERROR_ALREADY_FIBER)
                main_fiber = GetCurrentFiber();
        }
    }
#endif
    init_threads();
    return 0;
}

void perform_switch(int to_id) {
    dTHX;
    if (to_id == current_coro_index)
        return;
    my_coro_t * from = (current_coro_index == -1) ? &main_context : coroutines[current_coro_index];
    my_coro_t * to = (to_id == -1) ? &main_context : coroutines[to_id];

    // Track where we are coming from so the target can return here if needed
    to->last_sender = current_coro_index;

    current_coro_index = to_id;
    swap_perl_state(from, to);
#ifdef _WIN32
    if (to_id == -1)
        SwitchToFiber(main_fiber);
    else
        SwitchToFiber(to->context);
#else
    swapcontext(&from->context, &to->context);
#endif
}

DLLEXPORT SV * coro_yield(SV * ret_val) {
    dTHX;

    if (current_coro_index == -1)
        return &PL_sv_undef;

    my_coro_t * self = coroutines[current_coro_index];
    int parent = self->parent_id;

    // If parent is finished, missing, or destroyed, try the last sender. Fallback mode
    if (parent != -1 && (!coroutines[parent] || coroutines[parent]->finished))
        parent = self->last_sender;
    else if (parent == -1)
        parent = self->last_sender;

    // If the fallback is *also* finished or destroyed, go back to main
    if (parent >= 0 && (!coroutines[parent] || coroutines[parent]->finished))
        parent = -1;

    my_coro_t * caller = (parent == -1) ? &main_context : coroutines[parent];

    if (caller->transfer_data != ret_val) {
        if (caller->transfer_data && caller->transfer_data != &PL_sv_undef)
            SvREFCNT_dec(caller->transfer_data);
        caller->transfer_data = ret_val;
        if (ret_val && ret_val != &PL_sv_undef)
            SvREFCNT_inc(ret_val);
    }

    perform_switch(parent);

    SV * res = self->transfer_data;
    self->transfer_data = &PL_sv_undef;
    // Mortalize result before returning to Perl to avoid leaking the reference
    // created by the transfer mechanism.
    if (res && res != &PL_sv_undef)
        sv_2mortal(res);
    return res;
}

static void entry_point(my_coro_t * c) {
    dTHX;

    ENTER;
    SAVETMPS;

    dSP;
    PUSHMARK(SP);
    // Unpack arguments if transfer_data is an array ref
    if (c->transfer_data && SvROK(c->transfer_data) && SvTYPE(SvRV(c->transfer_data)) == SVt_PVAV) {
        AV * args = (AV *)SvRV(c->transfer_data);
        I32 len = av_top_index(args) + 1;
        for (I32 i = 0; i < len; i++) {
            SV ** svp = av_fetch(args, i, 0);
            if (svp)
                XPUSHs(*svp);
        }
    }
    PUTBACK;

    // Catch exceptions so the sky doesn't fall on our heads
    int count = call_sv(c->user_cv, G_SCALAR | G_EVAL);

    SPAGAIN;

    SV * ret_val = &PL_sv_undef;
    if (count == 1)
        ret_val = POPs;
    PUTBACK;

    // Immediately set finished to true so is_done() will call destroy_coro() even if subsequent operations fail.
    // It's working as I imagine it but this is probably wrong...
    c->finished = true;

    // Clear the old transfer_data (arguments passed in)
    if (c->transfer_data && c->transfer_data != &PL_sv_undef) {
        SvREFCNT_dec(c->transfer_data);
        c->transfer_data = &PL_sv_undef;
    }

    // Store result for fiber in transfer_data and inc refcnt so it survives FREETMPS and can be cleaned up by
    // destroy_coro
    if (ret_val && ret_val != &PL_sv_undef) {
        SvREFCNT_inc(ret_val);
        c->transfer_data = ret_val;
    }

    // Report result/error to the Perl object
    if (c->self_ref && SvROK(c->self_ref)) {
        dSP;
        ENTER;
        SAVETMPS;
        PUSHMARK(SP);
        XPUSHs(c->self_ref);
        if (SvTRUE(ERRSV)) {
            XPUSHs(ERRSV);
            PUTBACK;
            call_method("set_error", G_DISCARD);
        }
        else {
            XPUSHs(ret_val);
            PUTBACK;
            call_method("set_result", G_DISCARD);
        }
        FREETMPS;
        LEAVE;
    }

    FREETMPS;
    LEAVE;

    // Yield the result stored in transfer_data
    // coro_yield will inc it again for the caller.
    coro_yield(c->transfer_data ? c->transfer_data : &PL_sv_undef);

    while (1)
        coro_yield(&PL_sv_undef);
}

#ifdef _WIN32
static void WINAPI fiber_entry(void * param) { entry_point((my_coro_t *)param); }
#else
static void posix_entry(int id) { entry_point(coroutines[id]); }
#endif

DLLEXPORT int create_coro_ptr(SV * user_code, SV * self_ref) {
    dTHX;
    int idx = -1;
    for (int i = 0; i < MAX_COROS; i++) {
        if (coroutines[i] == NULL) {
            idx = i;
            break;
        }
    }
    if (idx == -1)
        return -2;

    my_coro_t * c = (my_coro_t *)malloc(sizeof(my_coro_t));
    if (!c)
        return -3;
    memset(c, 0, sizeof(my_coro_t));

    c->user_cv = user_code;
    if (user_code && user_code != &PL_sv_undef)
        SvREFCNT_inc(user_code);

    c->self_ref = self_ref;
    if (self_ref && self_ref != &PL_sv_undef)
        SvREFCNT_inc(self_ref);
    c->id = idx;
    c->parent_id = -1;
    c->last_sender = -1;
    c->transfer_data = &PL_sv_undef;
    coroutines[idx] = c;
    init_perl_stacks(c);
#ifdef _WIN32
    c->context = CreateFiber(0, fiber_entry, c);
#else
    c->stack_sz = 2 * 1024 * 1024;
    // posix_memalign ensures 16-byte alignment
    if (posix_memalign(&c->stack_p, 16, c->stack_sz) != 0) {
        destroy_coro(idx);  // Clean up partially created coro
        return -3;
    }

    getcontext(&c->context);
    c->context.uc_stack.ss_sp = c->stack_p;
    c->context.uc_stack.ss_size = c->stack_sz;
    c->context.uc_link = &main_context.context;
    makecontext(&c->context, (void (*)())posix_entry, 1, c->id);
#endif
    return idx;
}

DLLEXPORT SV * coro_call(int id, SV * args) {
    dTHX;
    if (id < 0 || id >= MAX_COROS || !coroutines[id] || coroutines[id]->finished)
        return &PL_sv_undef;

    if (coroutines[id]->transfer_data != args) {
        if (coroutines[id]->transfer_data && coroutines[id]->transfer_data != &PL_sv_undef)
            SvREFCNT_dec(coroutines[id]->transfer_data);
        coroutines[id]->transfer_data = args;
        if (args && args != &PL_sv_undef)
            SvREFCNT_inc(args);
    }

    coroutines[id]->parent_id = current_coro_index;
    perform_switch(id);

    // If the fiber finished during this call, ensure we release the arguments
    // we passed to it. The results are in our own transfer_data.
    if (coroutines[id] && coroutines[id]->finished) {
        if (coroutines[id]->transfer_data && coroutines[id]->transfer_data != &PL_sv_undef) {
            SvREFCNT_dec(coroutines[id]->transfer_data);
            coroutines[id]->transfer_data = &PL_sv_undef;
        }
    }

    my_coro_t * me = (current_coro_index == -1) ? &main_context : coroutines[current_coro_index];
    SV * res = me->transfer_data;
    me->transfer_data = &PL_sv_undef;
    // Mortalize result before returning to Perl
    if (res && res != &PL_sv_undef)
        sv_2mortal(res);
    return res;
}

DLLEXPORT SV * coro_transfer(int id, SV * args) {
    dTHX;
    if (id < -1 || (id >= 0 && (id >= MAX_COROS || !coroutines[id])))
        return &PL_sv_undef;
    if (id >= 0 && coroutines[id]->finished)
        return &PL_sv_undef;
    my_coro_t * target = (id == -1) ? &main_context : coroutines[id];

    if (target->transfer_data != args) {
        if (target->transfer_data && target->transfer_data != &PL_sv_undef)
            SvREFCNT_dec(target->transfer_data);
        target->transfer_data = args;
        if (args && args != &PL_sv_undef)
            SvREFCNT_inc(args);
    }

    perform_switch(id);

    // If the target fiber was a real fiber (not main) and it finished during this transfer,
    // ensure we release the arguments we passed to it.
    if (id >= 0 && coroutines[id] && coroutines[id]->finished) {
        if (coroutines[id]->transfer_data && coroutines[id]->transfer_data != &PL_sv_undef) {
            SvREFCNT_dec(coroutines[id]->transfer_data);
            coroutines[id]->transfer_data = &PL_sv_undef;
        }
    }

    my_coro_t * me = (current_coro_index == -1) ? &main_context : coroutines[current_coro_index];
    SV * res = me->transfer_data;
    me->transfer_data = &PL_sv_undef;
    // Mortalize result before returning to Perl
    if (res && res != &PL_sv_undef)
        sv_2mortal(res);
    return res;
}

DLLEXPORT int is_finished(int id) {
    if (id < 0)
        return 0;
    return (coroutines[id] && coroutines[id]->finished) ? 1 : 0;
}

static void recursive_depth_reset(pTHX_ CV * cv) {
    if (!cv || SvTYPE((SV *)cv) != SVt_PVCV)
        return;
    if (CvDEPTH(cv) > 0)
        CvDEPTH(cv) = 0;
}

DLLEXPORT void destroy_coro(int id) {
    dTHX;
    if (id < 0 || id >= MAX_COROS)
        return;
    my_coro_t * c = coroutines[id];
    if (!c)
        return;

    coroutines[id] = NULL;  // Prevent re-entry
    // Depth reset is kinda the most difficult part... First, we gotta deal with...
    // User CV*
    if (c->user_cv && c->user_cv != &PL_sv_undef) {
        CV * cv = NULL;
        if (SvROK(c->user_cv))
            cv = (CV *)SvRV(c->user_cv);
        else if (SvTYPE(c->user_cv) == SVt_PVCV)
            cv = (CV *)c->user_cv;
        if (cv)
            recursive_depth_reset(aTHX_ cv);
    }

    // The context stack
    if (c->si && c->si->si_cxstack) {
        for (I32 i = 0; i <= c->si->si_cxix; i++) {
            PERL_CONTEXT * cx = &(c->si->si_cxstack[i]);
            if (CxTYPE(cx) == CXt_SUB || CxTYPE(cx) == CXt_FORMAT)
                recursive_depth_reset(aTHX_ cx->blk_sub.cv);
        }
    }

    // Scan the argument stack for ANY other CVs
    if (c->curstack) {
        SSize_t fill = av_top_index(c->curstack);
        SV ** ary = AvARRAY(c->curstack);
        for (SSize_t i = 0; i <= fill; i++) {
            SV * sv = ary[i];
            if (sv && SvROK(sv)) {
                SV * rv = SvRV(sv);
                if (rv && SvTYPE(rv) == SVt_PVCV)
                    recursive_depth_reset(aTHX_(CV *) rv);
            }
            else if (sv && SvTYPE(sv) == SVt_PVCV) {
                recursive_depth_reset(aTHX_(CV *) sv);
            }
        }
    }

    if (PL_dirty) {
#ifndef _WIN32
        if (c->stack_p)
            free(c->stack_p);
#endif
        free(c);
        return;
    }

#ifdef _WIN32
    if (c->context)
        DeleteFiber(c->context);
#else
    if (c->stack_p)
        free(c->stack_p);
#endif

    // Now, it should be safe for cleanup
    if (c->si) {
        if (c->si->si_cxstack)
            Safefree(c->si->si_cxstack);
        Safefree(c->si);
    }

    if (c->curstack) {
        av_clear(c->curstack);
        SvREFCNT_dec((SV *)c->curstack);
        c->curstack = NULL;
    }

    if (c->markstack)
        Safefree(c->markstack);
    if (c->scopestack)
        Safefree(c->scopestack);
    if (c->savestack)
        Safefree(c->savestack);
    if (c->tmps_stack) {
        for (I32 i = 0; i <= c->tmps_ix; i++) {
            SV * sv = c->tmps_stack[i];
            if (sv && sv != &PL_sv_undef)
                SvREFCNT_dec(sv);
        }
        Safefree(c->tmps_stack);
    }

    if (c->user_cv && c->user_cv != &PL_sv_undef) {
        SvREFCNT_dec(c->user_cv);
        c->user_cv = NULL;
    }

    if (c->self_ref && c->self_ref != &PL_sv_undef) {
        SvREFCNT_dec(c->self_ref);
        c->self_ref = NULL;
    }

    if (c->transfer_data && c->transfer_data != &PL_sv_undef) {
        SvREFCNT_dec(c->transfer_data);
        c->transfer_data = NULL;
    }

    free(c);
}

DLLEXPORT void cleanup() {
    dTHX;
    threads_keep_running = 0;
#ifdef _WIN32
    Sleep(10);
#else
    usleep(10000);
#endif
    if (current_coro_index != -1) {
        swap_perl_state(coroutines[current_coro_index], &main_context);
        current_coro_index = -1;
    }
    for (int i = 0; i < MAX_COROS; i++)
        if (coroutines[i])
            destroy_coro(i);

    if (main_context.transfer_data && main_context.transfer_data != &PL_sv_undef) {
        SvREFCNT_dec(main_context.transfer_data);
        main_context.transfer_data = &PL_sv_undef;
    }
}
