# Linux::Event::Fork

[![CI](https://github.com/haxmeister/perl-linux-event-fork/actions/workflows/ci.yml/badge.svg)](https://github.com/haxmeister/perl-linux-event-fork/actions/workflows/ci.yml)

Minimal async child process management on top of Linux::Event.

This module adds:

- Nonblocking stdout/stderr capture
- Streaming stdin
- Soft timeouts
- Tagging
- Bounded parallelism (`max_children`)
- Queueing
- `drain()` callback
- `cancel_queued()` support
- Introspection (`running`, `queued`, `max_children`)

It is intentionally small and policy-focused.

---

## Quick Start

```perl
use v5.36;
use Linux::Event;
use Linux::Event::Fork;

my $loop = Linux::Event->new;

# Optional: configure bounded parallelism
my $fork = $loop->fork_helper(max_children => 4);

$loop->fork(
  cmd => [ $^X, '-we', 'print "hello\n"; exit 0' ],

  on_stdout => sub ($child, $chunk) {
    print $chunk;
  },

  on_exit => sub ($child, $exit) {
    print "exit code: " . $exit->code . "\n";
    $loop->stop;
  },
);

$loop->run;
