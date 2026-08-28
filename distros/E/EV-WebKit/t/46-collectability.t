use v5.10; use strict; use warnings;
use Test::More;
use Scalar::Util 'weaken';
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit; use File::Temp 'tempdir';

# Regression for a memory-retention bug: after quit() and dropping every
# Perl reference, an EV::WebKit instance must become
# collectible by ordinary refcounting. Three independent root causes were
# found (GI async-ready-callback closures that outlive their one firing and
# keep their own copy of $self forever; a chrome reload-button <-> $c
# reference cycle; find/find_all's own wrapper closures one level out from
# _call_js) -- see the report for the full bisect matrix and fix rationale.
#
# Pattern per scenario (report's recommended shape): (1) assert setup
# actually worked, BEFORE testing teardown -- a silently-broken setup could
# trivially "pass" a collectability check for the wrong reason; (2) quit();
# (3) weaken a fresh observer on the browser (and any Element handles
# received); (4) undef every strong reference, INCLUDING any returned
# Element (an Element legitimately keeps its browser reachable via its own
# {b} field while the Element itself is alive -- dropping only $b is not
# enough); (5) spin the loop briefly so any still-in-flight completion gets
# a chance to run its post-free no-op path too; (6) assert collected.
#
# Every weaken+check stays in the same lexical scope it was created in and
# is never passed across a sub-call boundary -- passing an already-weakened
# reference by value into a sub silently produces either a false positive
# (a sub's own `undef`d copy never touches the caller's variable) or a false
# negative (copying a weak reference's value into a new container is an
# ordinary strong reference, not a weak one) -- see the report's
# "methodological pitfalls" section. spin() below deliberately takes no
# reference-bearing argument at all.

sub spin {
    my $t = EV::timer(0.5, 0, sub { EV::break });   # must stay a named lexical: an
    EV::run;                                         # unstored EV::timer is GC'd before it fires
    EV::run(EV::RUN_NOWAIT) for 1..5;
    return;
}

# 1) bare new() + quit -- control. Must already pass; a failure here means
#    the harness itself (not the module) regressed.
{
    my $b = EV::WebKit->new(window=>[200,150]);
    ok(defined $b, 'scenario 1 setup: instance constructed');

    $b->quit;
    weaken(my $w = $b);
    undef $b;
    spin();
    ok(!defined $w, 'scenario 1: bare new+quit -- browser collected');
}

# 2) load_html + one completed script().
{
    my $b = EV::WebKit->new(window=>[200,150]);
    my ($lerr, $v, $serr);
    $b->load_html('<title>s2</title><p>hi</p>', sub {
        (undef, $lerr) = @_;
        return EV::break if $lerr;
        $b->script('return 1', sub { ($v, $serr) = @_; EV::break });
    });
    TWK::run_with_timeout(15);
    ok(!$lerr, 'scenario 2 setup: load_html completed without error');
    ok(!$serr && $v == 1, 'scenario 2 setup: script() completed with expected result');

    $b->quit;
    weaken(my $w = $b);
    undef $b;
    spin();
    ok(!defined $w, 'scenario 2: one completed script() -- browser collected');
}

# 3) script() issued, then quit() in the SAME tick -- the op is still truly
#    in-flight (never dispatched a response) when teardown happens.
{
    my $b = EV::WebKit->new(window=>[200,150]);
    my $lerr;
    $b->load_html('<title>s3</title><p>hi</p>', sub { (undef, $lerr) = @_; EV::break });
    TWK::run_with_timeout(15);
    ok(!$lerr, 'scenario 3 setup: load_html completed without error');

    my ($cb_fired, $cb_err) = (0, undef);
    $b->script('return 1', sub { $cb_fired++; $cb_err = $_[1] });   # issued...
    $b->quit;                                        # ...and torn down while still in-flight -- quit() now flushes it
    is($cb_fired, 1, 'scenario 3 setup: in-flight script cb flushed exactly once by quit()');
    like($cb_err // '', qr/browser closed/, "scenario 3 setup: ...resolved with 'browser closed', not dropped");

    weaken(my $w = $b);
    undef $b;
    spin();
    ok(!defined $w, 'scenario 3: script() flushed in-flight by quit() -- browser still collected');
}

# 4) find() + an Element read, INCLUDING the Element-level find()/find_all()
#    path (the "undef $s at one resolution point" fix is specific to those --
#    see the report) -- and a weaken-check on the returned Element handle
#    itself, not just the browser: an Element legitimately keeps its browser
#    reachable via {b} while the Element is alive, so dropping the Element
#    too is required for the browser to collect, and the Element itself must
#    become collectible once dropped.
{
    my $b = EV::WebKit->new(window=>[300,200]);
    my ($lerr, $d, $derr, $tag, $span, $sperr, $all, $allerr);
    $b->load_html('<div id=d><span class=s>hi</span><span class=s>yo</span></div>', sub {
        (undef, $lerr) = @_;
        return EV::break if $lerr;
        $b->find('#d', sub {
            ($d, $derr) = @_;
            return EV::break if $derr || !$d;
            $d->tag(sub {
                $tag = $_[0];
                $d->find('span', sub {
                    ($span, $sperr) = @_;
                    $d->find_all('span', sub {
                        ($all, $allerr) = @_;
                        EV::break;
                    });
                });
            });
        });
    });
    TWK::run_with_timeout(15);
    ok(!$lerr, 'scenario 4 setup: load_html completed without error');
    ok(!$derr && ref($d), 'scenario 4 setup: find(#d) found the element');
    is($tag, 'div', 'scenario 4 setup: element read (tag)');
    ok(!$sperr && ref($span), 'scenario 4 setup: Element find(span) succeeded');
    ok(!$allerr && ref($all) eq 'ARRAY' && @$all == 2, 'scenario 4 setup: Element find_all(span) succeeded');

    $b->quit;
    weaken(my $w  = $b);
    weaken(my $wd = $d);
    undef $b;
    undef $d; undef $span; undef $all;   # drop every handle -- not just the browser variable
    spin();
    ok(!defined $w,  'scenario 4: find()+Element read (incl. Element::find/find_all) -- browser collected');
    ok(!defined $wd, 'scenario 4: returned Element handle itself collected too');
}

# 5) wait_for() resolved.
{
    my $b = EV::WebKit->new(window=>[200,150]);
    my ($lerr, $el, $werr);
    $b->load_html('<p id=p>hi</p>', sub {
        (undef, $lerr) = @_;
        return EV::break if $lerr;
        $b->wait_for('#p', sub { ($el, $werr) = @_; EV::break });
    });
    TWK::run_with_timeout(15);
    ok(!$lerr, 'scenario 5 setup: load_html completed without error');
    ok(!$werr && ref($el), 'scenario 5 setup: wait_for found the element');

    $b->quit;
    weaken(my $w = $b);
    undef $b;
    undef $el;
    spin();
    ok(!defined $w, 'scenario 5: wait_for() resolved -- browser collected');
}

# 6) chrome=>1 + two mock navigations (mock_scheme + go).
{
    my $b = EV::WebKit->new(window=>[300,200], chrome=>1);
    ok(ref($b->{chrome}) eq 'HASH', 'scenario 6 setup: chrome hash present');
    $b->mock_scheme('mock', sub {
        my ($uri) = @_;
        my ($n) = $uri =~ m{mock://(\w+)};
        return ("<html><head><title>$n</title></head><body>$n</body></html>", 'text/html');
    });
    my ($e1, $e2);
    $b->go('mock://one', sub {
        (undef, $e1) = @_;
        $b->go('mock://two', sub {
            (undef, $e2) = @_;
            EV::break;
        });
    });
    TWK::run_with_timeout(15);
    ok(!$e1 && !$e2, 'scenario 6 setup: both mock navigations completed without error');

    $b->quit;
    weaken(my $w = $b);
    undef $b;
    spin();
    ok(!defined $w, 'scenario 6: chrome=>1 + two navigations -- browser collected');
}

# 7) screenshot() (bytes mode).
{
    my $b = EV::WebKit->new(window=>[200,150]);
    my ($lerr, $bytes, $serr);
    $b->load_html('<body style="background:#0a0"><h1>s7</h1></body>', sub {
        (undef, $lerr) = @_;
        return EV::break if $lerr;
        $b->screenshot({bytes=>1}, sub { ($bytes, $serr) = @_; EV::break });
    });
    TWK::run_with_timeout(15);
    ok(!$lerr, 'scenario 7 setup: load_html completed without error');
    ok(!$serr && length($bytes // '') > 0, 'scenario 7 setup: screenshot bytes captured');

    $b->quit;
    weaken(my $w = $b);
    undef $b;
    spin();
    ok(!defined $w, 'scenario 7: screenshot() bytes mode -- browser collected');
}

# 8) pdf() to a tempfile. Flagged in the report as an untested residual (no
#    bisect scenario exercised it) -- included here specifically to close
#    that gap, not just patch it blind.
{
    my $dir = tempdir(CLEANUP=>1);
    my $pdf = "$dir/out.pdf";
    my $b = EV::WebKit->new(window=>[200,150]);
    my ($lerr, $path, $perr);
    $b->load_html('<h1>s8</h1>', sub {
        (undef, $lerr) = @_;
        return EV::break if $lerr;
        $b->pdf($pdf, sub { ($path, $perr) = @_; EV::break });
    });
    TWK::run_with_timeout(15);
    ok(!$lerr, 'scenario 8 setup: load_html completed without error');
    ok(!$perr && -s $pdf, 'scenario 8 setup: pdf() wrote a file') or diag('perr='.($perr//'undef'));

    $b->quit;
    weaken(my $w = $b);
    undef $b;
    spin();
    ok(!defined $w, 'scenario 8: pdf() to a tempfile -- browser collected');
}

# 9) set_cookie()/cookies()/clear_cookies() chain -- bonus beyond the
#    report's/task's explicit scenario list. None of the 12 bisect-matrix
#    scenarios independently exercised a cookie method's collectability
#    (they were fixed by the same-GI-async-ready-callback-mechanism argument
#    the report itself makes for _call_js, not bisect-proven on their own);
#    this closes that small residual coverage gap cheaply. save_cookies is
#    mechanically identical to cookies() (same shared-$wself-per-loop shape)
#    and already gets heavy functional exercise in t/62-cookiejar.t, so it is
#    not duplicated here.
{
    my $b = EV::WebKit->new(window=>[200,150]);
    my ($sok, $serr, $list, $lerr2, $cok, $cerr);
    $b->set_cookie({ name=>'k', value=>'v', domain=>'coll.test', path=>'/', max_age=>3600 }, sub {
        ($sok, $serr) = @_;
        $b->cookies('http://coll.test/', sub {
            ($list, $lerr2) = @_;
            $b->clear_cookies(sub { ($cok, $cerr) = @_; EV::break });
        });
    });
    TWK::run_with_timeout(15);
    ok($sok && !$serr, 'scenario 9 setup: set_cookie completed without error');
    ok(!$lerr2 && ref($list) eq 'ARRAY', 'scenario 9 setup: cookies() completed without error');
    ok($cok && !$cerr, 'scenario 9 setup: clear_cookies completed without error');

    $b->quit;
    weaken(my $w = $b);
    undef $b;
    spin();
    ok(!defined $w, 'scenario 9: set_cookie/cookies/clear_cookies chain -- browser collected');
}

# Functional (not collectability) guard: several concurrent async ops issued
# off ONE Element handle, none of which mention it by name in their own
# closure -- the exact shape that broke when Element::find/find_all's own
# capture of $s was naively weakened to match the browser-level fix (see the
# report: this regressed 6/14 assertions in t/41-element-read.t). Element's
# fix is instead a single-resolution-point `undef $s` immediately before
# invoking $cb, keeping $s a strong capture for the whole in-flight gap.
{
    my $b = EV::WebKit->new(window=>[300,200]);
    my %g;
    $b->load_html('<div id=d><span class=s>hi</span><span class=s>yo</span></div>', sub {
        my (undef, $lerr) = @_;
        return EV::break if $lerr;
        $b->find('#d', sub {
            my ($d) = @_;
            my $n = 0; my $want = 3;
            my $done = sub { EV::break if ++$n == $want };
            $d->find('span', sub { my ($el) = @_; $g{find} = ref $el; $done->() });
            $d->find_all('span', sub { my ($els) = @_; $g{find_all} = scalar @{ $els || [] }; $done->() });
            $d->tag(sub { $g{tag} = $_[0]; $done->() });
        });
    });
    TWK::run_with_timeout(15);
    is($g{find}, 'EV::WebKit::Element', 'concurrent ops off one Element: find() resolved');
    is($g{find_all}, 2, 'concurrent ops off one Element: find_all() resolved');
    is($g{tag}, 'div', 'concurrent ops off one Element: sibling call (tag) resolved too');
    $b->quit;
}

# The SAME retention, per call rather than per instance. GI never releases a
# GAsyncReadyCallback closure even after it fires, so everything the completion
# still captures is held for the life of the PROCESS. $self was weakened for
# exactly that reason; $cb, the Cancellable and the watchdog timer were not, so
# every async call retained the user's whole callback graph forever -- and
# wait_for/wait_for_js issue one per poll tick.
#
# Measured before the fix: 68 kB/call, growing linearly and never reused.
# After: ~1.9 kB/call and flat (the closure SHELL is GI's and cannot be freed
# from Perl; what the shell HOLDS is ours, and now is).
#
# A canary counted by DESTROY, not RSS: freed Perl SVs go back to perl's own
# arenas rather than to the OS, so RSS cannot tell a leak from a reuse.
{
    package EVWK::Canary;
    our $alive = 0;
    sub new { $alive++; bless {}, shift }
    sub DESTROY { $alive-- }
}
{
    my $lb = EV::WebKit->new(window => [200,150], ephemeral => 1, timeout => 10);
    my $ready = 0;
    $lb->load_html('<p id=p>x</p>', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(20);
    ok($ready, 'premise: the page is loaded');

    my $N = 25;
    for my $which (
        ['script',     sub { my $cb = shift; $lb->script('return 1;', $cb) }],
        ['find',       sub { my $cb = shift; $lb->find('#p', $cb) }],
        ['cookies',    sub { my $cb = shift; $lb->cookies('http://x/', $cb) }],
        ['frames',     sub { my $cb = shift; $lb->frames($cb) }],
    ) {
        my ($name, $call) = @$which;
        local $EVWK::Canary::alive = 0;
        my $done = 0;
        for (1 .. $N) {
            my $canary = EVWK::Canary->new;
            $call->(sub { my $keep = $canary; $done++; EV::break if $done == $N });
        }
        TWK::run_with_timeout(40);
        is($done, $N, "$name: all $N callbacks fired");
        is($EVWK::Canary::alive, 0,
           "$name: nothing the callbacks closed over is still held afterwards")
            or diag("$EVWK::Canary::alive of $N retained -- the GI completion closure is holding them");
    }
    $lb->quit;
}

done_testing;
