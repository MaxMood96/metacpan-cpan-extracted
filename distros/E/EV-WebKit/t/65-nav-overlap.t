use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;
use IO::Socket::INET;

# Regression coverage for "a stray navigation signal resolves the WRONG
# nav's callback": {pending} used to be a bare [cb, timer] with no identity,
# so when go(B) supersedes an in-flight go(A), WebKit's own cancellation of
# A's now-abandoned load surfaces later as a load-failed for A's uri -- and
# since {pending} already holds B's callback by the time it arrives, the OLD
# code resolved B's callback with A's cancellation error, silently dropping
# B's real completion (already consumed). See _start_nav/_finish_nav's
# generation + tracked-target-uri gating in lib/EV/WebKit.pm.

# --- 1) reentrant repro (100% deterministic, no timing dependency): the
#     mock_scheme producer for mock://a reentrantly calls go(mock://b)
#     before returning mock://a's own body. go(a)'s own in-flight load is
#     itself what gets superseded-then-cancelled, entirely synchronously
#     from Perl's point of view.
{
    my @stray_errors;
    my $b = EV::WebKit->new(window=>[300,200], timeout=>5,
        on_error => sub { push @stray_errors, $_[0] });
    my $reentered = 0;
    my ($a_ok, $a_err, $b_ok, $b_err, $b_uri);
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        my ($n) = $uri =~ m{mock://(\w+)};
        if ($n eq 'a' && !$reentered) {
            $reentered = 1;
            $b->go('mock://b', sub {
                ($b_ok, $b_err) = @_;
                $b_uri = $b->uri;
                EV::break;
            });
        }
        return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
    });
    $b->go('mock://a', sub { ($a_ok, $a_err) = @_ });
    my $wd = EV::timer(15, 0, sub { fail('reentrant repro: watchdog fired -- cb_b never resolved'); EV::break });
    EV::run;
    undef $wd;

    is($a_err, 'superseded', 'reentrant repro: outer go(a) callback superseded');
    is($a_ok, undef, 'reentrant repro: outer go(a) callback result is undef');
    is($b_err, undef, 'reentrant repro: nested go(b) callback resolves with NO error')
        or diag("b_err=" . ($b_err // 'u'));
    ok($b_ok, 'reentrant repro: nested go(b) callback result is true');
    is($b_uri, 'mock://b', 'reentrant repro: final uri is mock://b');
    is(scalar(@stray_errors), 0, 'reentrant repro: no stray on_error deliveries')
        or diag("stray_errors=@stray_errors");

    $b->quit;
}

# --- 2) plain overlapping go()/go() -- the non-reentrant case (1) and (3)
#     cannot cover: an ordinary caller issuing a second go() while the first
#     is still loading. WebKit's cancellation of A's now-abandoned load
#     surfaces later as a load-failed for A's uri, by which time {pending}
#     already holds B.
#
#     The overlap is MANUFACTURED, not raced. Issuing go(B) from a short
#     EV::timer only tests anything when the timer beats the load, and stops
#     doing so as navigation gets faster -- silently, since the outcome is
#     asserted but never the premise. A server that withholds its response
#     makes A provably in flight on any machine, and the preconditions below
#     say so out loud instead of leaving it inferred from a passing result.
#
#     Two positions in A's lifecycle, since where the cancellation lands
#     relative to the commit is exactly what the gates disambiguate:
#       held  -- no response at all, so A is cancelled before committing
#       hdrs  -- headers sent, body withheld, so A is cancelled after it
#                commits and has a uri of its own
my @MODES  = qw(held hdrs);
my @TRIALS = (1 .. 3);
use constant ASSERTS_PER_TRIAL => 7;
SKIP: {
    # skip, NOT plan skip_all: assertions have already run in this file, and a
    # plan emitted after them is a BAD PLAN -- "You planned 0 tests but ran N",
    # and the whole run FAILS on exactly the restricted hosts this guard is for.
    # The count comes off the same lists the loops below use, so it cannot drift.
    my $srv = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => 0,
                                    Listen => 20, ReuseAddr => 1)
        or skip "cannot bind a test server socket: $!",
                @MODES * @TRIALS * ASSERTS_PER_TRIAL;
    my $port = $srv->sockport;
    my (%conns, @held);
    my $accept = EV::io($srv, EV::READ, sub {
        my $c = $srv->accept or return;
        $c->blocking(0);
        my $buf = '';
        my $rw; $rw = EV::io($c, EV::READ, sub {
            my $n = sysread($c, my $chunk, 4096);
            if (!defined $n) { return if $!{EAGAIN} || $!{EWOULDBLOCK}; delete $conns{$c}; return }
            return delete $conns{$c} unless $n;
            $buf .= $chunk;
            return unless $buf =~ /\r?\n\r?\n/;
            delete $conns{$c};
            my ($path) = $buf =~ m{^\S+\s+(\S+)};
            $path //= '/';
            # /held: never answer. /hdrs: headers only, body withheld. Both
            # keep the socket open, so the load stays in flight until WebKit
            # itself cancels it. @held holds the sockets -- dropping one here
            # would close it and end the load we are trying to suspend.
            if ($path =~ m{^/(held|hdrs)}) {
                if ($1 eq 'hdrs') {
                    $c->blocking(1);
                    print $c "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n"
                           . "Content-Length: 100000\r\n\r\n"
                           . '<html><head><title>one</title></head><body>' . ('x' x 2000);
                    $c->flush;
                }
                push @held, $c;
                return;
            }
            my $body = '<html><head><title>two</title></head><body>two</body></html>';
            print $c "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n"
                   . "Content-Length: " . length($body) . "\r\nConnection: close\r\n\r\n$body";
            close $c;
        });
        $conns{$c} = $rw;
    });

    for my $mode (@MODES) {
        for my $trial (@TRIALS) {
            my @stray_errors;
            my $b = EV::WebKit->new(window => [300,200], timeout => 5,
                on_error => sub { push @stray_errors, $_[0] });
            my $one = "http://127.0.0.1:$port/$mode";
            my $two = "http://127.0.0.1:$port/two";
            my ($one_err, $two_ok, $two_err, $two_uri);
            $b->go($one, sub { (undef, $one_err) = @_ });

            # Pump until A has provably started -- {pending}[4] is the module's
            # own started_seen flag. Bounded, so a nav that never starts fails
            # HERE rather than making the assertions below meaningless.
            my $deadline = EV::time + 10;
            until ((($b->{pending} || [])->[4]) || EV::time > $deadline) {
                my $t = EV::timer(0.02, 0, sub { EV::break }); EV::run;
            }
            ok($b->{pending}, "$mode/$trial: precondition -- A is still in flight when B is issued")
                or diag('A had already resolved; this trial would prove nothing');
            ok(($b->{pending} || [])->[4], "$mode/$trial: precondition -- A has started");

            $b->go($two, sub { ($two_ok, $two_err) = @_; $two_uri = $b->uri; EV::break });
            my $wd = EV::timer(15, 0, sub {
                fail("$mode/$trial: watchdog -- cb2 never resolved"); EV::break });
            EV::run; undef $wd;

            ok(defined $two_ok, "$mode/$trial: cb2 (go B) fired");
            is($two_err, undef, "$mode/$trial: cb2 resolves without error")
                or diag("two_err=" . ($two_err // 'undef'));
            is($two_uri, $two, "$mode/$trial: final uri is B");
            is($one_err, 'superseded', "$mode/$trial: cb1 (go A) superseded")
                or diag("one_err=" . ($one_err // 'undef'));
            is(scalar(@stray_errors), 0, "$mode/$trial: no stray on_error deliveries")
                or diag("stray_errors=@stray_errors");
            $b->quit;
        }
    }
    undef $accept;
    close $_ for @held;
}

# --- 3) reentrant back() -- the same cross-talk mechanism as (1)/(2) above,
#     but for a nav with NO tracked target uri. back()/forward()/reload()/
#     load_html() call _start_nav($cb) without a target (a history entry's
#     destination isn't known ahead of time, and load_html has none at all),
#     so the target-uri gate that protects go()-vs-go() above is inert for
#     these four -- see _start_nav's callers. Only the started-since gate
#     (a stray load-failed can't belong to a pending nav that has not yet
#     seen its own load-changed started/committed) protects them. Prime a
#     two-entry history (h1, h2) so back() has somewhere to go, then --
#     reentrantly, from inside mock://a's own producer, exactly like test
#     (1) above -- call back() before mock://a's own load settles. WebKit's
#     cancellation of the now-superseded mock://a load surfaces later as a
#     load-failed for mock://a's uri; back()'s pending must not be
#     mis-resolved by it.
{
    my @stray_errors;
    my $b = EV::WebKit->new(window=>[300,200], timeout=>5,
        on_error => sub { push @stray_errors, $_[0] });
    my $reentered = 0;
    my ($back_ok, $back_err, $back_uri);
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        my ($n) = $uri =~ m{mock://(\w+)};
        if ($n eq 'a' && !$reentered) {
            $reentered = 1;
            $b->back(sub {
                ($back_ok, $back_err) = @_;
                $back_uri = $b->uri;
                EV::break;
            });
        }
        return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
    });

    my ($e1, $e2);
    $b->go('mock://h1', sub { (undef,$e1) = @_; $b->go('mock://h2', sub { (undef,$e2) = @_; EV::break }) });
    my $wd0 = EV::timer(15, 0, sub { fail('reentrant back(): watchdog fired during history setup'); EV::break });
    EV::run;
    undef $wd0;

    my ($a_ok, $a_err);
    $b->go('mock://a', sub { ($a_ok, $a_err) = @_ });
    my $wd = EV::timer(15, 0, sub { fail('reentrant back(): watchdog fired -- back() callback never resolved'); EV::break });
    EV::run;
    undef $wd;

    is($a_err, 'superseded', 'reentrant back(): outer go(a) callback superseded');
    is($back_err, undef, 'reentrant back(): back() callback resolves with NO error')
        or diag("back_err=" . ($back_err // 'u'));
    ok($back_ok, 'reentrant back(): back() callback result is true');
    is($back_uri, 'mock://h1', 'reentrant back(): final uri is the back target (mock://h1)');
    is(scalar(@stray_errors), 0, 'reentrant back(): no stray on_error deliveries')
        or diag("stray_errors=@stray_errors");

    $b->quit;
}

# --- 4) reentrant reload() -- same mechanism as (3), superseding with
#     reload() instead of back(). This specifically exercises the
#     started-since gate rather than any uri comparison, and in a stronger
#     way than (3): confirmed live (5/5 trace runs), WebKit's reload() here
#     reloads the last-COMMITTED page (mock://h2 -- mock://a never
#     committed before being superseded), NOT the provisional mock://a uri
#     that get_uri() optimistically shows -- so reload()'s own pending has
#     an untracked target that doesn't even coincide with the superseded
#     nav's uri. Only "has MY pending seen its own started yet" can
#     identify the later stray load-failed (for mock://a) as not-mine; a
#     uri comparison would have nothing to key off at all. The final uri
#     is therefore intentionally not asserted here (it is an incidental
#     WebKit implementation detail, not part of this fix's contract) --
#     only that reload() resolves truthfully, without cross-talk.
{
    my @stray_errors;
    my $b = EV::WebKit->new(window=>[300,200], timeout=>5,
        on_error => sub { push @stray_errors, $_[0] });
    my $reentered = 0;
    my ($rl_ok, $rl_err, $rl_uri);
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        my ($n) = $uri =~ m{mock://(\w+)};
        if ($n eq 'a' && !$reentered) {
            $reentered = 1;
            $b->reload(sub {
                ($rl_ok, $rl_err) = @_;
                $rl_uri = $b->uri;
                EV::break;
            });
        }
        return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
    });

    my $e2;
    $b->go('mock://h2', sub { (undef,$e2) = @_; EV::break });
    my $wd0 = EV::timer(15, 0, sub { fail('reentrant reload(): watchdog fired during setup'); EV::break });
    EV::run;
    undef $wd0;

    my ($a_ok, $a_err);
    $b->go('mock://a', sub { ($a_ok, $a_err) = @_ });
    my $wd = EV::timer(15, 0, sub { fail('reentrant reload(): watchdog fired -- reload() callback never resolved'); EV::break });
    EV::run;
    undef $wd;

    is($a_err, 'superseded', 'reentrant reload(): outer go(a) callback superseded');
    is($rl_err, undef, 'reentrant reload(): reload() callback resolves with NO error')
        or diag("rl_err=" . ($rl_err // 'u'));
    ok($rl_ok, 'reentrant reload(): reload() callback result is true');
    ok(defined $rl_uri, 'reentrant reload(): final uri is defined (navigation genuinely completed)')
        or diag("rl_uri=" . ($rl_uri // 'u'));
    is(scalar(@stray_errors), 0, 'reentrant reload(): no stray on_error deliveries')
        or diag("stray_errors=@stray_errors");

    $b->quit;
}

# --- 5) non-regression: a genuine navigation failure for a NEW (non-
#     overlapping) go() must still resolve with a real, defined error -- the
#     started-since gate must never swallow a truthful failure. go() tracks
#     a target uri, so this is additionally covered by the pre-existing
#     uri-gate (target known and equal to failing_uri is never stray,
#     regardless of started state) -- belt and suspenders.
{
    my $b = EV::WebKit->new(window=>[300,200], timeout=>4);
    my ($r, $e);
    $b->go('http://nonexistent.invalid./', sub { ($r,$e) = @_; EV::break });
    my $wd = EV::timer(10, 0, sub { fail('genuine go() failure: watchdog fired -- callback never resolved'); EV::break });
    EV::run;
    undef $wd;
    ok(defined $e, 'genuine go() failure still resolves with a real, defined error')
        or diag("r=" . ($r // 'u'));
    $b->quit;
}

# --- 6) non-regression: a normal load_html() (no overlap at all) still
#     resolves successfully -- load_html has no tracked target uri either,
#     so it depends entirely on the started-since gate staying out of the
#     way of its own genuine 'finished'.
{
    my $b = EV::WebKit->new(window=>[300,200]);
    my ($ok, $err);
    $b->load_html('<html><head><title>plain</title></head><body>hi</body></html>', sub {
        ($ok, $err) = @_;
        EV::break;
    });
    my $wd = EV::timer(10, 0, sub { fail('plain load_html(): watchdog fired -- callback never resolved'); EV::break });
    EV::run;
    undef $wd;
    is($err, undef, 'plain load_html(): resolves without error');
    ok($ok, 'plain load_html(): resolves with a true result');
    is($b->title, 'plain', 'plain load_html(): title reflects the loaded content');
    $b->quit;
}

done_testing;
