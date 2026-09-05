#ifndef _GNU_SOURCE
# define _GNU_SOURCE
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <spawn.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern char **environ;

#ifndef P_PIDFD
# define P_PIDFD 3
#endif

#ifndef SYS_pidfd_open
# ifdef __NR_pidfd_open
#  define SYS_pidfd_open __NR_pidfd_open
# else
#  error "Linux::Event::Kernel::Process requires Linux headers with pidfd_open"
# endif
#endif

#ifndef SYS_pidfd_send_signal
# ifdef __NR_pidfd_send_signal
#  define SYS_pidfd_send_signal __NR_pidfd_send_signal
# else
#  error "Linux::Event::Kernel::Process requires Linux headers with pidfd_send_signal"
# endif
#endif

static void
lep_free_vector(char **vector)
{
    size_t index;
    if (!vector) return;
    for (index = 0; vector[index]; index++)
        free(vector[index]);
    free(vector);
}

static char **
lep_command_vector(SV *command)
{
    AV *array;
    SSize_t last, index;
    char **vector;
    if (!SvROK(command) || SvTYPE(SvRV(command)) != SVt_PVAV)
        croak("command must be an array reference");
    array = (AV *)SvRV(command);
    last = av_len(array);
    if (last < 0)
        croak("command must contain at least one argument");
    vector = (char **)calloc((size_t)last + 2, sizeof(char *));
    if (!vector)
        croak("cannot allocate command vector");
    for (index = 0; index <= last; index++) {
        SV **item = av_fetch(array, index, 0);
        STRLEN length;
        const char *bytes;
        if (!item || !SvOK(*item) || SvROK(*item)) {
            lep_free_vector(vector);
            croak("every command argument must be a defined scalar");
        }
        bytes = SvPVbyte(*item, length);
        if (memchr(bytes, '\0', length)) {
            lep_free_vector(vector);
            croak("command arguments cannot contain NUL bytes");
        }
        vector[index] = strndup(bytes, length);
        if (!vector[index]) {
            lep_free_vector(vector);
            croak("cannot copy command argument");
        }
    }
    return vector;
}

static char **
lep_environment_vector(SV *environment)
{
    HV *hash;
    HE *entry;
    size_t count, index = 0;
    char **vector;
    if (!SvOK(environment))
        return NULL;
    if (!SvROK(environment) || SvTYPE(SvRV(environment)) != SVt_PVHV)
        croak("env must be a hash reference");
    hash = (HV *)SvRV(environment);
    count = (size_t)HvTOTALKEYS(hash);
    vector = (char **)calloc(count + 1, sizeof(char *));
    if (!vector)
        croak("cannot allocate environment vector");
    hv_iterinit(hash);
    while ((entry = hv_iternext(hash))) {
        STRLEN key_length, value_length;
        const char *key = HePV(entry, key_length);
        SV *value_sv = HeVAL(entry);
        const char *value;
        size_t length;
        if (!SvOK(value_sv) || SvROK(value_sv)) {
            lep_free_vector(vector);
            croak("every environment value must be a defined scalar");
        }
        value = SvPVbyte(value_sv, value_length);
        if (!key_length || memchr(key, '=', key_length)
                || memchr(key, '\0', key_length)
                || memchr(value, '\0', value_length)) {
            lep_free_vector(vector);
            croak("environment names must be nonempty; names and values must be NUL-free");
        }
        length = (size_t)key_length + 1 + (size_t)value_length;
        vector[index] = (char *)malloc(length + 1);
        if (!vector[index]) {
            lep_free_vector(vector);
            croak("cannot copy environment entry");
        }
        memcpy(vector[index], key, key_length);
        vector[index][key_length] = '=';
        memcpy(vector[index] + key_length + 1, value, value_length);
        vector[index][length] = '\0';
        index++;
    }
    return vector;
}

static int
lep_add_stdio(posix_spawn_file_actions_t *actions, int source, int target)
{
    if (source < 0)
        return 0;
    if (source == target)
        return 0;
    return posix_spawn_file_actions_adddup2(actions, source, target);
}

static int
lep_duplicate_source(int source)
{
    int duplicate;
    if (source < 0)
        return source;
    do {
        duplicate = fcntl(source, F_DUPFD_CLOEXEC, STDERR_FILENO + 1);
    } while (duplicate < 0 && errno == EINTR);
    return duplicate;
}

MODULE = Linux::Event::Kernel::Process    PACKAGE = Linux::Event::Kernel::Process

PROTOTYPES: DISABLE

SV *
_spawn(command, environment, cwd, stdin_fd, stdout_fd, stderr_fd, close_fds)
    SV *command
    SV *environment
    SV *cwd
    int stdin_fd
    int stdout_fd
    int stderr_fd
    SV *close_fds
  PREINIT:
    char **argv = NULL;
    char **envp = NULL;
    const char *cwd_bytes = NULL;
    STRLEN cwd_length = 0;
    posix_spawn_file_actions_t actions;
    int actions_ready = 0;
    int error = 0;
    pid_t pid = -1;
    int pidfd = -1;
    int safe_stdin = -1;
    int safe_stdout = -1;
    int safe_stderr = -1;
    AV *close_array;
    SSize_t close_last, index;
    AV *result;
  CODE:
    argv = lep_command_vector(command);
    envp = lep_environment_vector(environment);
    if (SvOK(cwd)) {
        cwd_bytes = SvPVbyte(cwd, cwd_length);
        if (!cwd_length || memchr(cwd_bytes, '\0', cwd_length)) {
            lep_free_vector(argv);
            lep_free_vector(envp);
            croak("cwd must be a non-empty NUL-free path");
        }
    }
    if (!SvROK(close_fds) || SvTYPE(SvRV(close_fds)) != SVt_PVAV) {
        lep_free_vector(argv);
        lep_free_vector(envp);
        croak("internal close_fds must be an array reference");
    }
    close_array = (AV *)SvRV(close_fds);
    close_last = av_len(close_array);
    safe_stdin = lep_duplicate_source(stdin_fd);
    if (stdin_fd >= 0 && safe_stdin < 0)
        error = errno;
    if (!error) {
        safe_stdout = lep_duplicate_source(stdout_fd);
        if (stdout_fd >= 0 && safe_stdout < 0)
            error = errno;
    }
    if (!error && stderr_fd >= 0) {
        safe_stderr = lep_duplicate_source(stderr_fd);
        if (safe_stderr < 0)
            error = errno;
    }
    if (!error)
        error = posix_spawn_file_actions_init(&actions);
    if (!error) actions_ready = 1;
    if (!error) error = lep_add_stdio(&actions, safe_stdin, STDIN_FILENO);
    if (!error) error = lep_add_stdio(&actions, safe_stdout, STDOUT_FILENO);
    if (!error && stderr_fd == -2)
        error = posix_spawn_file_actions_adddup2(
            &actions, STDOUT_FILENO, STDERR_FILENO);
    else if (!error)
        error = lep_add_stdio(&actions, safe_stderr, STDERR_FILENO);
    if (!error && safe_stdin >= 0)
        error = posix_spawn_file_actions_addclose(&actions, safe_stdin);
    if (!error && safe_stdout >= 0)
        error = posix_spawn_file_actions_addclose(&actions, safe_stdout);
    if (!error && safe_stderr >= 0)
        error = posix_spawn_file_actions_addclose(&actions, safe_stderr);
#ifdef LEP_HAVE_POSIX_SPAWN_CHDIR
    if (!error && cwd_bytes)
        error = posix_spawn_file_actions_addchdir_np(&actions, cwd_bytes);
#else
    if (!error && cwd_bytes)
        error = ENOTSUP;
#endif
    for (index = 0; !error && index <= close_last; index++) {
        SV **item = av_fetch(close_array, index, 0);
        int fd;
        SSize_t previous;
        if (!item || !SvOK(*item) || SvROK(*item)) {
            error = EINVAL;
            break;
        }
        fd = (int)SvIV(*item);
        for (previous = 0; previous < index; previous++) {
            SV **earlier = av_fetch(close_array, previous, 0);
            if (earlier && SvOK(*earlier) && !SvROK(*earlier)
                    && (int)SvIV(*earlier) == fd)
                break;
        }
        if (fd > STDERR_FILENO && previous == index)
            error = posix_spawn_file_actions_addclose(&actions, fd);
    }
    if (!error)
        error = posix_spawnp(&pid, argv[0], &actions, NULL, argv,
            envp ? envp : environ);
    if (actions_ready)
        posix_spawn_file_actions_destroy(&actions);
    if (safe_stdin >= 0) close(safe_stdin);
    if (safe_stdout >= 0) close(safe_stdout);
    if (safe_stderr >= 0) close(safe_stderr);
    lep_free_vector(argv);
    lep_free_vector(envp);
    if (error)
        croak("posix_spawn: %s", Strerror(error));
    do {
        pidfd = (int)syscall(SYS_pidfd_open, pid, 0);
    } while (pidfd < 0 && errno == EINTR);
    if (pidfd < 0) {
        int saved_errno = errno;
        kill(pid, SIGKILL);
        while (waitpid(pid, NULL, 0) < 0 && errno == EINTR) { }
        croak("pidfd_open: %s", Strerror(saved_errno));
    }
    result = newAV();
    av_push(result, newSViv((IV)pid));
    av_push(result, newSViv((IV)pidfd));
    RETVAL = newRV_noinc((SV *)result);
  OUTPUT:
    RETVAL

SV *
_pipe_cloexec()
  PREINIT:
    int descriptors[2];
    AV *result;
  CODE:
    if (pipe2(descriptors, O_CLOEXEC) < 0)
        croak("pipe2: %s", Strerror(errno));
    result = newAV();
    av_push(result, newSViv(descriptors[0]));
    av_push(result, newSViv(descriptors[1]));
    RETVAL = newRV_noinc((SV *)result);
  OUTPUT:
    RETVAL

int
_pidfd_open(pid)
    IV pid
  CODE:
    if (pid <= 0 || pid > INT_MAX)
        croak("pid must be a positive integer");
    do {
        RETVAL = (int)syscall(SYS_pidfd_open, (pid_t)pid, 0);
    } while (RETVAL < 0 && errno == EINTR);
    if (RETVAL < 0)
        croak("pidfd_open: %s", Strerror(errno));
  OUTPUT:
    RETVAL

void
_pidfd_send(pidfd, signal_number)
    int pidfd
    int signal_number
  PREINIT:
    int result;
  CODE:
    if (signal_number <= 0 || signal_number >= NSIG)
        croak("signal(): signal must be a positive valid signal number");
    do {
        result = (int)syscall(
            SYS_pidfd_send_signal, pidfd, signal_number, NULL, 0);
    } while (result < 0 && errno == EINTR);
    if (result < 0)
        croak("pidfd_send_signal: %s", Strerror(errno));

SV *
_pidfd_reap(pidfd)
    int pidfd
  PREINIT:
    siginfo_t information;
    int status;
    AV *result;
  CODE:
    memset(&information, 0, sizeof(information));
    do {
        status = waitid((idtype_t)P_PIDFD, (id_t)pidfd, &information,
            WEXITED | WNOHANG);
    } while (status < 0 && errno == EINTR);
    if (status < 0)
        croak("waitid: %s", Strerror(errno));
    if (!information.si_pid) {
        RETVAL = newSV(0);
    } else {
        result = newAV();
        av_push(result, newSViv((IV)information.si_code));
        av_push(result, newSViv((IV)information.si_status));
        RETVAL = newRV_noinc((SV *)result);
    }
  OUTPUT:
    RETVAL

void
_drain_pipe(self, callback, fd, read_size, maximum)
    SV *self
    SV *callback
    int fd
    UV read_size
    UV maximum
  PREINIT:
    UV reads = 0;
    int status = 0;
    int saved_errno = 0;
    ssize_t count;
    SV *chunk;
    char *buffer;
  PPCODE:
    if (!read_size || read_size > (UV)INT_MAX)
        croak("native Process pipe read size is invalid");
    while (!maximum || reads < maximum) {
        ENTER;
        SAVETMPS;
        chunk = sv_2mortal(newSV((STRLEN)read_size));
        SvPOK_only(chunk);
        buffer = SvGROW(chunk, (STRLEN)read_size + 1);
        do {
            count = read(fd, buffer, (size_t)read_size);
        } while (count < 0 && errno == EINTR);
        if (count > 0) {
            SvCUR_set(chunk, (STRLEN)count);
            *SvEND(chunk) = '\0';
            reads++;
            if (SvOK(callback)) {
                dSP;
                PUSHMARK(SP);
                EXTEND(SP, 2);
                PUSHs(self);
                PUSHs(chunk);
                PUTBACK;
                call_sv(callback, G_DISCARD | G_VOID);
                SPAGAIN;
                PUTBACK;
            }
            FREETMPS;
            LEAVE;
            continue;
        }
        if (count == 0) {
            status = 1;
        } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
            status = 2;
            saved_errno = errno;
        }
        FREETMPS;
        LEAVE;
        break;
    }
    EXTEND(SP, 2);
    PUSHs(sv_2mortal(newSViv(status)));
    PUSHs(sv_2mortal(newSViv(saved_errno)));

void
_write_pipe(fd, payload)
    int fd
    SV *payload
  PREINIT:
    STRLEN length;
    const char *bytes;
    ssize_t written;
    int saved_errno = 0;
    sigset_t blocked, previous, pending;
    int already_pending = 0;
    struct timespec zero = { 0, 0 };
  PPCODE:
    bytes = SvPVbyte(payload, length);
    sigemptyset(&blocked);
    sigaddset(&blocked, SIGPIPE);
    pthread_sigmask(SIG_BLOCK, &blocked, &previous);
    sigpending(&pending);
    already_pending = sigismember(&pending, SIGPIPE);
    do {
        written = write(fd, bytes, length);
    } while (written < 0 && errno == EINTR);
    if (written < 0)
        saved_errno = errno;
    if (written < 0 && saved_errno == EPIPE && !already_pending)
        sigtimedwait(&blocked, NULL, &zero);
    pthread_sigmask(SIG_SETMASK, &previous, NULL);
    EXTEND(SP, 2);
    PUSHs(sv_2mortal(newSViv((IV)written)));
    PUSHs(sv_2mortal(newSViv(saved_errno)));

void
_close_fd(fd)
    int fd
  CODE:
    if (close(fd) < 0 && errno != EBADF)
        croak("close: %s", Strerror(errno));
