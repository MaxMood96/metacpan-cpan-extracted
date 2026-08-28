use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# Regression for the EV::Glib wedge:
# a GIO/GI async completion (or GLib signal callback) that calls EV::break
# synchronously unwinds out of ev_run while still nested in the glib dispatch
# frame that EV::Glib bridges into EV. This corrupts EV::Glib's prepare/check
# bookkeeping and wedges every SUBSEQUENT EV::run into a permanent 100%-CPU
# spin (gdb-confirmed: main thread parks at one PC inside ev_run, no watcher
# -- not even an unrelated native EV::timer -- ever fires again). It's
# invisible to every single-EV::run test in this suite; it only bites real
# "loop, do work, loop again" usage. Empirically, ~13 sequential
# _call_js/script() round-trips in one EV::run reliably arms it before a
# second EV::run; this test does 20 to leave margin.
#
# NOTE: if this ever hangs instead of failing, it must be re-run wrapped in a
# shell `timeout` (e.g. `timeout 90 xvfb-run -a perl -Ilib t/45-lifecycle.t`)
# -- an unfixed wedge spins forever and even TWK::run_with_timeout's own
# failsafe EV::timer cannot fire during the spin.

my $N = 20;   # comfortably above the ~13-call threshold that arms the wedge pre-fix

my $b = EV::WebKit->new(window=>[200,150]);
my $n = 0;
$b->load_html('<p id=p>hi</p>', sub {
    my (undef, $err) = @_;
    return fail("load_html failed: $err") if $err;
    my $chain; $chain = sub {
        $b->script('return 1', sub {
            my ($v, $err) = @_;
            return fail("script round-trip #$n failed: $err") if $err;
            $n++;
            if ($n >= $N) { EV::break }             # ends EV::run #1 from deep inside a chain
            else          { $chain->() }
        });
    };
    $chain->();
});
TWK::run_with_timeout(20);
is($n, $N, "first EV::run: $N sequential _call_js round-trips completed (each callback ended in EV::break-reachable code)");

# A second, fully independent EV::run. Pre-fix, this spins at 100% CPU forever
# instead of ever reaching the is() below.
my $r2;
$b->script('return 40+2', sub {
    my ($v, $err) = @_;
    $r2 = $v;
    EV::break;
});
TWK::run_with_timeout(20);
is($r2, 42, 'second, independent EV::run completes -- no EV::Glib wedge');

$b->quit;
done_testing;
