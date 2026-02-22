# NAME

Acme::Parataxis - A terrible idea, honestly...

# SYNOPSIS

The classic way (as I write this, Acme::Parataxis is 5 days old and already has a 'classic' API...)

```perl
use v5.40;
use Acme::Parataxis;
$|++;

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
        say 'Result 1: ' . $f1->await( );
        say 'Result 2: ' . $f2->await( );
    }
);
```

Or do things the more modern way:

```perl
use v5.40;
use Acme::Parataxis qw[:all];
$|++;

async {
    say 'Main task started';

    # 'fiber' is a shorter alias for 'spawn'
    my $f1 = fiber {
        say '  Task 1: Sleeping...';
        await_sleep(1000);
        return 42;
    };

    my $f2 = fiber {
        say '  Task 2: Performing I/O...';
        # ...
        return 'I/O Done';
    };

    # 'await' works on fibers and futures
    say 'Result 1: ' . await($f1);
    say 'Result 2: ' . await($f2);
};
```

# DESCRIPTION

`Acme::Parataxis` implements a hybrid concurrency model for Perl, greatly inspired by the concurrency system for the
[Wren](https://wren.io/concurrency.html) programming language. It combines cooperative multitasking (fibers) with a
preemptive native thread pool.

Fibers are a mechanism for lightweight concurrency. They are similar to threads but are cooperatively scheduled. While
the OS may switch between threads at any time, a fiber only passes control when explicitly told to do so. This makes
concurrency deterministic and easier to reason about. You (probably) don't have to worry about random context switches
clobbering your data.

Fibers are incredibly lightweight. Each one has its own stack and context, but they don't use OS thread resources. You
can easily create thousands of them without stalling your system.

## A Warning

I had this idea while writing cookbook examples for Affix. I wondered if I could implement a hybrid concurrency model
for Perl from within FFI. This is that unpublished article made into a module. It's fragile. It's dangerous. It's my
attempt at combining cooperative multitasking (green threads or fibers or whatever they're called in the latest edit of
Wikipedia) with a preemptive native thread pool. It's Acme::Parataxis.

This module is experimental and resides in the `Acme::` namespace for a reason. It manually manipulates Perl's
internal stacks and C context. It is very dangerous. It's irresponsible, honestly, that I'm even putting this terrible
idea into the world. Don't use this. Forget you even saw it. Just **reading** this has probably made your projects more
prone to breaking. Reading the package name out loud might cause brain damage to yourself and those within earshot.

Close the browser and clear your history before this does further harm!

# MODERN API

While the classic object-oriented API is always available, `Acme::Parataxis` exports a set of functions (via the
`:all` tag) that provide a more modern, concise way to write concurrent code.

## `async { ... }`

A convenience wrapper around `run( )`. It starts the scheduler, executes the provided block as the main fiber, and
automatically calls `stop( )` when the block completes.

```
async {
    say "The scheduler is running!";
};
```

## `fiber { ... }`

An alias for `spawn( )`. It creates a new fiber and returns a [Future](#acme-parataxis-future-object-methods).

```perl
my $f = fiber {
    say "Hello from fiber!";
};
```

## `await( $thing )`

A generic await function. It accepts either an `Acme::Parataxis` fiber object or an `Acme::Parataxis::Future` and
suspends the current fiber until the target is ready.

```perl
my $result = await($f);
```

## `await_sleep( $ms )`

Suspends the current fiber for `$ms` milliseconds. This is a non-blocking operation that allows other fibers to run
while the current one is paused.

```
async {
    say "Taking a nap...";
    await_sleep(1000);
    say "I'm awake!";
};
```

## `await_read( $fh, $timeout = 5000 )`

Suspends the current fiber until the provided filehandle is ready for reading, or the timeout is reached.

```perl
async {
    await_read($socket);
    my $data = <$socket>;
    say "Received: $data";
};
```

## `await_write( $fh, $timeout = 5000 )`

Suspends the current fiber until the provided filehandle is ready for writing, or the timeout is reached.

```
async {
    await_write($socket);
    syswrite($socket, $message);
};
```

## `await_core_id( )`

Returns the ID of the CPU core currently executing the background task. This is a non-blocking operation that offloads
the request to the thread pool and suspends the fiber until the result is ready.

```perl
async {
    my $core = await_core_id( );
    say "Background task handled by CPU core: $core";
};
```

# CORE CONCEPTS

## Creating Fibers

All Perl code in this system runs within a fiber. When you start your script or call `Acme::Parataxis::run`, a "main"
fiber is active. You can create new fibers using `spawn` or by manually instantiating an `Acme::Parataxis` object:

```perl
my $fiber = Acme::Parataxis->new(code => sub {
    say "I'm in a fiber!";
});
```

Creating a fiber does not run it immediately. It simply prepares the context and waits to be invoked.

## Invoking Fibers

To run a fiber, you "call" it. This suspends the current fiber and executes the called one until it finishes or yields.

```
$fiber->call( );
```

When the called fiber finishes, control returns to the fiber that called it. It is an error to call a fiber that is
already done.

## Yielding

Yielding is the "secret sauce" of fibers.

A yielded fiber passes control back to its caller but remembers its exact state including all variables and the current
instruction pointer. The next time it's called, it resumes exactly where it left off.

```
Acme::Parataxis->yield( );
```

## Communication (Passing Values)

Fibers can pass data back and forth through `call` and `yield`:

- **Resuming with a value**: Arguments passed to `$fiber->call(@args)` are returned by the `yield( )` call that
suspended the fiber.
- **Yielding with a value**: Arguments passed to `Acme::Parataxis->yield(@args)` are returned to the caller by
the `call( )` that resumed the fiber.

## Full Coroutines

Fibers in Parataxis are "full coroutines." This means they can suspend from anywhere in the callstack. You can call
`yield( )` from deeply nested functions, and the entire fiber stack will be suspended until the fiber is resumed.

## Transferring Control

While `call( )` and `yield( )` manage a stack-like chain of execution, `transfer( )` provides an unstructured way to
switch between fibers. When you transfer to a fiber, the current one is suspended, and the target fiber resumes. Unlike
`call( )`, transferring does not establish a parent/child relationship. It's more like a `goto` for execution
contexts.

```
$other_fiber->transfer( );
```

## Fibers vs. Threads

In Parataxis, your **Perl code** always runs on a single OS thread. However, when you call an `await_*` function, the
current fiber is suspended, and the actual blocking work is performed on a **different** OS thread in a native pool.
Once the task completes, your fiber is automatically queued for resumption on the main thread.

# SCHEDULER FUNCTIONS

The following functions are the primary interface for the integrated cooperative scheduler.

## `run( $code )`

Starts the event loop and executes `$code` as the initial fiber. The loop continues to run as long as there are active
fibers or pending background tasks.

```perl
Acme::Parataxis::run(sub {
    say "The scheduler is running!";
});
```

## `spawn( $code )`

Creates a new fiber and adds it to the scheduler's queue. Returns a [Future](#acme-parataxis-future-object-methods)
that will eventually contain the fiber's return value.

```perl
my $future = Acme::Parataxis->spawn(sub {
    return "Hello from fiber #" . Acme::Parataxis->current_fid;
});
```

## `yield( @args )`

Pauses the current fiber and returns control to the scheduler. If `@args` are provided, they are passed to the context
that next resumes this fiber. Arguments can be of any Perl data type.

## `stop( )`

Tells the scheduler to exit the loop after the current iteration. Note that this does not immediately terminate other
fibers; it simply prevents the scheduler from starting new ones.

# THREAD POOL CONFIGURATION

`Acme::Parataxis` uses a native thread pool to handle blocking tasks. While it manages itself automatically, you can
tune its behavior using these functions.

## `set_max_threads( $count )`

Sets the maximum number of worker threads the pool is allowed to spawn. By default, this is set to the number of
logical CPU cores detected on your system (up to a hard limit of 64).

```
# Limit the pool to 4 threads
set_max_threads(4);
```

## `max_threads( )`

Returns the currently configured maximum thread pool size.

# BLOCKING & I/O FUNCTIONS

These functions **suspend** the current fiber and offload the actual blocking work to the native thread pool.

## `await_sleep( $ms )`

Suspends the fiber for `$ms` milliseconds. While the background thread sleeps, other fibers can continue to execute.

## `await_read( $fh, $timeout = 5000 )`

Suspends the fiber until the filehandle `$fh` is ready for reading, or the `$timeout` (in milliseconds) is reached.

```perl
my $status = Acme::Parataxis->await_read($socket);
if ($status > 0) {
    my $data = <$socket>;
}
```

## `await_write( $fh, $timeout = 5000 )`

Suspends the fiber until the filehandle `$fh` is ready for writing.

## `await_core_id( )`

Offloads a request to the thread pool and returns the ID of the CPU core that handled the job.

# MANUAL FIBER MANAGEMENT

Advanced users can manage context switching themselves without using the integrated scheduler.

## `new( code => $sub )`

Instantiates a new fiber. The `code` argument must be a subroutine reference.

```perl
my $fiber = Acme::Parataxis->new(code => sub {
    my $arg = Acme::Parataxis->yield("Initial data");
    return "Done with $arg";
});
```

## `call( @args )`

Explicitly switches control to the fiber and passes `@args`. Arguments can be scalars, hash/array references, or
objects. This establishes a parent/child relationship: when the fiber yields or completes, control returns to the
caller.

## `transfer( @args )`

A "symmetric" switch. Suspends the current context and moves directly to the target fiber. No parent/child relationship
is established. Like `call`, it supports passing arbitrary Perl data via `@args`.

# PREEMPTION

## `maybe_yield( )`

Increments an internal operation counter for the current fiber. If the counter reaches the threshold set by
`set_preempt_threshold`, the fiber automatically yields.

```perl
while (my $row = $sth->fetch) {
    process($row);
    Acme::Parataxis->maybe_yield( ); # Cooperatively prevent starvation
}
```

## `set_preempt_threshold( $val )`

Sets the number of `maybe_yield` increments before a forced yield occurs. Default is 0 (preemption disabled).

# Class Methods

## `tid( )`

Returns the unique OS Thread ID of the main interpreter thread.

## `current_fid( )`

Returns the unique numeric ID of the currently executing fiber, or -1 if called from the "root" (main) context.

## `root( )`

Returns a proxy object representing the initial execution context. This is useful for `transfer( )`ing control back to
the main thread from a symmetric coroutine.

# Acme::Parataxis OBJECT METHODS

## `fid( )`

Returns the unique numeric ID of the fiber object.

## `is_done( )`

Returns true if the fiber has finished execution (either by returning or dying). Once a fiber is done, its internal ID
is released and it can no longer be called.

# Acme::Parataxis::Future OBJECT METHODS

## `await( )`

Suspends the current fiber until the future is ready. Returns the result or **dies** if the task encountered an error.

## `is_ready( )`

Returns true if the task associated with the future has completed.

## `result( )`

Returns the task result immediately. Croaks if the future is not yet ready.

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
        my $start = time;
        while (1) {
            # Check for readiness NOW (0 timeout)
            return 1 if $self->SUPER::_do_timeout($type, 0);
            # Check for overall timeout
            my $elapsed = time - $start;
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

## Cooperative Parallelism

This example demonstrates how to perform multiple HTTP requests concurrently on a single interpretation thread.

```perl
use Acme::Parataxis;
# ... (See My::HTTP implementation in INTEGRATING SYNCHRONOUS MODULES) ...

Acme::Parataxis::run(sub {
    my $http = My::HTTP->new(verify_SSL => 0);
    my @urls = qw[http://example.com http://perl.org];

    # Spawn tasks for each URL
    my @futures = map {
        my $url = $_;
        Acme::Parataxis->spawn(sub { $http->get($url)->{status} })
    } @urls;

    # Collect results as they become ready
    say "Status for $urls[$_]: " . $futures[$_]->await( ) for 0..$#urls;
});
```

## Symmetric Producer/Consumer

A low-level example of Passing control sideways between fibers.

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
    my $item = Acme::Parataxis->yield( ); # Initial wait
    while (1) {
        last if $item eq 'DONE';
        say "Consumer: Eating $item";
        $item = $p->transfer( );
    }
});

$c->call( ); # Prime consumer
$p->call( ); # Start producer
```

# BEST PRACTICES & GOTCHAS

- **Avoid blocking syscalls:** Never call blocking `sleep( )` or `sysread( )` on the main interpretation thread.
Always use the `await_*` equivalents to offload work to the pool.
- **Thread Safety:** While Perl code remains single-threaded, background tasks run on separate OS threads. Shared
C-level data (if accessed via FFI) must be mutex-protected.
- **Stack Limits:** Each fiber is allocated a 512KB stack by default. This is more than sufficient for most
Perl code and allows for high concurrency with a small memory footprint. Extremely deep recursion or massive regex
backtracking might still hit limits.
- **Efficiency:** The native thread pool is initialized dynamically upon the first asynchronous request. It
starts with a small "seed" pool and grows on demand up to the configured limit. Worker threads use condition
variables to sleep efficiently when idle, ensuring near-zero CPU usage when no background tasks are pending.
- **Reference Cycles:** Be careful when passing fiber objects into their own closures, as this can create
memory leaks.

# GORY TECHNICAL DETAILS

## Architectural Inspiration

The concurrency model in Parataxis is heavily inspired by the **Wren** programming language, specifically its treatment
of fibers as the primary unit of execution and its deterministic cooperative scheduling.

## Stack Virtualization

On Unix-like systems, we use `ucontext.h` to manage stack and register state. On Windows, we leverage the native
`Fiber API`. In both cases, we perform heart surgery on the Perl interpreter by manually teleporting its internal
global pointers (the `PL_*` variables) between contexts.

## Shared CVs and Pad Virtualization

A significant challenge in Perl green threads is the shared nature of PadLists and the global `CvDEPTH` counter. In
debug builds of Perl, calling a shared subroutine from multiple fibers can trigger internal assertions (like
`AvFILLp(av) == -1`). Parataxis includes a specialized workaround that surgically cleans the next landing pad before
every context switch to satisfy these assertions without clobbering active lexical state.

## `eval` vs. `try/catch`

While `feature 'try'` is available in modern Perl, manually teleporting interpreter state can occasionally confuse the
compiler's expectations for stack unwinding. Standard `eval { ... }` remains the most predictable way to handle
exceptions within fibers.

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
