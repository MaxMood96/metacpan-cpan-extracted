use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;

my @msgs;
my $b = EV::WebKit->new(window=>[300,200], on_console => sub { push @msgs, $_[0] });
my $flush_timer;
$b->load_html('<script>console.log("hi"); console.warn("careful"); console.error("oops")</script>', sub {
    $flush_timer = EV::timer(0.05, 0, sub { EV::break });   # let messages flush
});
TWK::run_with_timeout(10);
ok((grep { /hi/ } @msgs), 'captured console.log');
ok((grep { /careful/ } @msgs), 'captured console.warn');
ok((grep { /oops/ } @msgs), 'captured console.error');
done_testing;
