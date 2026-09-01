#!perl
use 5.008003;
use strict;
use warnings;
use Test::More;
use Fetch::Future;

# The protocol methods are always present; the async sub syntax that uses
# them is not, so the file is split. Everything that can be tested by
# calling the methods directly runs everywhere.

sub F { Fetch::Future->new }

# ---- the protocol is complete --------------------------------------------
for my $m (qw(
    AWAIT_NEW_DONE AWAIT_NEW_FAIL AWAIT_CLONE
    AWAIT_DONE AWAIT_FAIL AWAIT_GET AWAIT_WAIT
    AWAIT_IS_READY AWAIT_IS_CANCELLED
    AWAIT_ON_READY AWAIT_ON_CANCEL AWAIT_CHAIN_CANCEL
)) {
    ok(Fetch::Future->can($m), "$m is implemented");
}

# ---- constructors --------------------------------------------------------
{
    my $f = Fetch::Future->AWAIT_NEW_DONE('result');
    isa_ok($f, 'Fetch::Future', 'AWAIT_NEW_DONE');
    ok($f->AWAIT_IS_READY, 'AWAIT_NEW_DONE is ready');
    ok(!$f->AWAIT_IS_CANCELLED, 'AWAIT_NEW_DONE is not cancelled');
    is_deeply([$f->AWAIT_GET], ['result'], 'AWAIT_GET in list context');
    is(scalar $f->AWAIT_GET, 'result', 'AWAIT_GET in scalar context');
}
{
    my $f = Fetch::Future->AWAIT_NEW_FAIL('Oopsie');
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
    isa_ok($g, 'Fetch::Future', 'AWAIT_CLONE');
    ok(!$g->AWAIT_IS_READY, 'the clone is pending');
    ok(!$f->AWAIT_IS_READY, 'the original is untouched');
    isnt("$f", "$g", 'the clone is a different future');
}

# ---- AWAIT_GET reads, AWAIT_WAIT waits -----------------------------------
{
    # Outside a loop, waiting on a pending future is an error. AWAIT_GET must
    # not wait, so it reports unreadiness rather than the loop's complaint.
    local $Fetch::Future::AWAIT = undef;
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

    # async sub is syntax, so the whole block has to be compiled late.
    my $ok = eval <<'ASYNC';
        use Future::AsyncAwait future_class => 'Fetch::Future';

        {   # a future of this class can be awaited, and the async sub
            # returns one of the same class
            my $inner = Fetch::Future->new;
            async sub t_await { my $v = await $inner; return "got:$v" }
            my $outer = t_await();
            isa_ok($outer, 'Fetch::Future', 'the async sub result');
            ok(!$outer->is_ready, 'the async sub is suspended on the await');
            $inner->done(42);
            ok($outer->is_ready, 'resolving the awaited future resumes it');
            is(scalar $outer->get, 'got:42', 'the awaited value reached the body');
        }

        {   # a failure crosses the await
            my $inner = Fetch::Future->new;
            async sub t_fail { await $inner; return 1 }
            my $outer = t_fail();
            $inner->fail("kaboom\n");
            ok($outer->is_failed, 'the async sub failed');
            is($outer->failure, "kaboom\n", 'the failure crossed the await');
        }

        {   # cancelling the outer future cancels what it is awaiting
            my $inner = Fetch::Future->new;
            async sub t_cancel { await $inner; return 1 }
            my $outer = t_cancel();
            $outer->cancel;
            ok($inner->is_cancelled, 'cancelling the caller cancels the awaited future');
        }

        {   # two sequential awaits, each resolving immediately
            my $send = sub { my $f = Fetch::Future->new; $f->done; $f };
            async sub t_two { my $s = shift; await $s->(); await $s->(); return }
            my $outer = t_two($send);
            ok($outer->is_ready, 'two sequential awaits complete');
            ok(!$outer->is_failed, 'two sequential awaits did not fail');
        }
        1;
ASYNC
    diag("async sub block failed to compile: $@") unless $ok;
}

# ---- the loop pin survives the clone -------------------------------------
# An async sub builds the future it returns by cloning the one it suspended
# on. $Fetch::Future::AWAIT is a single global that the last install_await
# wins, so with two loops in the process a clone that dropped its pin is
# awaited on the wrong one and never resolves.
SKIP: {
    skip 'Future::AsyncAwait required for the loop pin test', 3
        unless eval { require Future::AsyncAwait; 1 };
    skip 'IO::Socket::INET required for the loop pin test', 3
        unless eval { require IO::Socket::INET; require File::Spec; 1 };

    my $srv = IO::Socket::INET->new(
        LocalHost => '127.0.0.1', LocalPort => 0, Listen => 8, ReuseAddr => 1,
    ) or skip "cannot listen: $!", 3;
    my $port = $srv->sockport;

    my $pid = fork;
    skip "cannot fork: $!", 3 unless defined $pid;
    if ( !$pid ) {
        # Never hold the harness TAP pipe open, and never outlive the run.
        open STDOUT, '>', File::Spec->devnull();
        open STDERR, '>', File::Spec->devnull();
        alarm 120;
        $SIG{TERM} = sub { exit 0 };
        while ( my $cli = $srv->accept ) {
            my $line = <$cli>;
            while ( my $l = <$cli> ) { last if $l eq "\r\n" }
            my $body = 'pinned';
            print $cli "HTTP/1.1 200 OK\r\n"
                . "Content-Type: text/plain\r\n"
                . "Content-Length: " . length($body) . "\r\n"
                . "Connection: close\r\n\r\n$body";
            close $cli;
        }
        exit 0;
    }
    $srv->close;

    my $ok = eval <<"PIN";
        use Fetch;
        use Fetch::Loop::Standalone;
        use Future::AsyncAwait future_class => 'Fetch::Future';

        my \$loop_b = Fetch::Loop::Standalone->new;
        my \$loop_a = Fetch::Loop::Standalone->new;
        my \$ua_b   = Fetch->new(loop => \$loop_b);
        my \$ua_a   = Fetch->new(loop => \$loop_a);

        \$ua_b->get("http://127.0.0.1:$port/")->get;
        \$ua_a->get("http://127.0.0.1:$port/")->get;
        \$loop_a->install_await;   # the global now names the OTHER loop

        async sub t_pin { my \$r = await \$ua_b->get("http://127.0.0.1:$port/");
                          return \$r->content }
        my \$outer = t_pin();
        isa_ok(\$outer, 'Fetch::Future', 'the async sub result');
        ok(defined \$outer->[4], 'the clone carries a loop pin');
        my \$got = eval {
            local \$SIG{ALRM} = sub { die "timed out\\n" };
            alarm 30;
            my \$r = scalar \$outer->get;
            alarm 0;
            \$r;
        };
        is(\$got, 'pinned', 'awaited on its own loop, not the installed one')
            or diag("get failed: \$@");
        1;
PIN
    diag("loop pin block failed: $@") unless $ok;

    kill 'TERM', $pid;
    waitpid $pid, 0;
}

done_testing;
