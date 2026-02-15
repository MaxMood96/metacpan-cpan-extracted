[![CI](https://github.com/haxmeister/perl-linux-event/actions/workflows/ci.yml/badge.svg)](https://github.com/haxmeister/perl-linux-event/actions/workflows/ci.yml)

Linux::Event **0.006** is the first stable API release. It provides a minimal, Linux-native event loop built on epoll, timerfd, signalfd, eventfd, and pidfd.

## Additional Linux primitives

Beyond timers and I/O watchers, Linux::Event can integrate:

- **Signals** via `signalfd` (`$loop->signal(...)`)
- **Wakeups** via `eventfd` (`$loop->waker`, then watch `$waker->fh`)
- **Process exit** via `pidfd` (`$loop->pid($pid, ...)` for child exit notifications)

See the `examples/` directory for working, minimal scripts.

# Linux::Event

A Linux-focused, backend-swappable event loop framework.

**Status:** EXPERIMENTAL / WORK IN PROGRESS\
**Current Version:** 0.006 (stable)

------------------------------------------------------------------------

## Overview

`Linux::Event` provides a clean, layered architecture:

User Code\
↓\
Linux::Event::Watcher\
↓\
Linux::Event::Loop (policy layer)\
├── Linux::Event::Clock\
├── Linux::Event::Timer\
├── Linux::Event::Scheduler\
└── Backend (mechanism layer)

### Design Goals

-   Clear, minimal public API
-   No epoll mask exposure
-   Mutable watcher handles
-   Backend-swappable architecture
-   Nanosecond precision internally
-   Seconds-based public timer API
-   Foundation for future socket/server abstractions

------------------------------------------------------------------------

## Installation

Development install:

    perl Makefile.PL
    make
    make test
    make install

Requires:

-   Linux
-   Linux::Epoll
-   Linux::Event::Clock \>= 0.011
-   Linux::Event::Timer \>= 0.010

------------------------------------------------------------------------

# Basic Usage

    use v5.36;
    use Linux::Event;

    my $loop = Linux::Event->new( backend => 'epoll' );

    $loop->after(0.250, sub ($loop) {
        say "250ms elapsed";
        $loop->stop;
    });

    $loop->run;

Timers use seconds (float allowed). Internally everything is stored in
nanoseconds.

------------------------------------------------------------------------

# Watching Filehandles

Create a watcher with `watch(...)`.

Interest is inferred from installed handlers.

    my $conn = My::Conn->new(...);

    my $w = $loop->watch(
        $fh,
        read  => \&My::Conn::on_read,
        write => \&My::Conn::on_write,
        data  => $conn,
    );

Handlers are invoked as:

    sub on_read ($loop, $fh, $watcher) {
        my $conn = $watcher->data;
        ...
    }

------------------------------------------------------------------------

## Watcher Object

`watch()` returns a `Linux::Event::Watcher`.

It is a mutable handle.

### Common Methods

    $w->enable_write;
    $w->disable_write;

    $w->on_read(sub { ... });
    $w->on_write(sub { ... });

    $w->data($obj);
    my $obj = $w->data;

    $w->cancel;

------------------------------------------------------------------------

## Edge Triggered Mode

Advanced users may enable edge-triggered behavior:

    my $w = $loop->watch(
        $fh,
        read => \&on_read,
        edge_triggered => 1,
    );

Important: In edge-triggered mode, read handlers must drain the
filehandle until EAGAIN.

Level-triggered mode (default) is safer and recommended unless you
understand epoll semantics.

------------------------------------------------------------------------

# Timer API

Timers are simple and seconds-based.

    my $id = $loop->after(0.100, sub ($loop) {
        ...
    });

Cancel:

    $loop->cancel($id);

Absolute deadline (monotonic timebase):

    $loop->at($deadline_seconds, sub ($loop) { ... });

------------------------------------------------------------------------

# Architecture

### Loop (Policy)

-   Owns scheduler
-   Owns timer rearm logic
-   Dispatches expired timers
-   Manages watcher state

### Backend (Mechanism)

-   Waits for readiness
-   Converts epoll events to internal mask
-   Dispatches to loop

Currently implemented:

-   Linux::Event::Backend::Epoll

Future:

-   Backend::Uring
-   Hybrid backends
-   Possibly select fallback

------------------------------------------------------------------------

# Development Status

This is a developer release.

The architecture is stabilizing, but APIs may change before 0.01.

Not yet recommended for production use.

------------------------------------------------------------------------

# Repository

https://github.com/haxmeister/perl-linux-event
