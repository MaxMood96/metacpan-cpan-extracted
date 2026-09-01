#!perl
use 5.008003;
use strict;
use warnings;
use Test::More;
use DBIx::Loop;

# The protocol methods are always present; the async sub syntax that uses
# them is not, so the file is split. Everything that can be tested by
# calling the methods directly runs everywhere.

sub F { DBIx::Loop::Future->new }

# ---- the protocol is complete --------------------------------------------
for my $m (qw(
    AWAIT_NEW_DONE AWAIT_NEW_FAIL AWAIT_CLONE
    AWAIT_DONE AWAIT_FAIL AWAIT_GET AWAIT_WAIT
    AWAIT_IS_READY AWAIT_IS_CANCELLED
    AWAIT_ON_READY AWAIT_ON_CANCEL AWAIT_CHAIN_CANCEL
)) {
    ok(DBIx::Loop::Future->can($m), "$m is implemented");
}

# ---- constructors --------------------------------------------------------
{
    my $f = DBIx::Loop::Future->AWAIT_NEW_DONE('result');
    isa_ok($f, 'DBIx::Loop::Future', 'AWAIT_NEW_DONE');
    ok($f->AWAIT_IS_READY, 'AWAIT_NEW_DONE is ready');
    is_deeply([$f->AWAIT_GET], ['result'], 'AWAIT_GET in list context');
    is(scalar $f->AWAIT_GET, 'result', 'AWAIT_GET in scalar context');
}
{
    my $f = DBIx::Loop::Future->AWAIT_NEW_DONE('a', 'b');
    is_deeply([$f->AWAIT_GET], ['a','b'], 'AWAIT_NEW_DONE keeps every value');
}
{
    my $f = DBIx::Loop::Future->AWAIT_NEW_FAIL('Oopsie');
    ok($f->AWAIT_IS_READY, 'AWAIT_NEW_FAIL is ready');
    ok($f->is_failed, 'AWAIT_NEW_FAIL is failed');
    my $line = __LINE__ + 1;
    ok(!eval { $f->AWAIT_GET; 1 }, 'AWAIT_GET on a failure dies');
    is($@, "Oopsie at " . __FILE__ . " line $line.\n",
       'the exception is reported at the caller');
}

# ---- clone ---------------------------------------------------------------
{
    my $f = F();
    my $g = $f->AWAIT_CLONE;
    isa_ok($g, 'DBIx::Loop::Future', 'AWAIT_CLONE');
    ok(!$g->AWAIT_IS_READY, 'the clone is pending');
    ok(!$f->AWAIT_IS_READY, 'the original is untouched');
    isnt("$f", "$g", 'the clone is a different future');
    $g->done('independent');
    ok(!$f->is_ready, 'settling the clone does not settle the original');
}

# ---- reading, not waiting ------------------------------------------------
# This distribution has no blocking wait: awaiting is the event loop's job.
# Both AWAIT_GET and AWAIT_WAIT therefore read, and say so on a pending one.
{
    my $f = F();
    ok(!eval { $f->AWAIT_GET; 1 }, 'AWAIT_GET on a pending future dies');
    like($@, qr/not ready/, 'AWAIT_GET says the future is not ready');
    ok(!eval { $f->AWAIT_WAIT; 1 }, 'AWAIT_WAIT on a pending future dies');
    like($@, qr/not ready/, 'AWAIT_WAIT does not block either');
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
{
    # fail() documents exactly one error; AWAIT_FAIL shares its body and so
    # must tolerate the extra values the protocol may pass.
    my $f = F();
    $f->AWAIT_FAIL("first\n", 'category', 'detail');
    is($f->failure, "first\n", 'AWAIT_FAIL takes the first value');
    my $g = F();
    ok(!eval { $g->fail; 1 }, 'fail() still requires an error');
    like($@, qr/Usage: DBIx::Loop::Future::fail/, 'and reports the same usage');
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

# ---- cancellation is not supported ---------------------------------------
# A DBIx::Loop::Future settles exactly once, into done or failed. There is no
# third outcome, so the protocol's cancellation methods take the constant
# false and no-op form it provides for exactly this case. These tests pin
# that, so the day cancellation is added they are what has to change.
{
    ok(!DBIx::Loop::Future->can('cancel'),
       'there is no cancel method to reach a cancelled state with');
}
{
    my $pending = F();
    my $done    = F()->done(1);
    my $failed  = F();
    $failed->fail("x\n");
    ok(!$pending->AWAIT_IS_CANCELLED, 'a pending future is not cancelled');
    ok(!$done->AWAIT_IS_CANCELLED,    'a done future is not cancelled');
    ok(!$failed->AWAIT_IS_CANCELLED,  'a failed future is not cancelled');
}
{
    my $f = F();
    my $fired = 0;
    is(eval { $f->AWAIT_ON_CANCEL(sub { $fired++ }); 1 }, 1,
       'AWAIT_ON_CANCEL accepts a callback');
    my $g = F();
    is(eval { $f->AWAIT_CHAIN_CANCEL($g); 1 }, 1,
       'AWAIT_CHAIN_CANCEL accepts a future');
    $f->done;
    is($fired, 0, 'the cancel callback never fires');
    ok(!$g->is_ready, 'the chained future is left alone');
}

# ---- async sub integration -----------------------------------------------
SKIP: {
    skip 'Future::AsyncAwait required for the async sub tests', 8
        unless eval { require Future::AsyncAwait; 1 };

    # async sub is syntax, so the whole block has to be compiled late.
    my $ok = eval <<'ASYNC';
        use Future::AsyncAwait future_class => 'DBIx::Loop::Future';

        {   # a future of this class can be awaited, and the async sub
            # returns one of the same class
            my $inner = DBIx::Loop::Future->new;
            async sub t_await { my @v = await $inner; return "got:@v" }
            my $outer = t_await();
            isa_ok($outer, 'DBIx::Loop::Future', 'the async sub result');
            ok(!$outer->is_ready, 'the async sub is suspended on the await');
            $inner->done('a', 'b');
            ok($outer->is_ready, 'resolving the awaited future resumes it');
            is(scalar $outer->get, 'got:a b', 'the awaited values reached the body');
        }

        {   # a failure crosses the await
            my $inner = DBIx::Loop::Future->new;
            async sub t_fail { await $inner; return 1 }
            my $outer = t_fail();
            $inner->fail("kaboom\n");
            ok($outer->is_failed, 'the async sub failed');
            is($outer->failure, "kaboom\n", 'the failure crossed the await');
        }

        {   # an exception in the body reaches the returned future rather
            # than the warn that on_ready traps callbacks with
            my $inner = DBIx::Loop::Future->new;
            async sub t_die { await $inner; die "body exploded\n" }
            my $outer = t_die();
            $inner->done(1);
            is($outer->failure, "body exploded\n",
               'a die in the body fails the returned future');
        }

        {   # two sequential awaits, each resolving immediately
            async sub t_two { my $s = shift; await $s->(); await $s->(); return }
            my $send = sub { my $f = DBIx::Loop::Future->new; $f->done; $f };
            my $outer = t_two($send);
            ok($outer->is_ready, 'two sequential awaits complete');
        }
        1;
ASYNC
    diag("async sub block failed to compile: $@") unless $ok;
}

done_testing;
