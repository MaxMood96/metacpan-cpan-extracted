# Linux::Event::Fork Examples

These scripts are small, focused demos of `Linux::Event::Fork` features.

## Quick start

From the distribution root:

```bash
perl -Ilib examples/12_fork_exit_object.pl
```

Most examples use `Linux::Event` + `Linux::Event::Fork` like this:

```perl
use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

# Optional: configure bounded parallelism at runtime
my $fork = $loop->fork_helper(max_children => 4);

$loop->fork(cmd => [ ... ]);
$loop->run;
```

## Canonical configuration style

This distribution intentionally uses **runtime configuration**:

```perl
my $fork = $loop->fork_helper(max_children => 4);
```

A previous compile-time idiom (`use Linux::Event::Fork max_children => ...;`) is removed.

## Example index

### Core concepts

- **12_fork_exit_object.pl**  
  Demonstrates the `Exit` object and streaming stdout/stderr capture.

- **13_fork_child_callback.pl**  
  Demonstrates `child => sub { ... }` (run code in the child) and why `exec` is recommended.

- **14_fork_stdin_streaming.pl**  
  Demonstrates streaming to the child’s stdin (nonblocking writes) and reading responses.

- **22_timeout_kill.pl**  
  Demonstrates soft timeouts (timeout callback + SIGTERM cleanup).

### Pool / queue policy

- **20_bounded_parallelism_with_drain.pl**  
  Shows `max_children` bounded parallelism, queueing, and `drain()`.

- **23_cancel_queued_by_tag.pl**  
  Shows `cancel_queued()` (only queued requests) and `drain()` to stop when fully idle.

### Practical “real world” demos

- **21_web_fetch_pool.pl**  
  A pool that runs many independent fetch tasks concurrently (using `cmd => [...]`).
  This demonstrates how to build a tiny work-queue without a framework.

### Notes

- **25_chunking_notes.pl**  
  Notes about streaming callbacks: you receive *chunks*, not “lines”, and should buffer if you need framing.

## Tips for users

- `cmd => [...]` is the simplest and fastest form: it forks, wires FDs, then execs.
- Use `tag => ...` to label work (for logs and for canceling queued requests).
- `cancel_queued()` does **not** affect running children.
- `drain(on_done => sub { ... })` fires when both:
  - no children are running, and
  - the queue is empty.
