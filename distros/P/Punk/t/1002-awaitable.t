#!perl
use 5.010;
use strict;
use warnings;
use Test::More;
use Punk;

# The Future::AsyncAwait::Awaitable protocol on Punk::Future. The methods are
# always present; the async sub syntax that drives them is not, so the file is
# split. Everything callable directly runs everywhere.

sub F { Punk::Future->new }

# ---- the protocol is complete --------------------------------------------
for my $m (qw(
    AWAIT_NEW_DONE AWAIT_NEW_FAIL AWAIT_CLONE
    AWAIT_DONE AWAIT_FAIL AWAIT_GET AWAIT_WAIT
    AWAIT_IS_READY AWAIT_IS_CANCELLED
    AWAIT_ON_READY AWAIT_ON_CANCEL AWAIT_CHAIN_CANCEL
)) {
    ok(Punk::Future->can($m), "$m is implemented");
}

# ---- constructors --------------------------------------------------------
{
    my $f = Punk::Future->AWAIT_NEW_DONE('result');
    isa_ok($f, 'Punk::Future', 'AWAIT_NEW_DONE');
    ok($f->AWAIT_IS_READY, 'AWAIT_NEW_DONE is ready');
    ok(!$f->AWAIT_IS_CANCELLED, 'AWAIT_NEW_DONE is not cancelled');
    is_deeply([$f->AWAIT_GET], ['result'], 'AWAIT_GET in list context');
    is(scalar $f->AWAIT_GET, 'result', 'AWAIT_GET in scalar context');
}
{
    my $f = Punk::Future->AWAIT_NEW_FAIL('Oopsie');
    ok($f->AWAIT_IS_READY, 'AWAIT_NEW_FAIL is ready');
    my $line = __LINE__ + 1;
    ok(!eval { $f->AWAIT_GET; 1 }, 'AWAIT_GET on a failure dies');
    is($@, "Oopsie at " . __FILE__ . " line $line.\n",
       'the exception is reported at the caller');
}
{
    # a failure with no failure value is not a failure; only the protocol
    # spelling defaults, fail_future is left as it was
    my $f = Punk::Future->AWAIT_NEW_FAIL;
    ok(!eval { $f->AWAIT_GET; 1 }, 'AWAIT_NEW_FAIL with no message still throws');
    my $g = Punk::Future->fail_future;
    ok($g->is_failed, 'fail_future with no message is unchanged');
}

# ---- clone ---------------------------------------------------------------
{
    my $f = F();
    my $g = $f->AWAIT_CLONE;
    isa_ok($g, 'Punk::Future', 'AWAIT_CLONE');
    ok(!$g->AWAIT_IS_READY, 'the clone is pending');
    ok(!$f->AWAIT_IS_READY, 'the original is untouched');
    isnt("$f", "$g", 'the clone is a different future');
    $g->done('independent');
    ok(!$f->is_ready, 'settling the clone does not settle the original');
}
{
    # The clone must carry the source's loop, because that is how the future
    # an async sub returns learns what can settle it. Off-loop there is no
    # loop to carry, and the clone must be block-mode too - which shows up as
    # AWAIT_WAIT reporting the missing loop rather than hanging.
    my $f = F();
    my $g = $f->AWAIT_CLONE;
    ok(!eval { $g->AWAIT_WAIT; 1 }, 'AWAIT_WAIT on a block-mode clone dies');
    like($@, qr/no event loop/, 'the clone inherited block mode, not a loop');
}

# ---- AWAIT_GET reads, AWAIT_WAIT waits -----------------------------------
# The two messages must differ: that difference is what proves AWAIT_GET took
# the reading branch rather than falling through to the waiting one.
{
    my $f = F();
    ok(!eval { $f->AWAIT_GET; 1 }, 'AWAIT_GET on a pending future dies');
    like($@, qr/not ready/, 'AWAIT_GET says the future is not ready');
    ok(!eval { $f->AWAIT_WAIT; 1 }, 'AWAIT_WAIT on a pending future dies');
    like($@, qr/no event loop/, 'AWAIT_WAIT tried to wait');
}

# ---- scalar context yields the first value -------------------------------
{
    my $f = Punk::Future->done_future(1, 2, 3);
    is_deeply([$f->get], [1,2,3], 'list context gives every value');
    is(scalar $f->get, 1, 'scalar context gives the FIRST value');
    is(scalar $f->result, 1, 'result is the same method');
    is(scalar $f->AWAIT_GET, 1, 'and so is AWAIT_GET');
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
    my @got;
    $f->on_cancel(sub { push @got, $_[0] });
    is(scalar @got, 0, 'on_cancel has not fired yet');
    $f->cancel;
    is(scalar @got, 1, 'on_cancel fired on cancellation');
    isa_ok($got[0], 'Punk::Future', 'the cancel callback got the future');
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
{
    # The cancel goes out as a method, so a future of any class works - and
    # nothing the caller handed over is ever taken for one of ours.
    my $cancelled = 0;
    {
        package T::Foreign::Future;
        sub new    { bless {}, shift }
        sub cancel { $cancelled++; return }
    }
    my $f = F();
    $f->AWAIT_CHAIN_CANCEL(T::Foreign::Future->new);
    $f->cancel;
    is($cancelled, 1, 'a foreign future is cancelled through its own method');
}

# ---- a blessed IV of another class is not a future -----------------------
# Punk blesses several classes into an IV holding a struct pointer, so without
# a class check a future method would read the wrong struct instead of dying.
{
    my $notafuture = bless \(my $x = 12345), 'T::Not::A::Future';
    ok(!eval { Punk::Future::is_ready($notafuture); 1 },
       'a foreign blessed IV is refused');
    like($@, qr/not a future/, 'and says so');
}

# ---- async sub integration -----------------------------------------------
SKIP: {
    skip 'Future::AsyncAwait required for the async sub tests', 8
        unless eval { require Future::AsyncAwait; 1 };

    # async sub is syntax, so the whole block has to be compiled late.
    my $ok = eval <<'ASYNC';
        use Future::AsyncAwait future_class => 'Punk::Future';

        {   # a future of this class can be awaited, and the async sub
            # returns one of the same class
            my $inner = Punk::Future->new;
            async sub t_await { my @v = await $inner; return "got:@v" }
            my $outer = t_await();
            isa_ok($outer, 'Punk::Future', 'the async sub result');
            ok(!$outer->is_ready, 'the async sub is suspended on the await');
            $inner->done('a', 'b');
            ok($outer->is_ready, 'resolving the awaited future resumes it');
            is(scalar $outer->get, 'got:a b', 'the awaited values reached the body');
        }

        {   # a failure crosses the await
            my $inner = Punk::Future->new;
            async sub t_fail { await $inner; return 1 }
            my $outer = t_fail();
            $inner->fail("kaboom\n");
            ok($outer->is_failed, 'the async sub failed');
            is($outer->failure, "kaboom\n", 'the failure crossed the await');
        }

        {   # cancelling the outer future cancels what it is awaiting
            my $inner = Punk::Future->new;
            async sub t_cancel { await $inner; return 1 }
            my $outer = t_cancel();
            $outer->cancel;
            ok($inner->is_cancelled, 'cancelling the caller cancels the awaited future');
        }

        {   # two sequential awaits, each resolving immediately
            async sub t_two { my $s = shift; await $s->(); await $s->(); return }
            my $send = sub { my $f = Punk::Future->new; $f->done; $f };
            my $outer = t_two($send);
            ok($outer->is_ready, 'two sequential awaits complete');
        }
        1;
ASYNC
    diag("async sub block failed to compile: $@") unless $ok;
}

done_testing;
