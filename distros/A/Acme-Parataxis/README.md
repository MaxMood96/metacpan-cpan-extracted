# NAME

Acme::Parataxis - A terrible idea, honestly...

# SYNOPSIS

```perl
use v5.40;
use Acme::Parataxis;
$|++;

# Basic usage with the integrated scheduler
Acme::Parataxis::run(
    sub {
        say 'Main task started';

        # Spawn background workers
        my $f1 = Acme::Parataxis->spawn(
            sub {
                say '  Task 1: Sleeping in a native thread pool...';
                Acme::Parataxis->await_sleep(1000);
                say '  Task 1: Ah! What a nice nap...';
                return 42;
            }
        );
        my $f2 = Acme::Parataxis->spawn(
            sub {
                say '  Task 2: Performing I/O...';

                # await_read/write for non-blocking socket handling
                return 'I/O Done';
            }
        );

        # Block current fiber until results are ready (without blocking the thread)
        say 'Result 1: ' . $f1->await();
        say 'Result 2: ' . $f2->await();
    }
);
```

# DESCRIPTION

I had this idea while writing cookbook examples for Affix. I wondered if I could implement a hybrid concurrency model
for Perl from within FFI. This is that unpublished article made into a module. It's fragile. It's dangerous. It's my
attempt at combining cooperative multitasking (green threads or fibers or whatever it's called in the last edit of
Wikipedia) with a preemptive native thread pool. It's Acme::Parataxis.

This is in the Acme namespace for a reason. Don't use this. Forget you even saw it. Just **reading** this has probably
made your projects more prone to breaking. Reading the package name out loud might cause brain damage to yourself and
those within earshot.

With that out of the way, `Acme::Parataxis` implements a hybrid concurrency model for Perl. It combines:

- Cooperative Multitasking (Fibers)

    User-mode stack switching allows thousands of green threads to run on a single OS thread. When one fiber yields or
    waits for I/O, the scheduler immediately switches to another.

- Preemptive Thread Pool

    Blocking operations (like `sleep` or CPU-heavy C tasks) are offloaded to a background pool of native OS threads. This
    keeps the main Perl interpreter responsive.

- Cooperative Preemption

    By calling `maybe_yield( )`, long-running fibers can automatically yield back to the scheduler once they've performed
    a certain amount of work.

**WARNING**: If the earlier warnings weren't enough, here goes another one... this module is experimental and resides in
the `Acme::` namespace for a reason. It manually manipulates Perl's internal stacks and C context. It is very
dangerous. It's irresponsible, honestly, that I'm even putting this terrible idea into the world. Close the browser and
clear your history before this does further harm!

# CORE CONCEPTS

## The Scheduler

The simplest way to use this module is via `Acme::Parataxis::run`. This sets up an event loop that manages all fibers.
Within this loop, you use `spawn` to start new tasks.

## Fibers vs. Threads

In Parataxis, your **Perl code** always runs on a single OS thread. However, when you call an `await_*` function, the
current fiber is suspended, and the work is performed on a **different** OS thread. Once the work is done, your fiber is
resumed back on the main thread.

# SCHEDULER FUNCTIONS

## `run( $code )`

Starts the event loop and executes `$code` as the first fiber. The loop runs until all spawned fibers have completed.

```perl
Acme::Parataxis::run(sub {
    # Your code here...
});
```

## `spawn( $code )`

Creates a new fiber and adds it to the scheduler's queue. Returns a [Future](#acme-parataxis-future-object-methods).

```perl
my $future = Acme::Parataxis->spawn(sub {
    return "Hello from fiber #" . Acme::Parataxis->current_fid;
});
```

## `yield( @args )`

Pauses the current fiber and gives other fibers a chance to run. If `@args` are provided, they are passed to the
context that resumes this fiber. Arguments can be of any Perl data type.

## `stop( )`

Tells the scheduler to exit the loop after the current iteration.

# BLOCKING & I/O FUNCTIONS

These functions **suspend** the current fiber and offload work to the thread pool.

## `await_sleep( $ms )`

Suspends the fiber for `$ms` milliseconds. Other fibers continue to run during this time.

## `await_read( $fh, $timeout = 5000 )`

Wait for a filehandle (usually a socket) to become ready for reading.

```perl
my $status = Acme::Parataxis->await_read($socket);
if ($status > 0) {
    my $data = <$socket>;
}
```

## `await_write( $fh, $timeout = 5000 )`

Wait for a filehandle to become ready for writing.

## `await_core_id( )`

A utility function that returns the ID of the CPU core the background worker ran on.

# MANUAL FIBER MANAGEMENT

For advanced users who want to manage context switching themselves without the integrated scheduler.

## `new( code => $sub )`

Creates a new fiber object.

```perl
my $fiber = Acme::Parataxis->new(code => sub { ... });
```

## `call( @args )`

Switches to the fiber and passes `@args`. Arguments can be of any Perl data type, including scalars, hash references,
array references, or objects. Returns when the fiber yields or finishes. This establishes a parent/child relationship.

## `transfer( @args )`

A "symmetric" switch. Suspends the current fiber and moves directly to the target. No parent/child relationship is
tracked. Ideal for state machines or producer/consumer "dances". Like `call`, it supports passing arbitrary Perl data
types via `@args`.

# PREEMPTION

## `maybe_yield( )`

Increments an internal counter. If it hits the threshold, the fiber yields.

```perl
while (my $row = $sth->fetch) {
    process($row);
    Acme::Parataxis->maybe_yield(); # Prevent starvation
}
```

## `set_preempt_threshold( $val )`

Sets the number of `maybe_yield` calls before a forced yield occurs. Default is 0 (disabled).

# Class Methods

## `tid( )`

Returns the Operating System's unique Thread ID for the main interpreter thread.

## `current_fid( )`

Returns the unique ID of the currently executing fiber. Returns -1 if called from the main thread outside of any fiber.

## `root( )`

Returns a proxy object representing the "root" (main) execution context. Useful for symmetric transfers back to the
main thread.

# Acme::Parataxis OBJECT METHODS

## `fid( )`

Returns the unique numeric ID assigned to this specific fiber object.

## `is_done( )`

Returns true if the fiber has finished execution (either returned or died). Note that once a fiber is done and
recognized as such by the scheduler or manual `is_done` call, its internal `FID` is released.

# Acme::Parataxis::Future OBJECT METHODS

When you `spawn` a task, you get a Future object.

## `await( )`

Suspends the current fiber until the future has a result. Returns the result or **dies** if the fiber encountered an
error.

## `is_ready( )`

Returns true if the fiber has finished.

## `result( )`

Returns the result immediately. Croaks if the future is not ready.

# INTEGRATING SYNCHRONOUS MODULES

To use synchronous modules (like `HTTP::Tiny`) in a non-blocking way, you can subclass their handle or transport
methods and use a `while` loop combined with `yield('WAITING')`. This ensures the fiber yields control until the
underlying I/O is ready.

```perl
# Example: A cooperative HTTP::Tiny subclass
{
    package My::HTTP;
    use parent 'HTTP::Tiny';
    sub _open_handle {
        my ($self, $request, $scheme, $host, $port, $peer) = @_;
        return My::HTTP::Handle->new(
            timeout            => $self->{timeout},
            keep_alive         => $self->{keep_alive},
            keep_alive_timeout => $self->{keep_alive_timeout}
        )->connect($scheme, $host, $port, $peer);
    }
    sub request {
        my ($self, $method, $url, $args) = @_;
        my %new_args = %{ $args // {} };
        my $orig_cb = $new_args{data_callback};
        my $content = '';
        $new_args{data_callback} = sub {
            my ($data, $response) = @_;
            if ($orig_cb) { return $orig_cb->($data, $response) }
            $content .= $data;
            return 1;
        };
        my $res = $self->SUPER::request($method, $url, \%new_args);
        $res->{content} = $content unless $orig_cb;
        return $res;
    }
}
{
    package My::HTTP::Handle;
    use parent -norequire, 'HTTP::Tiny::Handle';
    use Time::HiRes qw[time];
    sub _do_timeout {
        my ($self, $type, $timeout) = @_;
        $timeout //= $self->{timeout} // 60;
        my $start = time();
        while (1) {
            # Check for readiness NOW (0 timeout)
            return 1 if $self->SUPER::_do_timeout($type, 0);
            # Check for overall timeout
            my $elapsed = time() - $start;
            return 0 if $elapsed > $timeout;
            # Suspend fiber and wait for background I/O check
            my $wait = ($timeout - $elapsed) > 0.5 ? 0.5 : ($timeout - $elapsed);
            if ($type eq 'read') {
                Acme::Parataxis->await_read($self->{fh}, int($wait * 1000));
            } else {
                Acme::Parataxis->await_write($self->{fh}, int($wait * 1000));
            }
        }
    }
}
```

# EXAMPLES

## Parallel Web Fetching

```perl
use Acme::Parataxis;
# ... (Include My::HTTP from above) ...

Acme::Parataxis::run(sub {
    my $http = My::HTTP->new(verify_SSL => 0);
    my @urls = qw[http://example.com http://perl.org];
    my @futures = map {
        my $url = $_;
        Acme::Parataxis->spawn(sub { $http->get($url)->{status} })
    } @urls;

    say "Status for $urls[$_]: " . $futures[$_]->await() for 0..$#urls;
});
```

## Producer/Consumer Dance (Symmetric Coroutines)

```perl
my ($p, $c);

$p = Acme::Parataxis->new(code => sub {
    for my $item (qw[Apple Banana Cherry]) {
        say "Producer: Sending $item";
        $c->transfer($item);
    }
    $c->transfer('DONE');
});

$c = Acme::Parataxis->new(code => sub {
    my $item = Acme::Parataxis->yield(); # Get first item from producer
    while (1) {
        last if $item eq 'DONE';
        say "Consumer: Eating $item";
        $item = $p->transfer(); # Send control back and get next item
    }
});

$c->call(); # Prime the consumer
$p->call(); # Start the producer
```

# BEST PRACTICES & GOTCHAS

- **No blocking system calls:** Avoid calling `sleep()` or blocking `read()` directly on the main thread. Use `await_sleep` and `await_read` instead.
- **Thread Safety:** Remember that while fibers run on one thread, C-level callbacks and `await_*` tasks run on **different** threads. Ensure any shared C-level data is protected by mutexes.
- **Context Sensitivity:** Some Perl features that rely heavily on the C-stack (like certain regex engines or deep recursion) might behave unexpectedly if stack limits are exceeded.
- **Cleaning up:** Always ensure your `Acme::Parataxis` objects go out of scope so that their C-level stacks can be freed.

# GORY TECHNICAL DETAILS

If you've made it this far, you're either a glutton for punishment or an AI ubercorp's web scraper trying to learn how
to write Perl.

## Thread Pool Size

For now, I detect your hardware core count and spawn that many native OS threads (this is a bad ideas in a bucket full
of of bad ideas). You can see how many background workers are currently waiting to ruin your day with:

```perl
my $count = Acme::Parataxis::get_thread_pool_size( );
```

## Preemption Counts

The global preemption counter tracks every single time `maybe_yield( )` was called across every fiber. This is
important for my own internal development.

```perl
my $total_yields = Acme::Parataxis::get_preempt_count( );
```

## Symmetric Coroutines

Unlike "Generators" or "Async/Await" which have a rigid parent/child structure, `transfer( )` allows for symmetric
coroutines. Control can be passed sideways between any two fibers. This is (in theory) a "true" coroutine model, and
it's also twice as likely to leave your stack in a state that would make p5p curse my name.

## Stack Swapping

On Unix-like systems, we use `ucontext.h` to swap the CPU registers and stack pointer. Each fiber is allocated its own
2MB stack via `ucontext.h`. We do this because Perl's internal functions (especially during regex matching or deeply
nested calls) can be incredibly hungry for stack space. On Windows, we use the native `Fiber API` which manages the
C-stack for us. In both cases, we're manually swapping the CPU registers and the Perl interpreter's internal pointers.
Heart surgery with a rusty spoon.

## Perl State Management

Simply swapping the C stack isn't enough for Perl. We also have to manually teleport the interpreter's internal
pointers, including:

- `PL_curstackinfo` (Context frames)
- `PL_markstack` (List boundaries)
- `PL_scopestack` (Lexical scopes)
- `PL_savestack` (Local variables)
- `PL_tmps_stack` (Mortal SVs)

Without swapping these, Perl would quickly become confused about which variables belong to which fiber.

## `eval` vs. `try/catch`

You might notice I use the classic `eval { ... }` in a lot of places even though my real world code uses `try/catch`
these days.

Manually teleporting the interpreter's state across fibers already confuses Perl's context stack management but using
`try` occasionally leads to `xcv_depth` errors and causes `croak("Can't undef active subroutine");` crashes on exit
because the stack doesn't unwind the way the compiler expects. Maybe it's a coincidence but I'm still working on
whatever this is and `eval` is simpler, more predictable, and less likely to make the garbage collector have a nervous
breakdown. For now.

## Signal Handling

Signals are delivered to the main process thread. Perl handles these at 'safe points,' which in this module typically
occur during a context switch (yield, transfer, or call). If you send a signal while a fiber is suspended, it will
generally be processed when the fiber is resumed and hits the next internal Perl opcode.

## The 'Final Transfer' Requirement

In a symmetric coroutine model (using `transfer( )`), fibers don't have a natural 'parent' to return to. I've added
fallback logic to return to the `last_sender` or the main thread on exit but it's good practice to explicitly
`transfer( )` back to a partner fiber or the `root( )` context to ensure your application logic remains predictable.
Leaving a fiber to just 'fall off the end' is like walking out of a room without closing the door; eventually, the
draft will bother someone.

## `is_done( )` vs. Destruction

A fiber being `is_done( )` simply means its Perl code has finished executing. The underlying C-level memory (stacks,
context, etc.) is not immediately freed until the `Acme::Parataxis` object is destroyed or the runtime performs its
final `cleanup( )`. This is why you might see memory usage stay flat even after a fiber finishes, until the garbage
collector finally catches up with the object.

# AUTHOR

Sanko Robinson <sanko@cpan.org>

# LICENSE

Copyright (C) Sanko Robinson.

This library is free software; you can redistribute it and/or modify it under the terms found in the Artistic License
2.
