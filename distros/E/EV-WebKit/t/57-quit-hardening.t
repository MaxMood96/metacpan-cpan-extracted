use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use Scalar::Util qw(weaken);
use EV; use EV::WebKit;

# quit() flushes every in-flight callback. It runs USER code to do that, so it
# must survive that code misbehaving -- and it must not run it in a place where
# running it is unsafe. Both of those were broken.

# 1) A THROWING flushed callback must not take the rest of quit() down with it.
#    The flush loops used to invoke each callback unguarded, so the first die
#    unwound quit() entirely: every sibling callback after it was silently
#    dropped, and the teardown below the loop -- window->destroy included --
#    never ran. {_dead} is set on quit()'s first line, so no later quit() could
#    ever retry: the native window, view, web+network processes, context and
#    session leaked for the life of the process. Under a bare drop (DESTROY
#    evals quit) it happened in complete silence.
{
    my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
    my ($second, $third) = (0, 0);
    $b->script('1+1', sub { die "boom from the first callback\n" });   # {_ops}
    $b->script('2+2', sub { $second++ });                              # {_ops}
    $b->wait_for('#never', timeout => 30, sub { $third++ });           # {_waiters}

    my @warns;
    my $quit_died = do {
        local $SIG{__WARN__} = sub { push @warns, $_[0] };
        !eval { $b->quit; 1 };
    };

    ok(!$quit_died, 'quit() does not throw when a flushed callback dies')
        or diag("quit() died: $@");
    is($second, 1, '...the next callback in the same registry still fires');
    is($third,  1, '...and the other registry is flushed too');
    ok(scalar(grep { /callback died during quit/ } @warns),
        '...the exception is surfaced as a warning, not swallowed');
    ok(!defined $b->{win} && !defined $b->{view} && !defined $b->{session},
        '...and the native teardown still completed (no leaked window/view/session)')
        or diag('teardown was aborted by the die -- and _dead blocks any retry, so it can never happen');
}

# 2) Same, via the bare-drop path (DESTROY -> eval { quit }), where the die was
#    swallowed silently. The instance must still be collectable and torn down.
{
    my $wb;
    {
        my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
        weaken($wb = $b);
        $b->script('1+1', sub { die "boom during DESTROY\n" });
        local $SIG{__WARN__} = sub {};   # the warn is expected; keep the log clean
    }                                    # <- dropped: DESTROY -> quit -> flush -> die
    for (1 .. 3) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
    ok(!defined $wb, 'a throwing callback during DESTROY still collects the instance');
}

# 3) quit() called from INSIDE a WebKit dispatch frame (on_dialog) must not
#    deliver other ops' callbacks nested in that frame. Those callbacks are
#    promised a clean EV tick, and callers are told EV::break is safe there --
#    but an EV::break inside a GLib dispatch frame busy-spins the NEXT EV::run
#    (the lifecycle wedge). The whole teardown is deferred to a clean tick.
{
    my ($in_dialog, $cb_saw_dialog, $cb_err, $fired) = (0, 0);
    my $b;
    $b = EV::WebKit->new(window => [300,200], ephemeral => 1, on_dialog => sub {
        my $d = shift;
        $in_dialog = 1;
        $b->quit;          # <-- from inside WebKit's own dispatch frame
        $in_dialog = 0;
        $d->dismiss;
    });
    $b->mock_scheme('qd', sub { ('<html><body><script>confirm("x")</script>hi</body></html>', 'text/html') });
    $b->wait_for('#never', timeout => 30, sub {
        $fired++;
        $cb_err = $_[1];
        $cb_saw_dialog = $in_dialog;   # 1 => we were run nested inside on_dialog
        EV::break;                     # documented safe here -- and must stay safe
    });
    $b->go('qd://p', sub { });
    my $wd = EV::timer(20, 0, sub { EV::break });
    EV::run; undef $wd;

    is($fired, 1, 'quit() from on_dialog still resolves the in-flight callback exactly once');
    is($cb_err, 'browser closed', "...with 'browser closed'");
    is($cb_saw_dialog, 0, '...but NOT nested inside the dialog dispatch frame')
        or diag('the callback ran inside WebKit dispatch; an EV::break there wedges the next EV::run');

    # The real proof: a fresh, independent EV::run must still work. Under the
    # wedge it never returns -- not even its own timer fires.
    my $alive = 0;
    my $t = EV::timer(0.05, 0, sub { $alive = 1; EV::break });
    EV::run;
    ok($alive, 'the event loop is not wedged afterwards (a later EV::run still runs)');
}

# 4) A throwing on_policy must fail CLOSED. The handler is a gate; if a die
#    escapes it, neither allow() nor block() runs and WebKit applies its own
#    default -- allow. A page able to make the handler die would walk straight
#    through the gate.
{
    my $b = EV::WebKit->new(window => [300,200], ephemeral => 1, timeout => 3,
                            on_policy => sub { die "boom from on_policy\n" });
    my $served = 0;
    $b->mock_scheme('qp', sub { $served++; ('<html><body>through the gate</body></html>', 'text/html') });
    my @warns;
    {
        local $SIG{__WARN__} = sub { push @warns, $_[0] };
        $b->go('qp://p', sub { EV::break });
        my $wd = EV::timer(6, 0, sub { EV::break });
        EV::run; undef $wd;
    }
    is($served, 0, 'a throwing on_policy blocks the navigation (fails closed, not open)')
        or diag('the page was served: a handler that died let the navigation through');
    ok(scalar(grep { /on_policy callback died/ } @warns), '...and says so');
    $b->quit;
}

done_testing;
