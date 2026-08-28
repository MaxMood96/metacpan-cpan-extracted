use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use IO::Socket::INET; use Time::HiRes qw(time);

# THIS LIVES IN xt/ AND DOES NOT RUN UNDER `make test`, DELIBERATELY.
#
# Run it on purpose:   xvfb-run -a prove -Ilib -b xt/66-nav-finished.t
#
# Everything here is a RACE regression test, and two of its assertions are
# lower bounds on elapsed time (">= 0.1s"). That is not decoration: a stray
# 'finished' resolves in ~10-60ms while the real outcome arrives after the
# server's deliberate 150ms delay, so the time GAP is the only thing that
# distinguishes "resolved by my own outcome" from "resolved by somebody
# else's stray event". The assertion cannot be loosened without deleting
# the guard.
#
# The consequence is that a machine under load fails this for reasons that
# have nothing to do with the code: it went red once on a GitHub runner and
# green on the next identical run. A test whose verdict depends on winning a
# 150ms IPC race does not belong in the suite a user or a CPAN tester runs,
# so it does not run there. It is still worth keeping and worth running by
# hand after touching navigation.
#
# Known open issue (do not "fix" by loosening). The reload-vs-go block can
# legitimately fail when the web process commits the superseded mock load
# before it processes the reload -- a real ordering race in the module, not a
# test artifact. Analysed 2026-07-23; there are TWO paths to the same false
# success, and closing only one does not fix it:
#
#   Path 1 (mechanism 1, the committed-uri gate). The load-changed
#   started/committed branch stamps $p->[5] onto whatever is CURRENTLY
#   pending, with no check that the event belongs to it -- unlike finished
#   and load-failed, which both gate on {_superseded}. A superseded nav's
#   belated 'committed' therefore stamps the reload pending's $p->[5] with
#   the superseded uri, and that nav's 'finished' then matches on identity.
#   This half IS locally fixable: gate the started/committed stamp on
#   {_superseded} too, so a tail signal for a torn-down nav is not stamped.
#
#   Path 2 (mechanism 2, the superseded-uri filter). Even with NO commit,
#   _finished_is_stray resolves the current pending as success when the
#   finished's uri coincides with a superseded identity ("coincide ->
#   resolve"). In this race get_uri is still the superseded mock uri at
#   finished time, so this fires on its own. Flipping it to "coincide ->
#   stray" would close the race -- BUT the R11 report
#   (.superpowers/sdd/review-loop-r11-fix-report.md) states that branch
#   keeps a bfcache no-commit restore working, a case R11 could NOT trigger
#   live and verified only by inspection. It cannot be reproduced in this
#   environment either, so the flip cannot be shown safe.
#
# Because path 2 needs an unverifiable change to an 11-round-hardened state
# machine, and this test is already quarantined here, the module is left as
# the documented irreducible blind spot ('finished' carries no nav identity).
# A session that CAN reproduce the bfcache no-commit case should revisit both
# paths together. Do not ship a partial (path-1-only) fix: it muddies the
# water without closing the race.

# Regression coverage for R11: the load-changed 'finished' success path
# ($self->_finish_nav(undef) if $ev eq 'finished') had NO identity check at
# all -- unlike load-failed's target-uri/started-since gates (R9/R10, see
# t/65-nav-overlap.t). A SUPERSEDED nav's own belated 'finished' (WebKit
# still completes a request it had already been handed a response for, even
# after being superseded/cancelled -- confirmed live) therefore resolved the
# CURRENT (still-in-flight) pending with a FALSE SUCCESS, and the real nav's
# own genuine outcome then arrived to find {pending} already consumed. See
# _finished_is_stray / {_superseded} in lib/EV/WebKit.pm and
# .superpowers/sdd/review-loop-r11-fix-report.md.
#
# A real, delayed, ultimately-FAILING network target is used for the two
# cross-talk tests below (not a second mock:// scheme) because the bug is
# otherwise unobservable by (ok, err, uri) alone: get_uri() already reflects
# the NEW pending's own target the instant it is requested -- before that
# nav's own load has even started -- so a false-early 'success' and the
# eventual genuine 'success' would report the identical (uri, ok). Only a
# controlled real failure a fraction of a second later makes "resolved via
# the stray finished" and "resolved via my own real outcome" observably
# different -- and, per the reviewer's own live-probed timing, deterministic.
#
# In-process, non-blocking (EV::io) mini HTTP server -- NOT a forked
# process: this test's single EV loop also pumps the GLib main context
# EV::Glib bridges WebKitGTK's IPC through, so a blocking (or forked, but
# fate-sharing) server risks stalling that context -- see t/63-proxy.t for
# the same reasoning; this reuses that exact pattern.
my $srv = IO::Socket::INET->new(LocalAddr=>'127.0.0.1', LocalPort=>0, Listen=>5, ReuseAddr=>1)
    or plan skip_all => "cannot bind test server socket: $!";
my $port = $srv->sockport;
my %hits;      # path => hit count -- /reload_target behaves differently on its 2nd (reload) hit
my %conns;     # keep per-connection read/delay watchers alive, keyed by the socket
my $accept_io = EV::io($srv, EV::READ, sub {
    my $c = $srv->accept or return;
    $c->blocking(0);
    my $buf = '';
    my $rw; $rw = EV::io($c, EV::READ, sub {
        my $n = sysread($c, my $chunk, 4096);
        if (!defined $n) { return if $!{EAGAIN} || $!{EWOULDBLOCK}; delete $conns{$c}; return }
        return delete $conns{$c} unless $n;    # EOF before a full request arrived
        $buf .= $chunk;
        return unless $buf =~ /\r?\n\r?\n/;    # wait for full request headers
        delete $conns{$c};                      # done reading -- this dropped read-watcher may now be GC'd
        my ($path) = $buf =~ /^\S+\s+(\S+)/;
        $path //= '/';
        $hits{$path}++;
        if ($path eq '/slowfail' || ($path eq '/reload_target' && $hits{$path} >= 2)) {
            # a real, delayed failure: accept the connection, then abruptly
            # close it with NO response at all ~150ms later (matches the
            # reviewer's own live-probed, proven-reliable timing).
            my $t; $t = EV::timer(0.15, 0, sub { undef $t; close $c; delete $conns{$c} });
            $conns{$c} = $t;
            return;
        }
        if ($path eq '/reload_target') {
            _respond($c, 200, 'OK', "<html><head><title>ReloadTarget-hit$hits{$path}</title></head><body>rt</body></html>");
        } elsif ($path eq '/r302') {
            print $c "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:$port/final\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
            close $c;
        } elsif ($path eq '/final') {
            _respond($c, 200, 'OK', "<html><head><title>FinalPage</title></head><body>final</body></html>");
        } else {
            _respond($c, 404, 'Not Found', '');
        }
    });
    $conns{$c} = $rw;
});
sub _respond {
    my ($c, $code, $status, $body) = @_;
    print $c "HTTP/1.1 $code $status\r\nContent-Type: text/html\r\nContent-Length: "
           . length($body) . "\r\nConnection: close\r\n\r\n$body";
    close $c;
}

# --- 1) go-vs-go finished cross-talk: go('mock://a') is superseded, from
#     inside its OWN producer before it returns (100% deterministic -- the
#     exact reentrant-producer shape validated live and already used by
#     t/65-nav-overlap.t tests 1/3/4), by go() to a real target that takes
#     ~150ms to genuinely fail. Pre-fix, 'a's own belated 'finished' (its
#     mock:// request had already been handed a body) resolved the NEW
#     pending with a false, ~10ms-early SUCCESS; the real failure then had
#     nowhere to go (silently dropped -- {pending} already consumed).
{
    my @stray_errors;
    my $b = EV::WebKit->new(window=>[300,200], timeout=>5,
        on_error => sub { push @stray_errors, $_[0] });
    my $reentered = 0;
    my ($a_ok, $a_err, $new_ok, $new_err, $new_took, $t_reentry);
    my $slow_url = "http://127.0.0.1:$port/slowfail";
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        my ($n) = $uri =~ m{mock://(\w+)};
        if ($n eq 'a' && !$reentered) {
            $reentered = 1;
            $t_reentry = time();
            $b->go($slow_url, sub {
                ($new_ok, $new_err) = @_;
                $new_took = time() - $t_reentry;
                EV::break;
            });
        }
        return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
    });
    $b->go('mock://a', sub { ($a_ok, $a_err) = @_ });
    TWK::run_with_timeout(15);

    is($a_err, 'superseded', 'go-vs-go finished cross-talk: outer go(a) callback superseded');
    ok(defined $new_err, "go-vs-go finished cross-talk: superseding go()'s OWN real (failure) outcome is reported")
        or diag('new_ok='.($new_ok//'u').' new_err='.($new_err//'u'));
    like($new_err // '', qr/load failed/, 'go-vs-go finished cross-talk: real network failure, not a false success')
        if defined $new_err;
    ok(!$new_ok, "go-vs-go finished cross-talk: NOT falsely resolved as success by a's stray finished");
    cmp_ok($new_took, '>=', 0.1,
        sprintf('go-vs-go finished cross-talk: resolved after a real delay (%.3fs), not the ~10ms early window', $new_took // -1));
    is(scalar(@stray_errors), 0, 'go-vs-go finished cross-talk: no stray on_error deliveries')
        or diag("stray_errors=@stray_errors");

    $b->quit;
}

# --- 2) reload-vs-go finished cross-talk: reload() reentrantly supersedes an
#     in-flight go('mock://a') from inside its OWN producer (same
#     deterministic shape as (1) above, and as t/65-nav-overlap.t's reentrant
#     reload() test) -- reload() re-fetches the last-COMMITTED real page (not
#     the uncommitted mock://a -- see t/65-nav-overlap.t test 4 / the R10
#     report), which genuinely fails, after a real ~150ms delay, on this its
#     SECOND hit. Pre-fix, mock://a's own belated 'finished' resolved
#     reload()'s pending with a false, ~10ms-early SUCCESS (a stale title
#     from the first hit); the real failure then had nowhere to go.
{
    my @stray_errors;
    my $b = EV::WebKit->new(window=>[300,200], timeout=>5,
        on_error => sub { push @stray_errors, $_[0] });
    my $reload_url = "http://127.0.0.1:$port/reload_target";
    my $reentered = 0;
    my ($rl_ok, $rl_err, $rl_took, $t_reentry);
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        my ($n) = $uri =~ m{mock://(\w+)};
        if ($n eq 'a' && !$reentered) {
            $reentered = 1;
            $t_reentry = time();
            $b->reload(sub {
                ($rl_ok, $rl_err) = @_;
                $rl_took = time() - $t_reentry;
                EV::break;
            });
        }
        return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
    });

    my $e2;
    $b->go($reload_url, sub { (undef, $e2) = @_; EV::break });   # 1st hit -- fast 200, becomes the committed page
    TWK::run_with_timeout(15);
    is($e2, undef, 'reload-vs-go finished cross-talk: setup nav (real target) resolves without error');

    my ($a_ok, $a_err);
    $b->go('mock://a', sub { ($a_ok, $a_err) = @_ });
    TWK::run_with_timeout(15);

    is($a_err, 'superseded', 'reload-vs-go finished cross-talk: outer go(a) callback superseded');
    # The next three assertions are only meaningful if reload() actually went to
    # the network, so the server could fail its second hit. State that premise
    # as its own test rather than letting a cached reload look like three
    # unrelated failures.
    cmp_ok($hits{'/reload_target'} // 0, '>=', 2,
        'reload-vs-go finished cross-talk: reload() re-fetched (server saw hit 2, not a cached reload)');
    ok(defined $rl_err, "reload-vs-go finished cross-talk: reload()'s OWN real (failure) outcome is reported")
        or diag('rl_ok='.($rl_ok//'u').' rl_err='.($rl_err//'u'));
    ok(!$rl_ok, "reload-vs-go finished cross-talk: NOT falsely resolved as success by a's stray finished");
    cmp_ok($rl_took, '>=', 0.1,
        sprintf('reload-vs-go finished cross-talk: resolved after a real delay (%.3fs), not the ~10ms early window', $rl_took // -1));
    is(scalar(@stray_errors), 0, 'reload-vs-go finished cross-talk: no stray on_error deliveries')
        or diag("stray_errors=@stray_errors");

    $b->quit;
}

# --- Non-regression: a dropped or misrouted finished (or an overzealous new
#     gate) is a HANG, which is worse than the original bug -- these must
#     all resolve PROMPTLY and correctly. Every EV::run is bounded by
#     TWK::run_with_timeout so a regression here fails loudly, not silently.

# (a) plain go() -- no overlap at all -- resolves success promptly.
{
    my $b = EV::WebKit->new(window=>[300,200]);
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        my ($n) = $uri =~ m{mock://(\w+)};
        return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
    });
    my ($ok, $err, $took);
    my $t0 = time();
    $b->go('mock://plain', sub { ($ok, $err) = @_; $took = time() - $t0; EV::break });
    TWK::run_with_timeout(10);
    is($err, undef, 'non-regression (a) plain go(): resolves without error');
    ok($ok, 'non-regression (a) plain go(): resolves with a true result');
    cmp_ok($took, '<', 1, sprintf('non-regression (a) plain go(): resolved promptly (%.3fs)', $took // -1));
    $b->quit;
}

# (b) redirect -- a real 302 (the committed-uri gate must track the
#     POST-redirect destination, not the originally-requested uri).
{
    my $b = EV::WebKit->new(window=>[300,200], timeout=>5);
    my ($ok, $err, $uri, $title, $took);
    my $t0 = time();
    $b->go("http://127.0.0.1:$port/r302", sub {
        ($ok, $err) = @_;
        $took  = time() - $t0;
        $uri   = $b->uri;
        $title = $b->title;
        EV::break;
    });
    TWK::run_with_timeout(10);
    is($err, undef, 'non-regression (b) redirect: resolves without error');
    ok($ok, 'non-regression (b) redirect: resolves with a true result');
    is($uri, "http://127.0.0.1:$port/final", 'non-regression (b) redirect: final uri is the redirect target');
    is($title, 'FinalPage', 'non-regression (b) redirect: title reflects the redirected-to page');
    cmp_ok($took, '<', 2, sprintf('non-regression (b) redirect: resolved promptly (%.3fs)', $took // -1));
    $b->quit;
}

# (c) bfcache-shaped back(): go A, go B, back() -- must resolve PROMPTLY via
#     its own finished, not by riding out the per-nav timeout. Live tracing
#     (see the R11 fix report) found this WebKitGTK build always emits a
#     full (if very fast, ~1-3ms) started/committed/finished cycle for
#     back(), rather than ever skipping straight to 'finished' with no
#     committed at all -- but the property this test actually guards (a
#     plain, non-overlapping nav's own resolution must never be swallowed by
#     the superseded-uri gate) is exercised identically either way, since
#     {_superseded} is empty throughout for this non-overlapping back().
{
    my $b = EV::WebKit->new(window=>[300,200], timeout=>5);
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        my ($n) = $uri =~ m{mock://(\w+)};
        return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
    });
    my ($e1, $e2);
    $b->go('mock://bfa', sub { (undef, $e1) = @_; $b->go('mock://bfb', sub { (undef, $e2) = @_; EV::break }) });
    TWK::run_with_timeout(10);
    is($e1, undef, 'non-regression (c) bfcache back() setup: first nav resolves without error');
    is($e2, undef, 'non-regression (c) bfcache back() setup: second nav resolves without error');

    my ($back_ok, $back_err, $took);
    my $t0 = time();
    $b->back(sub { ($back_ok, $back_err) = @_; $took = time() - $t0; EV::break });
    TWK::run_with_timeout(10);
    is($back_err, undef, 'non-regression (c) bfcache back(): resolves without error');
    ok($back_ok, 'non-regression (c) bfcache back(): resolves with a true result');
    is($b->uri, 'mock://bfa', 'non-regression (c) bfcache back(): landed on the first page');
    cmp_ok($took, '<', 1,
        sprintf('non-regression (c) bfcache back(): resolved PROMPTLY (%.3fs) via finished, not any timeout', $took // -1))
        or diag("took=$took");
    $b->quit;
}

# (d) load_html -- no uri/network at all -- resolves.
{
    my $b = EV::WebKit->new(window=>[300,200]);
    my ($ok, $err, $took);
    my $t0 = time();
    $b->load_html('<html><head><title>plainhtml</title></head><body>hi</body></html>', sub {
        ($ok, $err) = @_;
        $took = time() - $t0;
        EV::break;
    });
    TWK::run_with_timeout(10);
    is($err, undef, 'non-regression (d) load_html: resolves without error');
    ok($ok, 'non-regression (d) load_html: resolves with a true result');
    is($b->title, 'plainhtml', 'non-regression (d) load_html: title reflects the loaded content');
    cmp_ok($took, '<', 1, sprintf('non-regression (d) load_html: resolved promptly (%.3fs)', $took // -1));
    $b->quit;
}

done_testing;
