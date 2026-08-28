use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

# wait_for must not crash if quit() tears down the browser mid-poll.
my $b = EV::WebKit->new(window=>[200,150]);
my @keep;   # keep the one-shot timers alive (EV watchers GC if unreferenced)
$b->load_html('<p>x</p>', sub {
    $b->wait_for('#never', timeout=>5, sub { });          # polls; selector never appears
    push @keep, EV::timer(0.15, 0, sub { $b->quit });     # tear down mid-poll
    push @keep, EV::timer(0.45, 0, sub { EV::break });    # let post-quit ticks fire
});
TWK::run_with_timeout(8);
pass('no crash when quit() runs during an outstanding wait_for poll');
done_testing;
