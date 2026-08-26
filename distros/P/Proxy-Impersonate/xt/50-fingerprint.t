use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use File::Temp qw(tempdir);
use Net::SSLeay ();
plan skip_all => 'live fingerprint test; set CI_LIVE=1 to run' unless $ENV{CI_LIVE};
require EV;
require Proxy::Impersonate;

Net::SSLeay::initialize();
my $tmp = tempdir(CLEANUP => 1);

# proxy re-originates upstream as chrome131 (verify ON: tls.peet.ws is real)
my $proxy = Proxy::Impersonate->new(
    impersonate => 'chrome131', listen => '127.0.0.1:0',
    cert_dir => "$tmp/proxy", verify => 1, timeout => 25,
);
my $proxy_port = $proxy->port;
my $result = "$tmp/result";

my $client_pid = fork // die "fork: $!";
if (!$client_pid) {
    socket(my $s, PF_INET, SOCK_STREAM, 0) or die $!;
    setsockopt($s, SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 25, 0));   # never hang
    connect($s, sockaddr_in($proxy_port, inet_aton('127.0.0.1'))) or die "connect: $!";
    syswrite($s, "CONNECT tls.peet.ws:443 HTTP/1.1\r\nHost: tls.peet.ws:443\r\n\r\n");
    my $h = '';
    while (index($h, "\r\n\r\n") < 0) { sysread($s, my $b, 1024) or last; $h .= $b }
    my $ctx = Net::SSLeay::CTX_new();
    my $ssl = Net::SSLeay::new($ctx);
    Net::SSLeay::set_fd($ssl, fileno($s));
    Net::SSLeay::connect($ssl) > 0 or do { _save($result, "TLS-FAIL"); exit 0 };
    Net::SSLeay::write($ssl,
        "GET /api/all HTTP/1.1\r\nHost: tls.peet.ws\r\nAccept: */*\r\n\r\n");
    my $buf = '';
    while (index($buf, "\r\n\r\n") < 0) {
        my ($d, $rv) = Net::SSLeay::read($ssl, 4096);
        last if !defined $rv || $rv <= 0; $buf .= $d;
    }
    my $end = index($buf, "\r\n\r\n") + 4;
    my ($clen) = $buf =~ /content-length:\s*(\d+)/i;
    if (defined $clen) {
        while (length($buf) - $end < $clen) {
            my ($d, $rv) = Net::SSLeay::read($ssl, 16384);
            last if !defined $rv || $rv <= 0; $buf .= $d;
        }
    } else {
        while (1) {
            my ($d, $rv) = Net::SSLeay::read($ssl, 16384);
            last if !defined $rv || $rv <= 0; $buf .= $d;
        }
    }
    _save($result, $buf);
    exit 0;
}

my $cw = EV::child($client_pid, 0, sub { EV::break() });
my $tw = EV::timer(40, 0, sub { EV::break() });
EV::run();
waitpid($client_pid, 0);

my $resp = do { local $/; open my $f, '<', $result or die "no result: $!"; <$f> };
like($resp, qr!\AHTTP/1\.1 200!, 'proxied 200 from tls.peet.ws');
my ($ja4) = $resp =~ /"ja4":\s*"([^"]+)"/;
ok($ja4, "origin reported a JA4 ($ja4)");
like($ja4, qr/^t13d/, 'JA4 is Chrome-shaped (TLS 1.3 client), not the proxy Net::SSLeay stack');
like($resp, qr/"user_agent":\s*"[^"]*Chrome/, 'the Chrome default UA reached the origin');
like($resp, qr/"akamai_fingerprint":\s*"[^"]/, 'HTTP/2 Akamai fingerprint present at the origin');

done_testing;

sub _save { my ($path, $data) = @_; open my $f, '>', $path or die $!; print $f $data; close $f }
