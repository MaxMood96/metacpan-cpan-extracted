#!perl
use strict;
use warnings;
use Test::More;
use Hyperman::Future;

# The protocol methods are always present; the async sub syntax that uses
# them is not, so the file is split in two. Everything that can be tested
# by calling the methods directly runs everywhere.

sub F { Hyperman::Future->new }

# ---- the protocol is complete --------------------------------------------
for my $m (qw(
    AWAIT_NEW_DONE AWAIT_NEW_FAIL AWAIT_CLONE
    AWAIT_DONE AWAIT_FAIL AWAIT_GET AWAIT_WAIT
    AWAIT_IS_READY AWAIT_IS_CANCELLED
    AWAIT_ON_READY AWAIT_ON_CANCEL AWAIT_CHAIN_CANCEL
)) {
    ok(Hyperman::Future->can($m), "$m is implemented");
}

# ---- constructors --------------------------------------------------------
{
    my $f = Hyperman::Future->AWAIT_NEW_DONE('result');
    isa_ok($f, 'Hyperman::Future', 'AWAIT_NEW_DONE');
    ok($f->AWAIT_IS_READY, 'AWAIT_NEW_DONE is ready');
    ok(!$f->AWAIT_IS_CANCELLED, 'AWAIT_NEW_DONE is not cancelled');
    is_deeply([$f->AWAIT_GET], ['result'], 'AWAIT_GET in list context');
    is(scalar $f->AWAIT_GET, 'result', 'AWAIT_GET in scalar context');
}
{
    my $f = Hyperman::Future->AWAIT_NEW_FAIL('Oopsie');
    ok($f->AWAIT_IS_READY, 'AWAIT_NEW_FAIL is ready');
    my $line = __LINE__ + 1;
    ok(!eval { $f->AWAIT_GET; 1 }, 'AWAIT_GET on a failure dies');
    is($@, "Oopsie at " . __FILE__ . " line $line.\n",
       'the exception is reported at the caller');
}

# ---- clone ---------------------------------------------------------------
{
    my $f = F();
    my $g = $f->AWAIT_CLONE;
    isa_ok($g, 'Hyperman::Future', 'AWAIT_CLONE');
    ok(!$g->AWAIT_IS_READY, 'the clone is pending');
    ok(!$f->AWAIT_IS_READY, 'the original is untouched');
    isnt("$f", "$g", 'the clone is a different future');
}

# ---- AWAIT_GET reads, AWAIT_WAIT waits -----------------------------------
{
    # Outside a loop, waiting on a pending future is an error. AWAIT_GET must
    # not wait, so it reports unreadiness rather than the loop's complaint.
    my $f = F();
    ok(!eval { $f->AWAIT_GET; 1 }, 'AWAIT_GET on a pending future dies');
    like($@, qr/not ready/, 'AWAIT_GET did not try to run a loop');
    ok(!eval { $f->AWAIT_WAIT; 1 }, 'AWAIT_WAIT on a pending future dies');
    like($@, qr/without an event loop/, 'AWAIT_WAIT tried to wait');
}

# ---- settling ------------------------------------------------------------
{
    my $f = F();
    $f->AWAIT_DONE('a', 'b');
    is_deeply([$f->AWAIT_GET], ['a','b'], 'AWAIT_DONE sets the result');
}
{
    my $f = F();
    $f->AWAIT_FAIL("late\n");
    ok(!eval { $f->AWAIT_GET; 1 }, 'AWAIT_FAIL sets the failure');
    is($@, "late\n", 'the failure message is preserved verbatim');
}

# ---- on_ready ------------------------------------------------------------
{
    my $f = F();
    my $fired = 0;
    $f->AWAIT_ON_READY(sub { $fired++ });
    is($fired, 0, 'AWAIT_ON_READY has not fired yet');
    $f->done;
    is($fired, 1, 'AWAIT_ON_READY fired on completion');
}

# ---- on_cancel: code references ------------------------------------------
{
    my $f = F();
    my $fired = 0;
    $f->on_cancel(sub { $fired++ });
    is($fired, 0, 'on_cancel has not fired yet');
    $f->cancel;
    is($fired, 1, 'on_cancel fired on cancellation');
}
{
    my $f = F();
    my $fired = 0;
    $f->on_cancel(sub { $fired++ });
    $f->done;
    is($fired, 0, 'on_cancel does not fire on a normal completion');
}
{
    my $f = F();
    $f->cancel;
    my $fired = 0;
    $f->on_cancel(sub { $fired++ });
    is($fired, 1, 'on_cancel on an already-cancelled future fires at once');
}
{
    my $f = F()->done;
    my $fired = 0;
    $f->on_cancel(sub { $fired++ });
    is($fired, 0, 'on_cancel on a completed future is dropped');
}
{
    my $f = F();
    my @order;
    $f->on_cancel(sub { push @order, 1 });
    $f->on_cancel(sub { push @order, 2 });
    $f->cancel;
    is_deeply(\@order, [1,2], 'on_cancel callbacks run in registration order');
}

# ---- chain cancel: futures -----------------------------------------------
{
    my ($f1, $f2) = (F(), F());
    $f1->AWAIT_CHAIN_CANCEL($f2);
    ok(!$f2->is_cancelled, 'the chained future is not cancelled yet');
    $f1->cancel;
    ok($f2->is_cancelled, 'cancelling f1 cancels f2');
}
{
    my ($f1, $f2) = (F(), F());
    $f1->AWAIT_CHAIN_CANCEL($f2);
    $f2->cancel;
    ok(!$f1->is_cancelled, 'there is no link back from f2 to f1');
}
{
    my ($f1, $f2) = (F(), F());
    $f1->AWAIT_CHAIN_CANCEL($f2);
    $f1->done;
    ok(!$f2->is_cancelled, 'completing f1 leaves f2 alone');
}

# ---- async sub integration -----------------------------------------------
SKIP: {
    skip 'Future::AsyncAwait required for the async sub tests', 9
        unless eval { require Future::AsyncAwait; 1 };

    # Which version, in the output, because a smoker report does not say.
    # Future::AsyncAwait is not a prerequisite of this distribution - the
    # tests use it if it is there - so it never appears in a report's
    # PREREQUISITES table, and a failure that depends on its version has
    # nothing in the report to pin it to.
    diag("Future::AsyncAwait $Future::AsyncAwait::VERSION");

    # Cancellation is the one behaviour here that the async sub machinery
    # drives rather than this class: F::AA calls
    # $outer->AWAIT_CHAIN_CANCEL($inner) when it suspends, and that call is
    # what a later $outer->cancel rides into $inner. This class implements
    # both that method and the older AWAIT_ON_CANCEL spelling, and t/39
    # proves the whole Awaitable API against F::AA's own conformance suite -
    # but if F::AA never makes the call, nothing this class does can make
    # the inner future cancel.
    #
    # F::AA renamed AWAIT_ON_CANCEL to AWAIT_CHAIN_CANCEL in 0.45 and its
    # 0.56 Changes says "Actually use AWAIT_ON_CANCEL properly (RT137723)",
    # so below 0.56 the call is not something to rely on. A 5.22.1 smoker
    # FAILed exactly this one assertion out of 539 while t/39 passed.
    my $chains = eval { Future::AsyncAwait->VERSION('0.56'); 1 } ? 1 : 0;

    # async sub is syntax, so the whole block has to be compiled late.
    my $ok = eval <<'ASYNC';
        use Future::AsyncAwait future_class => 'Hyperman::Future';

        {   # a future of this class can be awaited, and the async sub
            # returns one of the same class
            my $inner = Hyperman::Future->new;
            async sub t_await { my $v = await $inner; return "got:$v" }
            my $outer = t_await();
            isa_ok($outer, 'Hyperman::Future', 'the async sub result');
            ok(!$outer->is_ready, 'the async sub is suspended on the await');
            $inner->done(42);
            ok($outer->is_ready, 'resolving the awaited future resumes it');
            is(scalar $outer->get, 'got:42', 'the awaited value reached the body');
        }

        {   # a failure crosses the await
            my $inner = Hyperman::Future->new;
            async sub t_fail { await $inner; return 1 }
            my $outer = t_fail();
            $inner->fail("kaboom\n");
            ok($outer->is_failed, 'the async sub failed');
            is($outer->failure, "kaboom\n", 'the failure crossed the await');
        }

        {   # cancelling the outer future cancels what it is awaiting
            SKIP: {
                skip 'Future::AsyncAwait 0.56+ chains cancellation into the '
                   . 'awaited future', 1 unless $chains;
                my $inner = Hyperman::Future->new;
                async sub t_cancel { await $inner; return 1 }
                my $outer = t_cancel();
                $outer->cancel;
                ok($inner->is_cancelled,
                    'cancelling the caller cancels the awaited future');
            }
        }

        {   # the shape a PAGI application produces: two sequential sends,
            # each resolving immediately
            my $send = sub { my $f = Hyperman::Future->new; $f->done; $f };
            async sub t_pagi { my $s = shift; await $s->(); await $s->(); return }
            my $outer = t_pagi($send);
            ok($outer->is_ready, 'two sequential awaits complete');
            ok(!$outer->is_failed, 'two sequential awaits did not fail');
        }
        1;
ASYNC
    diag("async sub block failed to compile: $@") unless $ok;
}

done_testing;
