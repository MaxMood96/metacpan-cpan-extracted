use v5.10; use strict; use warnings;
use Test::More;
use Curl::Impersonate;
plan skip_all => 'network async test; set CI_LIVE=1 to run' unless $ENV{CI_LIVE};

my $m = Curl::Impersonate->multi;
my %got;
for my $n (1..3) {
    my $c = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 20);
    $m->add($c, { method => 'GET', url => 'https://tls.peet.ws/api/clean' }, sub {
        my ($res, $err) = @_;
        $got{$n} = $err ? "ERR:$err" : $res->{status};
    });
}
$m->perform_blocking;
is($got{$_}, 200, "request $_ completed") for 1..3;

# an unresolvable host reports an error to the callback, not a status
my $mm = Curl::Impersonate->multi;
my $err;
my $c = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
$mm->add($c, { url => 'https://no.such.host.invalid.example/' }, sub {
    (undef, $err) = @_;
});
$mm->perform_blocking;
ok($err, "dns failure surfaced as an error ($err)");

done_testing;
