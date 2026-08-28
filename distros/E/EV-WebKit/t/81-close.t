use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();

# Children must load the same lib the parent was told to use: under `make
# test` that is blib, under a mutation check some copy in /tmp. A hardcoded
# -Ilib made the child quietly test a different tree -- or, run from a
# directory without one, the INSTALLED module.
my $EVWK_INC = join ' ', map { my $p = $_; $p =~ s/'/'\\''/g; "-I'$p'" }
                        grep { !ref && length } @INC;   # shell-quoted: a path with a space would otherwise split into broken flags

use Scalar::Util qw(weaken);
use File::Temp qw(tempdir);
use EV; use EV::WebKit;

# The USER closing the window (titlebar X, alt-F4, the window manager) is a real
# event the module simply never handled: the instance kept running with no
# window, every in-flight callback dangled, the natives leaked, and the caller's
# EV::run went on spinning over nothing. It only bites the VISIBLE mode (a real
# display, usually chrome => 1) -- which is exactly why a headless test suite
# never saw it, and why it survived every review round.
#
# Gtk4::Window::close() is the same path the window manager takes (it emits
# close-request); ->destroy(), which quit() uses, does not.

my $dir = tempdir(CLEANUP => 1);

# 1) Closing the window tears the instance down: in-flight callbacks resolve
#    with 'browser closed', and on_close is told -- after, not instead.
{
    my (@errs, $closed, $order);
    my $b;
    $b = EV::WebKit->new(window => [300,200], ephemeral => 1,
                         on_close => sub { $closed++; $order = 'closed-after-flush' if @errs });
    $b->mock_scheme('cl', sub { ('<html><body><div id=x>hi</div></body></html>', 'text/html') });
    my $ready;
    $b->go('cl://p', sub { $ready = 1; EV::break });
    TWK::run_with_timeout(15);
    ok($ready, 'setup: page loaded') or BAIL_OUT('no page');

    $b->script('return 1', sub { push @errs, $_[1] });      # in flight...
    $b->find('#x',        sub { push @errs, $_[1] });       # ...and this one too
    $b->{win}->close;                                        # <-- the user closes the window
    my $wd = EV::timer(5, 0, sub { EV::break }); EV::run; undef $wd;

    is($closed, 1, 'on_close fires exactly once when the user closes the window');
    is(scalar(@errs), 2, '...and every in-flight callback is resolved (not left dangling)');
    is(scalar(grep { ($_ // '') eq 'browser closed' } @errs), 2,
        "...each with 'browser closed'");
    is($order, 'closed-after-flush', '...with on_close called AFTER the teardown, not instead of it');
    ok($b->{_dead}, '...and the instance is closed');
}

# 2) With NO on_close, closing the window must still tear down cleanly -- the
#    silent-leak case.
{
    my @errs;
    my $wb;
    {
        my $b = EV::WebKit->new(window => [300,200], ephemeral => 1);
        weaken($wb = $b);
        $b->load_html('<p>x</p>', sub { EV::break });
        TWK::run_with_timeout(15);
        $b->script('return 1', sub { push @errs, $_[1] });   # in flight
        $b->{win}->close;
        my $wd = EV::timer(5, 0, sub { EV::break }); EV::run; undef $wd;
        ok($b->{_dead}, 'closing the window quits the instance even with no on_close');
        is(scalar(grep { ($_ // '') eq 'browser closed' } @errs), 1,
            '...still resolving the in-flight callback');
        ok(!defined $b->{win} && !defined $b->{view},
            '...and releasing the native window/view (no leak)');
    }
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
    ok(!defined $wb, '...and the instance is collectable afterwards');
}

# 3) quit() is NOT a user close: it must not fire on_close.
{
    my $closed = 0;
    my $b = EV::WebKit->new(window => [300,200], ephemeral => 1, on_close => sub { $closed++ });
    $b->load_html('<p>x</p>', sub { EV::break });
    TWK::run_with_timeout(15);
    $b->quit;
    for (1 .. 5) { my $t = EV::timer(0.05, 0, sub { EV::break }); EV::run }
    is($closed, 0, 'a programmatic quit() does not fire on_close (it is not a user close)');
}

# 4) on_close is delivered on a CLEAN TICK, so EV::break from it is safe -- that
#    is the whole point of the handler (it is how a visible browser's EV::run
#    returns). close-request fires inside GTK's dispatch frame, so a naive
#    implementation would deliver it there, and an EV::break in a dispatch frame
#    busy-spins the NEXT EV::run forever. Run in a child: an armed wedge SPINS
#    rather than failing (see t/05-wedge-ops.t).
{
    my $script = "$dir/close-break.pl";
    open my $fh, '>', $script or die $!;
    print $fh <<'CHILD';
use v5.10; use strict; use warnings; $| = 1;
use EV; use EV::WebKit;
my $broke = 0;
my $b = EV::WebKit->new(window => [300,200], ephemeral => 1,
                        on_close => sub { $broke = 1; EV::break });   # the documented idiom
$b->load_html('<p>x</p>', sub { EV::break });
my $g = EV::timer(15, 0, sub { EV::break }); EV::run; undef $g;
my $c = EV::timer(0.1, 0, sub { $b->{win}->close });                  # the user closes it
EV::run;                              # must RETURN, via on_close's EV::break
print "BROKE $broke\n";
my $alive = 0;                        # ...and the loop must still be usable
my $t = EV::timer(0.05, 0, sub { $alive = 1; EV::break });
EV::run;
print "WEDGE-FREE\n" if $alive;
CHILD
    close $fh;

    my $out = `timeout -k 5 60 '$^X' $EVWK_INC '$script' 2>/dev/null`;
    my $rc  = $? >> 8;
    like($out, qr/^BROKE 1$/m, "EV::break from on_close returns the caller's EV::run");
    ok($out =~ /^WEDGE-FREE$/m && $rc == 0,
        '...and does not wedge the loop (on_close is delivered on a clean tick)')
        or diag($rc == 124 || $rc == 137
            ? 'child had to be KILLED: on_close was delivered inside GTK dispatch, and the EV::break wedged the loop'
            : "child exit=$rc, output: $out");
}

# 5) on_close fires EXACTLY once even if the window gets several close-requests
#    before the deferred teardown runs -- a double-click on the X, a window
#    manager re-sending the delete, fast Alt-F4. The guard used to be {_dead},
#    which quit() only sets a tick later, so each close-request scheduled its own
#    notification. The native window is still destroyed once regardless; it was
#    the notification that doubled.
{
    my $closes = 0;
    my $b = EV::WebKit->new(window => [200,150], ephemeral => 1, on_close => sub { $closes++ });
    $b->load_html('<p>x</p>', sub { EV::break });
    TWK::run_with_timeout(15);
    $b->{win}->close for 1 .. 3;                 # three close-requests, one tick
    my $wd = EV::timer(2, 0, sub { EV::break }); EV::run; undef $wd;
    is($closes, 1, 'on_close fires exactly once for repeated close-requests in one tick')
        or diag("fired $closes times");
}

done_testing;
