use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use File::Temp qw(tempdir);
use Net::SSLeay ();
plan skip_all => 'integration test; set PROXY_IT=1 to run' unless $ENV{PROXY_IT};
require EV;
require Proxy::Impersonate;
require Proxy::Impersonate::Cert;

Net::SSLeay::initialize();
my $tmp = tempdir(CLEANUP => 1);

# a local HTTPS origin with a self-signed cert the proxy does NOT trust
my $origin_cert = Proxy::Impersonate::Cert->new(cert_dir => "$tmp/origin");
socket(my $osrv, PF_INET, SOCK_STREAM, 0) or die $!;
setsockopt($osrv, SOL_SOCKET, SO_REUSEADDR, 1);
bind($osrv, sockaddr_in(0, inet_aton('127.0.0.1'))) or die $!;
listen($osrv, 5) or die $!;
my $origin_port = (sockaddr_in(getsockname($osrv)))[0];
my $opid = fork // die $!;
if (!$opid) {
    my $ctx = Net::SSLeay::CTX_new();
    Net::SSLeay::set_cert_and_key($ctx, $origin_cert->cert_path, $origin_cert->key_path);
    for (1..3) {
        accept(my $c, $osrv) or last;
        my $ssl = Net::SSLeay::new($ctx); Net::SSLeay::set_fd($ssl, fileno($c));
        if (Net::SSLeay::accept($ssl) > 0) {
            Net::SSLeay::read($ssl);
            Net::SSLeay::write($ssl, "HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\nSECRET");
        }
        Net::SSLeay::free($ssl); close $c;
    }
    exit 0;
}
close $osrv;

# proxy with the SECURE default (verify => 1): the untrusted origin must be rejected
my $proxy = Proxy::Impersonate->new(impersonate => 'chrome131',
    listen => '127.0.0.1:0', cert_dir => "$tmp/proxy");   # verify defaults to 1
my $result = "$tmp/r";
my $cpid = fork // die $!;
if (!$cpid) {
    socket(my $s, PF_INET, SOCK_STREAM, 0);
    setsockopt($s, SOL_SOCKET, SO_RCVTIMEO, pack('l!l!', 20, 0));
    connect($s, sockaddr_in($proxy->port, inet_aton('127.0.0.1')));
    my $auth = "127.0.0.1:$origin_port";
    syswrite($s, "CONNECT $auth HTTP/1.1\r\nHost: $auth\r\n\r\n");
    my $h = ''; while (index($h, "\r\n\r\n") < 0) { sysread($s, my $b, 1024) or last; $h .= $b }
    my $ctx = Net::SSLeay::CTX_new(); my $ssl = Net::SSLeay::new($ctx);
    Net::SSLeay::set_fd($ssl, fileno($s));
    Net::SSLeay::connect($ssl) > 0 or do { _save($result, 'TLS-FAIL'); exit 0 };
    Net::SSLeay::write($ssl, "GET / HTTP/1.1\r\nHost: $auth\r\n\r\n");
    my $buf = ''; while (1) { my ($d, $rv) = Net::SSLeay::read($ssl, 8192); last if !defined $rv || $rv <= 0; $buf .= $d }
    _save($result, $buf); exit 0;
}
my $cw = EV::child($cpid, 0, sub { EV::break() });
my $tw = EV::timer(30, 0, sub { EV::break() });
EV::run();
waitpid($cpid, 0); kill 'TERM', $opid; waitpid($opid, 0);

my $resp = do { local $/; open my $f, '<', $result or die; <$f> };
like($resp, qr!\AHTTP/1\.1 502!, 'verify=>1 rejects the untrusted origin with 502');
unlike($resp, qr/SECRET/, 'the origin body is NOT relayed when the cert is untrusted');
done_testing;

sub _save { my ($p, $d) = @_; open my $f, '>', $p or die; print $f $d; close $f }
