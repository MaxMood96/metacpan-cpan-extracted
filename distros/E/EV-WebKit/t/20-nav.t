use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my $b = EV::WebKit->new(window => [400,300]);
my ($title, $err, $html, $html_err, $html_ret);
$b->load_html('<html><head><title>Hi</title></head><body><p>ok</p></body></html>', sub {
    (undef, $err) = @_;
    $title = $b->title;
    $html_ret = $b->html(sub {
        ($html, $html_err) = @_;
        EV::break;
    });
});
TWK::run_with_timeout(10);
is($err, undef, 'no nav error');
is($title, 'Hi', 'title read after load');
is($html_ret, $b, 'html returns $b');
is($html_err, undef, 'no html error');
like($html, qr{<p>ok</p>}, 'html contains body markup');
like($html, qr{^<html}i, 'html starts with <html');

# The title above is available because _finish_nav waits for it -- and WHICH arm
# of that wait delivered it is the point. It races notify::title against a
# deadline; a deadline alone makes the guarantee only as good as the guess, and
# a machine under load beats it. So assert the NOTIFICATION resolved it, by
# requiring the callback well inside the deadline: a regression to deadline-only
# still produces the right title here (just NAV_SETTLE_DELAY later), so the
# elapsed time is the only thing that can catch it.
{
    my $deadline = EV::WebKit::NAV_SETTLE_DELAY();
    my $b2 = EV::WebKit->new(window => [400,300]);
    my ($fin, $settled);
    $b2->{view}->signal_connect('load-changed' => sub {
        $fin = EV::time if "$_[1]" =~ /finish/i });
    $b2->load_html('<html><head><title>Race</title></head><body>x</body></html>', sub {
        $settled = EV::time; EV::break });
    TWK::run_with_timeout(20);
    my $took = (defined $fin && defined $settled) ? $settled - $fin : undef;
    is($b2->title, 'Race', 'the title is there in the callback');
    ok(defined $took, 'the load finished and settled') or diag('never saw both events');
    cmp_ok($took, '<', $deadline / 2,
           sprintf('...delivered by notify::title, not by waiting out the %.0fms deadline', $deadline * 1000))
        or diag(sprintf('settled %.1fms after finished -- the deadline arm did this', ($took // -1) * 1000));
    $b2->quit;
}

done_testing;
