use v5.10; use strict; use warnings;
use Test::More;
use Curl::Impersonate;
plan skip_all => 'network fingerprint test; set CI_LIVE=1 to run' unless $ENV{CI_LIVE};

my $c = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 20);
my $r = $c->get('https://tls.peet.ws/api/all');
is($r->{status}, 200, 'fingerprint endpoint reachable') or diag($r->{error} // '');
my ($ja4) = ($r->{body} // '') =~ /"ja4":\s*"([^"]+)"/;
ok($ja4, "got a ja4 ($ja4)");
like($ja4, qr/^t13d/, 'JA4 is a TLS 1.3 client (Chrome-shaped)');
like($r->{body}, qr/"akamai_fingerprint":\s*"[^"]/, 'HTTP/2 (Akamai) fingerprint present');
like($r->{body}, qr/"user_agent":\s*"[^"]*Chrome/, 'the Chrome default UA was applied');
# response plumbing
is($r->{headers}{'content-type'}, 'application/json', 'response headers parsed + lowercased');
ok(length($r->{body}) > 100, 'body captured');
done_testing;
