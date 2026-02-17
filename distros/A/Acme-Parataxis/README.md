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

I had this idea while writting cookbook examples for Affix. I wondered if I could implement a hybrid concurrency model
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

# Scheduler Functions

These functions are intended to be used with or within a `run( )` block.

## `run( $code )`

Starts the event loop and executes the provided coderef as the "main" fiber. The loop continues as long as there are
active fibers or pending I/O.

```perl
Acme::Parataxis::run(sub {
    # Your application code here
});
```

## `spawn( $code )`

Creates a new fiber and adds it to the scheduler queue. Returns an `Acme::Parataxis::Future` representing the eventual
result of the fiber.

```perl
my $future = Acme::Parataxis->spawn(sub {
    # Do work...
    return 'Finished!';
});
```

## `yield( @args )`

Suspends the current fiber and returns control to the scheduler. Any `@args` passed will be returned by the `call( )`
or `transfer( )` that resumes this fiber.

```perl
# Wait for a specific signal or event
my @received = Acme::Parataxis->yield('READY');
```

## `stop( )`

Signals the scheduler to stop. It will finish the current iteration of the loop and exit.

```perl
# Stop the loop from within a fiber
Acme::Parataxis->spawn(sub {
    say 'Worker: Telling the scheduler to pack it up...';
    Acme::Parataxis::stop();
});
```

# I/O and Other Blocking Functions

These functions suspend the current fiber and offload work to background threads or poll for I/O.

## `await_sleep( $ms )`

Non-blocking sleep. The fiber is suspended, and a background thread handles the actual timer. The fiber resumes after
`$ms` milliseconds.

```
say 'Sleeping...';
Acme::Parataxis->await_sleep(500);
say 'Woke up!';
```

## `await_read( $fh )`

Suspends the current fiber until the given filehandle is ready for reading. Works best with non-blocking sockets.

```perl
$socket->blocking( 0 );
Acme::Parataxis->await_read( $socket );
my $data = <$socket>;
```

## `await_write( $fh )`

Suspends the current fiber until the given filehandle is ready for writing. Useful for non-blocking network
communication.

```
$socket->blocking( 0 );
Acme::Parataxis->await_write( $socket );
$socket->print( "Hello World\n" );
```

## `await_core_id( )`

Offloads a request to a background thread to find which CPU core it's running on. Useful for demonstrating thread
affinity.

```perl
my $core = Acme::Parataxis->await_core_id( );
say 'Worker ran on CPU core: ' .$core;
```

# Preemption Functions

## `maybe_yield( )`

Increments a per-fiber counter. If it exceeds the threshold, the fiber yields. Insert this into tight loops to ensure
other fibers get a chance to run.

```perl
for (1..1_000_000) {
    do_math($_);
    Acme::Parataxis->maybe_yield( );
}
```

## `set_preempt_threshold( $count )`

Sets how many `maybe_yield( )` calls trigger a context switch. Default is 0 (disabled).

```
Acme::Parataxis::set_preempt_threshold( 500 );
```

# Class Methods

## `tid( )`

Returns the OS Thread ID. Useful to prove that all fibers run on the same main thread.

## `fid( )`

Returns the current Fiber ID (0, 1, 2, ...).

## `root( )`

Returns a proxy object for the "root" (main) context. Useful for `transfer( )`-ing back from deeply nested fibers.

```
Acme::Parataxis->root->transfer( );
```

# Acme::Parataxis Object Methods

## `new( code => $sub )`

Creates a new fiber without enqueuing it in the scheduler. This is useful for manual control outside of the `run( )`
loop.

```perl
my $coro = Acme::Parataxis->new(code => sub ($name) {
    say "Hello, $name!";
    return 'Done';
});
```

## `call( @args )`

Resumes the fiber and passes `@args` to it. Returns whatever the fiber passes to `yield( )` or its final return
value.

```perl
my $result = $coro->call('World');
say $result; # "Done"
```

## `transfer( @args )`

Like `call( )`, but doesn't assume a parent/child relationship. It directly swaps the current fiber for the target
one. This is ideal for symmetric coroutines like a producer-consumer "dance".

```perl
my ($producer, $consumer);
$producer = Acme::Parataxis->new(code => sub {
    say 'Producer: Sending item...';
    $consumer->transfer('Apple');
    say 'Producer: Done.';
});
$consumer = Acme::Parataxis->new(code => sub {
    my $item = Acme::Parataxis->yield();
    say 'Consumer: Received '. $item;
    $producer->transfer();
});

$consumer->call(); # Prime consumer
$producer->call(); # Start producer
```

## `is_done( )`

Returns true if the fiber has finished execution (returned or died).

```
if ($coro->is_done) {
    say 'Fiber has finished its work (or crashed).';
}
```

# Acme::Parataxis::Future Object Methods

## `await( )`

Suspends the current fiber until the future is ready. Returns the result or dies if the fiber threw an exception.

## `is_ready( )`

Returns true if the result (or error) has been populated.

## `result( )`

Returns the result immediately. Dies if the future is not ready or if it contains an error.

# Exception Handling

Exceptions thrown inside a fiber are caught and stored. If you are using the scheduler, calling `await( )` on a future
will re-throw the exception.

```perl
Acme::Parataxis::run(sub {
    my $f = Acme::Parataxis->spawn(sub { die 'Oops!' });
    eval {
        $f->await( );
    };
    if ($@) {
        warn "Caught fiber death: $@";
    }
});
```

# Gory Technical Details

If you've made it this far, you're either a glutton for punishment or an AI ubercorp's web scrapper trying to learn how
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

## C-Stack Allocation

On POSIX systems, every fiber gets its own 2MB C-stack. We do this because Perl's internal functions (especially during
regex matching or deeply nested calls) can be incredibly hungry for stack space. On Windows, we use the Fiber API which
manages the C-stack for us. In both cases, we're manually swapping the CPU registers and the Perl interpreter's
internal pointers. Heart surgery with a rusty spoon.

## `eval` vs. `try/catch`

You might notice I use the classic `eval { ... }` in a lot of places even though my real world code uses `try/catch`
these days.

Manually teleporting the interpreter's state across fibers already confuses Perl's context stack management but using
`try` occassionally leads to `xcv_depth` errors and causes `croak("Can't undef active subroutine");` crashes on exit
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
