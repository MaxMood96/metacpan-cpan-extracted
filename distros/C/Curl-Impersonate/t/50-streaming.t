use v5.10; use strict; use warnings;
use Test::More;
use Curl::Impersonate;
plan skip_all => 'network streaming test; set CI_LIVE=1' unless $ENV{CI_LIVE};

# incremental delivery: on_headers once, on_body per chunk, on_done at the end
my $m = Curl::Impersonate->multi;
my ($status, $hdrs, $body, $done, $err, $chunks);
my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 20);
$m->add_streaming($h, { url => 'https://tls.peet.ws/api/clean' }, {
    on_headers => sub { ($status, $hdrs) = @_ },
    on_body    => sub { $body .= $_[0]; $chunks++; return 0 },   # never pause
    on_done    => sub { ($err) = @_; $done = 1 },
});
$m->perform_blocking;
is($status, 200, 'on_headers got status 200');
ok($hdrs && ref $hdrs eq 'HASH', 'on_headers got a headers hashref');
ok($chunks && $chunks >= 1, "on_body fired ($chunks chunk(s))");
ok(length($body) > 10, 'on_body accumulated a body');
ok($done && !$err, 'on_done fired with no error');
like($body, qr/ja3|tls|"tls"/i, 'streamed body is the fingerprint JSON');

# pause/resume: returning truthy from on_body pauses; resume drains the rest.
# (The rigorous byte-exact no-duplication check for the pause-before-consume idiom
# is Proxy::Impersonate's t/44, which drives a 2 MiB body through a real EV loop;
# see the add_streaming POD for the chunk contract.)
my $m2 = Curl::Impersonate->multi;
my ($paused, $got, $fin) = (0, '', 0);
my $h2 = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 20);
$m2->add_streaming($h2, { url => 'https://tls.peet.ws/api/clean' }, {
    on_headers => sub {},
    on_body    => sub { $got .= $_[0]; if (!$paused) { $paused = 1; return 1 } return 0 },
    on_done    => sub { $fin = 1 },
});
# drive a few rounds, then resume once, then finish
for (1..50) { last if $fin; $m2->socket_action(-1, 0); $m2->resume($h2) if $paused && !$fin; }
$m2->perform_blocking;
ok($paused, 'on_body requested a pause');
ok($fin, 'transfer finished after resume');
ok(length($got) > 10, 'body delivered across pause/resume');

done_testing;
