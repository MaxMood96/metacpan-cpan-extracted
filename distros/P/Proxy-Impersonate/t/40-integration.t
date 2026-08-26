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

# --- a local self-signed HTTPS origin that replies "PROXIED<...>" (no
#     Content-Length: the body is delimited by connection close) ---
my $origin_cert = Proxy::Impersonate::Cert->new(cert_dir => "$tmp/origin");
socket(my $osrv, PF_INET, SOCK_STREAM, 0) or die "socket: $!";
setsockopt($osrv, SOL_SOCKET, SO_REUSEADDR, 1);
bind($osrv, sockaddr_in(0, inet_aton('127.0.0.1'))) or die "bind: $!";
listen($osrv, 5) or die "listen: $!";
my $origin_port = (sockaddr_in(getsockname($osrv)))[0];
my $body = 'PROXIED-' . ('x' x 5000);   # a few KB so it spans read chunks

my $origin_pid = fork // die "fork: $!";
if (!$origin_pid) {
    my $ctx = Net::SSLeay::CTX_new();
    Net::SSLeay::set_cert_and_key($ctx, $origin_cert->cert_path, $origin_cert->key_path);
    for (1..4) {
        accept(my $cli, $osrv) or last;
        my $ssl = Net::SSLeay::new($ctx);
        Net::SSLeay::set_fd($ssl, fileno($cli));
        if (Net::SSLeay::accept($ssl) > 0) {
            Net::SSLeay::read($ssl);
            Net::SSLeay::write($ssl,
                "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\n$body");
        }
        Net::SSLeay::free($ssl); close $cli;
    }
    exit 0;
}
close $osrv;

# --- the proxy in this process's EV loop (verify=>0: origin is self-signed) ---
my $proxy = Proxy::Impersonate->new(
    impersonate => 'chrome131', listen => '127.0.0.1:0',
    cert_dir => "$tmp/proxy", verify => 0, timeout => 20,
);
my $proxy_port = $proxy->port;
my $result = "$tmp/result";

# --- a blocking client (child): CONNECT through the proxy, GET, save response ---
my $client_pid = fork // die "fork: $!";
if (!$client_pid) {
    socket(my $s, PF_INET, SOCK_STREAM, 0) or die $!;
    connect($s, sockaddr_in($proxy_port, inet_aton('127.0.0.1'))) or die "connect: $!";
    my $auth = "127.0.0.1:$origin_port";
    syswrite($s, "CONNECT $auth HTTP/1.1\r\nHost: $auth\r\n\r\n");
    my $hdr = '';
    while (index($hdr, "\r\n\r\n") < 0) { sysread($s, my $b, 1024) or last; $hdr .= $b }
    my $ctx = Net::SSLeay::CTX_new();
    my $ssl = Net::SSLeay::new($ctx);
    Net::SSLeay::set_fd($ssl, fileno($s));
    Net::SSLeay::connect($ssl) > 0 or do { _save($result, "TLS-FAIL"); exit 0 };
    Net::SSLeay::write($ssl, "GET /hello HTTP/1.1\r\nHost: $auth\r\nAccept: */*\r\n\r\n");
    my $resp = '';
    while (1) {
        my ($d, $rv) = Net::SSLeay::read($ssl, 16384);
        if (defined $rv && $rv > 0) { $resp .= $d; next }
        last;
    }
    _save($result, $resp);
    exit 0;
}

# --- run EV until the client exits (or a timeout) ---
my $cw = EV::child($client_pid, 0, sub { EV::break() });
my $tw = EV::timer(30, 0, sub { EV::break() });
EV::run();

waitpid($client_pid, 0);
kill 'TERM', $origin_pid; waitpid($origin_pid, 0);

my $resp = do { local $/; open my $f, '<', $result or die "no result: $!"; <$f> };
ok(defined $resp && length $resp, 'client got a response through the proxy');
like($resp, qr!\AHTTP/1\.1 200 OK!, 'proxied 200 status line');
like($resp, qr/\r\n\r\nPROXIED-x/, 'origin body relayed through the proxy');
ok(length($resp) > 5000, 'full multi-chunk body streamed back');
unlike($resp, qr/content-length/i, 'unknown-length response delimited by close');
like($resp, qr/connection: close/i, 'proxy added Connection: close for the close-delimited body');

done_testing;

sub _save { my ($path, $data) = @_; open my $f, '>', $path or die $!; print $f $data; close $f }
