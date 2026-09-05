# Kernel Process design

`Linux::Event::Kernel::Process` combines pidfd lifecycle notification and
optional asynchronous standard I/O in one logical Loop resource. It avoids
PID-reuse races and never runs Perl code in a post-fork child setup path.

## Public type model

A concrete subclass defines `on_exit` and whichever stdio callbacks it needs:

```perl
package BuildProcess;
use parent 'Linux::Event::Kernel::Process';

sub on_stdout ($process, $bytes) {
    print "build: $bytes";
}

sub on_stderr ($process, $bytes) {
    warn "build: $bytes";
}

sub on_exit ($process) {
    if (defined(my $code = $process->exit_code)) {
        say "build exited with $code";
    }
    else {
        say "build received signal " . $process->term_signal;
    }
    $process->loop->stop;
}
```

Callbacks are cached once per concrete subclass. One Process object owns the
pidfd, configured stdio pipes, Loop registrations, queue state, decoded status,
and application `data`.

## Native spawning

`spawn()` accepts an argument vector and never inserts a shell:

```perl
my $process = $loop->add(BuildProcess->spawn(
    command => ['/usr/bin/make', '-j4'],
    cwd     => '/srv/project',
    env     => { BUILD_MODE => 'test' },
    stdin   => 'pipe',
    stdout  => 'pipe',
    stderr  => 'pipe',
    data    => { started_by => 'api' },
));
```

Construction stores a specification. The child is created when the object is
attached through `loop => $loop` or `$loop->add(...)`; `pid()` is therefore
undefined while detached.

The native extension uses `posix_spawnp`. Pipes are created with close-on-exec
semantics. File actions establish stdio, close temporary child-side descriptors,
and optionally change directory with the supported libc spawn extension.

No Perl interpreter callback, application lock, or Perl allocator work is run
in a post-fork child setup path. This is an important safety property after
other Linux::Event native worker services exist.

`env` is a complete replacement environment. Omit it to inherit the current
environment. Use an explicit shell argv only when shell parsing is intentional.

## Standard I/O modes

Each standard descriptor accepts the supported forms:

| Value | Child behavior | Parent ownership |
| --- | --- | --- |
| `inherit` | retains the corresponding parent descriptor | no new handle |
| `pipe` | connects to a nonblocking parent pipe end | Process owns parent end |
| `null` | connects to `/dev/null` | temporary setup handle closed |
| filehandle | duplicates it onto child stdio | caller retains original handle |
| `stdout` for stderr | duplicates child stdout to child stderr | follows stdout policy |

`on_stdout`/`on_stdout_eof` require `stdout => 'pipe'`. Corresponding stderr
callbacks require a stderr pipe. `on_stdin_drain` requires a stdin pipe.
Impossible callback/configuration combinations fail during construction.

## Output draining

Process stdout and stderr pipes use dedicated native draining. Each successful
native read still invokes the cached application callback with that read's byte
string. Moving the mechanical read loop into XS does not silently aggregate
application output into a different callback protocol.

`read_size` bounds one callback payload. `max_reads_per_tick` remains the
per-descriptor fairness bound. EAGAIN, EOF, and hard errors return through the
Process lifecycle/error policy.

Process pipe I/O is intentionally owned by Process rather than exposed as
separate public `IO::Pipe` objects: the pipe lifecycle and callbacks are part of
the one child-process resource. Applications that independently own unrelated
pipes use `Linux::Event::IO::Pipe` directly.

## Standard input and backpressure

`write_stdin()` attempts an immediate write and queues any accepted remainder.
It can be called while detached; queued bytes remain pending until attachment.

Crossing `stdin_high_watermark` returns false while accepting the bytes.
`on_stdin_drain` fires when pending output reaches `stdin_low_watermark`.

A nonzero `max_pending_stdin` is a separate hard limit. Overflow rejects the
unsent bytes, closes Process stdin according to the current error contract, and
reports `output_limit`.

`close_stdin()` is graceful: it rejects new writes, drains accepted bytes, then
closes the child stdin pipe to deliver EOF.

Native pipe writes handle SIGPIPE without installing or changing a
process-global Perl signal disposition.

## Observing an existing process

An existing PID can be observed:

```perl
my $process = $loop->add(BuildProcess->new(
    pid  => $pid,
    reap => 1,
));
```

`reap => 1` uses `waitid(P_PIDFD)` and requires the target to be this process's
child. `reap => 0` supports pidfd lifecycle notification for a non-child while
leaving child wait-status fields unavailable.

Opening the pidfd during attachment pins the kernel process identity even if the
numeric PID is later reused.

## Exit and status

Pidfd readability triggers nonblocking wait processing. For a reaped child,
Process records the decoded exit code or terminating signal, core-dump state,
and conventional raw wait status.

Before `on_exit`, Linux::Event drains stdout/stderr bytes already available at
the current nonblocking boundary and closes remaining Process-owned stdio ends.
It deliberately does not keep the Process object alive merely because a
descendant inherited an output descriptor.

The Loop remains available during `on_exit` and is released afterward, including
when the callback throws. Callback exceptions propagate after native cleanup
restores a safe state.

## Signals

`signal($number)` uses `pidfd_send_signal`, so it cannot accidentally target a
new process that later reused the same numeric PID. Failure is reported through
the structured Process error contract.

There is deliberately no generic `cancel()` operation. Stopping observation,
sending a signal, closing stdin, and waiting for confirmed exit are different
operations. Applications choose an explicit shutdown policy and continue
running the Loop until `on_exit` confirms terminal state.

## Failure containment

If spawning succeeds but Linux::Event cannot finish pidfd/descriptor setup, the
implementation kills and reaps that exact child before propagating the setup
failure. Partial Loop registrations and pipe resources are closed.

Linux::Event does not fall back from an available pidfd identity to a racy
numeric-PID signal path merely because later setup failed.

Asynchronous stdio errors use the Process I/O error type; pidfd/wait lifecycle
errors use the Process lifecycle error type. `last_error` retains the most
recent structured error and an `on_error` subclass hook can handle it.

## Ownership and Loop destruction

The Loop retains a running `Kernel::Process`. Dropping an application reference
does not cancel notification or kill the child.

Conversely, destroying the Loop closes Linux::Event resources but does not
silently choose a signal to send to the child. Applications must define their
shutdown policy and keep the Loop alive until children that they own for reaping
have reached terminal state.

Spawned children and observed children with `reap => 1` exclusively own their
wait status through this Process object. Do not combine that mode with an
independent `wait`, `waitpid`, or SIGCHLD reaper for the same PID. Use
`reap => 0` when another component owns reaping and only pidfd lifecycle
notification is required.

## Platform contract

Process lifecycle/status requires Linux pidfd support and build headers for the
pidfd syscalls used by the distribution. Native spawning also requires the libc
spawn file-action capability used for configured working directories.

These constraints are explicit because a fallback based on running arbitrary
Perl child setup after fork would violate the thread-safety architecture.

## Performance model

One Process object can own pidfd plus stdin/stdout/stderr registrations without
creating public wrapper objects for each fd. Native stdout/stderr draining and
SIGPIPE-safe stdin writes keep mechanical syscall loops below the semantic Perl
callback boundary.

The Process-specific benchmark suite measures lifecycle, pipe draining, stdin
queue behavior, and native helper costs separately from generic ordered-byte and
reactor benchmarks.

## Native implementation boundary

`Linux::Event::Kernel::Process` is both the supported public class and the XS
host for pidfd lifecycle, native spawn, and Process stdio. Private helpers stay
behind that class and do not add another Perl dispatch boundary.
