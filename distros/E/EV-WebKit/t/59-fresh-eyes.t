use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();

# Children must load the same lib the parent was told to use: under `make
# test` that is blib, under a mutation check some copy in /tmp. A hardcoded
# -Ilib made the child quietly test a different tree -- or, run from a
# directory without one, the INSTALLED module.
my $EVWK_INC = join ' ', map { my $p = $_; $p =~ s/'/'\\''/g; "-I'$p'" }
                        grep { !ref && length } @INC;   # shell-quoted: a path with a space would otherwise split into broken flags

use File::Temp qw(tempdir);
use EV; use EV::WebKit;

my $dir = tempdir(CLEANUP => 1);

# 1) A mock_scheme producer runs inside WebKit's dispatch frame, exactly like
#    on_dialog/on_policy/on_console -- so quit() must defer its teardown there
#    too, or it delivers other ops' callbacks nested in that frame and an
#    EV::break from one of them wedges the next EV::run. The dispatch-frame fix
#    originally covered only the three GLib SIGNAL handlers and missed this one,
#    which is invoked directly from WebKit's C code, while the POD claimed it
#    was covered. Run in a child: an armed wedge spins forever rather than
#    failing (see t/05-wedge-ops.t).
{
    my $script = "$dir/mock-quit.pl";
    open my $fh, '>', $script or die $!;
    print $fh <<'CHILD';
use v5.10; use strict; use warnings; $| = 1;
use EV; use EV::WebKit;
my ($in_producer, $saw, $fired, $err) = (0, 0, 0);
my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
$b->mock_scheme('mq', sub {
    $in_producer = 1;
    $b->quit;                  # <-- from inside WebKit's own dispatch frame
    $in_producer = 0;
    return ('<html><body>hi</body></html>', 'text/html');
});
$b->wait_for('#never', timeout => 30, sub {
    $fired++; $err = $_[1];
    $saw = $in_producer;       # 1 => run nested inside the producer's frame
    EV::break;                 # documented safe here -- and must stay safe
});
$b->go('mq://p', sub { });
my $wd = EV::timer(20, 0, sub { EV::break }); EV::run; undef $wd;
print "FIRED $fired\n";
print "ERR ", ($err // '(undef)'), "\n";
print "NESTED $saw\n";
# The proof: a second, independent EV::run. Under the wedge it never returns.
my $alive = 0;
my $t = EV::timer(0.05, 0, sub { $alive = 1; EV::break });
EV::run;
print "WEDGE-FREE\n" if $alive;
CHILD
    close $fh;

    my $out = `timeout -k 5 60 '$^X' $EVWK_INC '$script' 2>/dev/null`;
    my $rc  = $? >> 8;
    like($out, qr/^FIRED 1$/m, 'quit() from a mock_scheme producer resolves the in-flight callback exactly once');
    like($out, qr/^ERR browser closed$/m, "...with 'browser closed'");
    like($out, qr/^NESTED 0$/m, '...but NOT nested inside the producer dispatch frame');
    ok($out =~ /^WEDGE-FREE$/m && $rc == 0,
        'quit() from a mock_scheme producer does not wedge the event loop')
        or diag($rc == 124 || $rc == 137
            ? 'child had to be KILLED: the loop wedged -- the producer is not marked as a dispatch frame'
            : "child exit=$rc, output: $out");
}

# 2) A producer that throws while serving a SUBRESOURCE must not fail the
#    top-level navigation. The scheme handler serves every request for the
#    scheme -- img/script/iframe included -- and its error path used to resolve
#    the pending nav unconditionally, so a broken image failed a page that had
#    in fact loaded perfectly.
{
    my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
    $b->mock_scheme('sub', sub {
        my $uri = shift;
        die "cannot serve $uri\n" if $uri =~ /broken\.png/;
        return ('<html><body><h1>Real Page</h1><img src="sub://broken.png"></body></html>', 'text/html');
    });
    my ($res, $err, $fired) = (undef, undef, 0);
    $b->go('sub://home', sub { ($res, $err) = @_; $fired++; EV::break });
    TWK::run_with_timeout(20);

    is($fired, 1, 'nav with a failing subresource: callback fired once');
    is($err, undef, '...and did NOT fail: a broken subresource is the page\'s problem, not the navigation\'s')
        or diag("err=" . ($err // '(undef)'));

    my ($h1, $herr);
    $b->script('return document.querySelector("h1").textContent', sub { ($h1, $herr) = @_; EV::break });
    TWK::run_with_timeout(15);
    is($h1, 'Real Page', '...and the page really did load');
    $b->quit;
}

# 2b) ...but a producer that throws on the navigation's OWN document must still
#     fail that navigation -- for EVERY nav type. The subresource check above
#     first gated on the pending nav's target uri, which is undef by design for
#     reload/back/forward (not predictable ahead of the history entry), so those
#     three silently reported SUCCESS while the page showed the error
#     placeholder. The gate is the view's current uri instead, which WebKit has
#     already set to the document being fetched.
{
    my $b = EV::WebKit->new(window => [300,200], ephemeral => 1, timeout => 10);
    my $boom = 0;
    $b->mock_scheme('rl', sub {
        my $uri = shift;
        die "producer boom\n" if $boom && $uri !~ /img/;
        return ('<html><body><h1>ok</h1></body></html>', 'text/html');
    });
    my ($e1, $e2);
    $b->go('rl://one', sub { $e1 = $_[1]; EV::break });
    TWK::run_with_timeout(15);
    is($e1, undef, 'setup: first load succeeds');

    $boom = 1;
    $b->reload(sub { $e2 = $_[1]; EV::break });
    TWK::run_with_timeout(15);
    like($e2 // '', qr/scheme handler error/,
        'reload(): a producer that throws on the document fails the navigation (not a false success)')
        or diag('reported success while the page showed the error placeholder');

    # back()/forward() share reload()'s "no predictable target" shape, but they
    # cannot exercise this path at all: WebKit restores them from session
    # history WITHOUT re-invoking the scheme handler (measured -- the producer
    # is never called, even with enable_page_cache => 0), so a producer throw is
    # unreachable there. An earlier attempt to assert on it was really asserting
    # on WebKit's caching, and duly flaked under load. reload() is the case that
    # actually reaches the code, and it is deterministic.
    $b->quit;
}

# 3) settings({user_agent => ...}) must not bypass set_user_agent's validation.
#    user-agent is just another WebKitSettings property, and WebKit silently
#    rejects a value it dislikes (keeps the old one, no exception) -- so this
#    path reported success while the UA never changed.
{
    my $b = EV::WebKit->new(window => [200,150]);
    my $bad = "Mozilla/5.0 caf\x{e9}";                     # byte >= 0x80: WebKit rejects it
    my $before = $b->user_agent;
    my $ok = eval { $b->settings({ user_agent => $bad }); 1 };
    ok(!$ok, 'settings({user_agent => <rejected value>}) croaks, like set_user_agent')
        or diag('reported success while WebKit silently kept the old UA');
    is($b->user_agent, $before, '...and the UA is unchanged');

    my $good = 'EVWebKit-Test/1.0';
    ok(eval { $b->settings({ user_agent => $good }); 1 }, 'settings() still sets a VALID user agent');
    is($b->user_agent, $good, '...and it actually applied');
    $b->quit;
}

# 4) GTK connects to one display per process. A second instance asking for a
#    different one used to be silently ignored -- it came up on the first
#    instance's display, even when the one it asked for did not exist.
{
    my $a = EV::WebKit->new(window => [200,150]);
    my $err = !eval { EV::WebKit->new(window => [200,150], display => ':56789'); 1 };
    ok($err, 'a second instance asking for a DIFFERENT display croaks (not silently ignored)');
    like($@, qr/one display per process/, '...saying why');
    ok(eval { my $c = EV::WebKit->new(window => [200,150], display => $ENV{DISPLAY}); $c->quit; 1 },
        '...while asking for the display already in use is fine');
    $a->quit;
}

# 5) wait_for(visible => 1) does two round-trips: find(), then is_visible() on
#    the handle. A page that churns the matched node between them made the
#    handle stale -- and that was delivered as a terminal error the POD never
#    mentions, instead of being polled through as "not settled yet".
{
    my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
    $b->mock_scheme('churn', sub {
        ('<html><body><div class="target">x</div><script>
            setInterval(function () {
                var t = document.querySelector(".target");
                if (t) { t.remove(); setTimeout(function () {
                    var d = document.createElement("div");
                    d.className = "target"; d.textContent = "x";
                    document.body.appendChild(d);
                }, 2); }
            }, 4);
          </script></body></html>', 'text/html')
    });
    my $ready;
    $b->go('churn://p', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(15);
    ok($ready, 'setup: churning page loaded') or BAIL_OUT('no page');

    my %seen;
    for my $i (1 .. 20) {
        my $err;
        $b->wait_for('.target', visible => 1, timeout => 2, sub { $err = $_[1]; EV::break });
        TWK::run_with_timeout(10);
        $seen{ defined $err ? $err : 'ok' }++;
    }
    is(($seen{'stale element'} // 0) + (scalar grep { /stale/ } keys %seen), 0,
        'wait_for(visible => 1) on a churning page never fails with a stale handle (it polls through it)')
        or diag('outcomes: ' . join(', ', map { "$_=$seen{$_}" } sort keys %seen));
    ok(($seen{ok} // 0) >= 15, '...and still resolves normally most of the time')
        or diag('outcomes: ' . join(', ', map { "$_=$seen{$_}" } sort keys %seen));
    $b->quit;
}

# 6) A bare DROP from inside a dispatch frame must not wedge either. quit()
#    defers its teardown when called from a handler -- but DESTROY cannot defer
#    (a strong ref to a refcount-0 object resurrects a corpse), so it tears down
#    in place, with the frame still on the stack. Releasing the natives there is
#    unavoidable; running the flushed CALLBACKS there is not, and an EV::break
#    from one of them wedges the loop exactly as an explicit quit() used to.
{
    my $script = "$dir/destroy-in-dispatch.pl";
    open my $fh, '>', $script or die $!;
    print $fh <<'CHILD';
use v5.10; use strict; use warnings; $| = 1;
use EV; use EV::WebKit;
my ($in_dialog, $saw, $fired) = (0, 0, 0);
# Count DESTROYs. TWO independent guards stop the teardown taking a fresh strong
# ref to this refcount-0 object -- DESTROY's {_destroying} flag, and _flush_later
# capturing only the callbacks, never $self. Remove either and the instance is
# RESURRECTED and destroyed twice. (Safe to wrap: DESTROY is a plain Perl sub,
# NOT a GI-generated method -- redefining one of those recurses forever.)
my $destroys = 0;
{
    no warnings 'redefine';
    my $orig = \&EV::WebKit::DESTROY;
    *EV::WebKit::DESTROY = sub { $destroys++; $orig->(@_) };
}
our $HOLD;                   # the ONLY strong reference to the browser
$HOLD = EV::WebKit->new(window => [300,200], ephemeral => 1, on_dialog => sub {
    my $d = shift;
    $in_dialog = 1;
    undef $HOLD;             # drop it -> refcount 0 -> DESTROY -> quit, in-frame
    $in_dialog = 0;
    $d->dismiss;
});
$HOLD->mock_scheme('dq', sub { ('<html><body><script>confirm("x")</script>hi</body></html>', 'text/html') });
$HOLD->wait_for('#never', timeout => 30, sub {
    $fired++;
    $saw = $in_dialog;       # 1 => run nested inside the dialog frame
    EV::break;
});
$HOLD->go('dq://p', sub { });
my $wd = EV::timer(20, 0, sub { EV::break }); EV::run; undef $wd;
print "FIRED $fired\n";
print "NESTED $saw\n";
my $alive = 0;
my $t = EV::timer(0.05, 0, sub { $alive = 1; EV::break });
EV::run;
print "WEDGE-FREE\n" if $alive;
print "DESTROYS $destroys\n";
CHILD
    close $fh;

    my $out = `timeout -k 5 60 '$^X' $EVWK_INC '$script' 2>/dev/null`;
    my $rc  = $? >> 8;
    like($out, qr/^FIRED 1$/m, 'a bare drop inside on_dialog still resolves the in-flight callback exactly once');
    like($out, qr/^NESTED 0$/m, '...delivered on a clean tick, not nested in the dialog frame');
    ok($out =~ /^WEDGE-FREE$/m && $rc == 0,
        'a bare drop inside a dispatch frame does not wedge the event loop')
        or diag($rc == 124 || $rc == 137
            ? 'child had to be KILLED: DESTROY tore down in place and flushed the callbacks inside the frame'
            : "child exit=$rc, output: $out");
    like($out, qr/^DESTROYS 1$/m,
        '...and the instance is destroyed exactly ONCE (the teardown never resurrects it)')
        or diag('DESTROY ran more than once: something took a strong reference to a refcount-0 object');
}

# 7) on_error is the ONLY notification a callback-less navigation failure ever
#    gets, and it is in no registry -- so nothing flushes it at quit(). Through
#    _defer it was hostage to the instance outliving the tick: a browser quit or
#    dropped in that gap swallowed the failure entirely, silently.
#    White-box, like t/21's settle-window case: the gap between "the failure was
#    recorded" and "the handler is called" is one tick wide, so drive it directly
#    rather than racing a real page load into it.
{
#    _finish_nav has TWO on_error sites -- a callback-less PENDING nav, and a
#    stray failure with no pending nav at all -- and they are reached by
#    different branches. Cover both, under both a quit() and a bare drop.
    for my $branch ('a callback-less pending nav', 'a stray failure with no pending nav') {
        for my $how ('an explicit quit()', 'a bare drop') {
            my $fired = 0;
            {
                my $b = EV::WebKit->new(window => [200,150], ephemeral => 1,
                                        on_error => sub { $fired++ });
                $b->{pending} = $branch =~ /pending/
                    ? [ undef, undef, 1, 'x://y', 0, undef ]   # in flight, NO callback
                    : undef;                                   # nothing pending: the stray branch
                $b->_finish_nav('boom');    # it fails -> on_error is owed, and deferred
                $b->quit if $how =~ /quit/; # <-- land in the gap, before the tick runs
            }                                # (for the bare drop, going out of scope here IS the drop)
            for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
            is($fired, 1, "on_error still fires for $branch when $how lands in the delivery gap")
                or diag('the only notification that navigation failed was silently swallowed');
        }
    }
}

# 8) A leftover superseded identity must not poison the NEXT navigation. While a
#    nav has not committed a uri yet, _finished_is_stray consults {_superseded}
#    to tell a stray tail signal from a legitimate no-commit (bfcache-shaped)
#    'finished'. An entry that is never consumed -- WebKit simply not delivering
#    a signal it looked like it owed -- would then make a LATER, unrelated nav's
#    own legitimate finished look stray, swallowing it: that nav hangs until its
#    full timeout. _start_nav wipes the set on every nav for exactly that reason.
{
    my $b = EV::WebKit->new(window => [200,150], ephemeral => 1);
    $b->mock_scheme('sp', sub { ('<html><body>x</body></html>', 'text/html') });

    $b->{_superseded} = { 'sp://old' => 1 };      # a stale identity from an earlier nav
    $b->go('sp://new', sub { EV::break });        # _start_nav must wipe it, synchronously
    is(scalar(keys %{ $b->{_superseded} }), 0,
        'a new navigation clears any leftover superseded identity')
        or diag('a stale entry survived into this nav: ' . join(',', keys %{ $b->{_superseded} }));
    TWK::run_with_timeout(15);

    # ...which is what keeps this nav's own uncommitted 'finished' from being
    # mistaken for a stray one and swallowed.
    $b->{pending} = [ undef, undef, 99, 'sp://three', 1, undef ];   # started, not yet committed
    is($b->_finished_is_stray('sp://three'), 0,
        "...so its own 'finished' is not swallowed as stray (which would hang it to timeout)");
    delete $b->{pending};
    $b->quit;
}

# A $DISPLAY that is SET but cannot be opened used to kill the process:
# Gtk4::init() calls exit(1) on a display it cannot reach, which is not a Perl
# exception, so eval could not see it and nothing after new() ran. That is the
# common shape -- a cron job or unit carrying DISPLAY=:0, a detached ssh
# session, an xvfb-run whose server has gone, a typo in display => ':1'.
# Gtk4::init_check() returns false instead, so it is a clean die now.
#
# In a CHILD, and with its own display value, because GTK initialises once per
# process and this file has already done so.
{
    my $inc = join ' ', map { my $p = $_; $p =~ s/'/'\\''/g; "-I'$p'" } @INC;
    my $prog = 'use EV; use EV::WebKit; '
             . 'my $b = eval { EV::WebKit->new(window => [200,150]) }; '
             . 'print $@ ? "CAUGHT\n" : "BUILT\n"; '
             . 'print "SURVIVED\n";';
    # NOT a hardcoded :99 -- `xvfb-run -a` allocates from 99 upward, so on CI
    # that display is the LIVE one and the child connects to it happily. Pick a
    # number with neither an X socket nor a lock file, so it is genuinely dead.
    my $dead;
    for my $n (reverse 300 .. 400) {
        next if -e "/tmp/.X11-unix/X$n" || -e "/tmp/.X$n-lock";
        $dead = ":$n";
        last;
    }
    ok($dead, 'premise: found a display number nothing is serving')
        or diag('every candidate had an X socket or lock');

    for my $case (['dead display', $dead], ['unset display', undef]) {
        my ($name, $disp) = @$case;
        SKIP: { skip 'no dead display number available', 3
                    if $name eq 'dead display' && !defined $disp; }
        next if $name eq 'dead display' && !defined $disp;
        my $env = defined $disp ? "DISPLAY='$disp'" : '-u DISPLAY';
        my $out = `env $env '$^X' $inc -e '$prog' 2>&1`;
        my $sig = $? & 127;
        is($sig, 0, "$name: new() does not kill the process with a signal")
            or diag("died on signal $sig");
        like($out, qr/^CAUGHT$/m, "$name: it is a catchable die");
        like($out, qr/^SURVIVED$/m, "$name: and the program keeps running");
    }
}

done_testing;
