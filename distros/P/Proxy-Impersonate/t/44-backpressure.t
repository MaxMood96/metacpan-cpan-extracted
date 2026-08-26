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

# A deterministic 2 MiB body: 262144 eight-byte records, each its own index. A
# duplicated or dropped 16 KiB block (curl's CURL_MAX_WRITE_SIZE, the granularity
# of the pause bug and the SSL-truncation bug) shows up as an out-of-sequence /
# missing record run, not merely a length change -- so a byte-exact compare is a
# precise detector. The body far exceeds HIWAT (256 KiB), so a slow client forces
# many pause/resume cycles.
my $N    = 262144;
my $body = join '', map { sprintf '%08d', $_ } 1 .. $N;
my $blen = length $body;

# --- local self-signed HTTPS origin: sends the whole body with Content-Length ---
my $origin_cert = Proxy::Impersonate::Cert->new(cert_dir => "$tmp/origin");
socket(my $osrv, PF_INET, SOCK_STREAM, 0) or die "socket: $!";
setsockopt($osrv, SOL_SOCKET, SO_REUSEADDR, 1);
bind($osrv, sockaddr_in(0, inet_aton('127.0.0.1'))) or die "bind: $!";
listen($osrv, 5) or die "listen: $!";
my $origin_port = (sockaddr_in(getsockname($osrv)))[0];

my $origin_pid = fork // die "fork: $!";
if (!$origin_pid) {
    my $ctx = Net::SSLeay::CTX_new();
    Net::SSLeay::set_cert_and_key($ctx, $origin_cert->cert_path, $origin_cert->key_path);
    for (1 .. 2) {
        accept(my $cli, $osrv) or last;
        my $ssl = Net::SSLeay::new($ctx);
        Net::SSLeay::set_fd($ssl, fileno($cli));
        if (Net::SSLeay::accept($ssl) > 0) {
            Net::SSLeay::read($ssl);
            Net::SSLeay::write($ssl,
                "HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\n"
              . "Content-Length: $blen\r\n\r\n$body");
        }
        Net::SSLeay::free($ssl); close $cli;
    }
    exit 0;
}
close $osrv;

my $proxy = Proxy::Impersonate->new(
    impersonate => 'chrome131', listen => '127.0.0.1:0',
    cert_dir => "$tmp/proxy", verify => 0, timeout => 30,
);
my $proxy_port = $proxy->port;
my $result = "$tmp/result";

# --- a deliberately SLOW client (child): read 4 KiB at a time with a tiny delay so
#     the proxy's wbuf backs up past HIWAT and the upstream is paused+resumed. ---
my $client_pid = fork // die "fork: $!";
if (!$client_pid) {
    socket(my $s, PF_INET, SOCK_STREAM, 0) or die $!;
    setsockopt($s, SOL_SOCKET, SO_RCVBUF, 4096);      # small: proxy SSL_write blocks fast -> wbuf backs up to HIWAT
    connect($s, sockaddr_in($proxy_port, inet_aton('127.0.0.1'))) or die "connect: $!";
    my $auth = "127.0.0.1:$origin_port";
    syswrite($s, "CONNECT $auth HTTP/1.1\r\nHost: $auth\r\n\r\n");
    my $hdr = ''; while (index($hdr, "\r\n\r\n") < 0) { sysread($s, my $b, 1024) or last; $hdr .= $b }
    my $ctx = Net::SSLeay::CTX_new();
    my $ssl = Net::SSLeay::new($ctx);
    Net::SSLeay::set_fd($ssl, fileno($s));
    Net::SSLeay::connect($ssl) > 0 or do { _save($result, "TLS-FAIL"); exit 0 };
    Net::SSLeay::write($ssl, "GET /big HTTP/1.1\r\nHost: $auth\r\nAccept: */*\r\n\r\n");
    my $resp = '';
    my $want = -1;                                     # total expected bytes, set once headers seen
    while (1) {
        my ($d, $rv) = Net::SSLeay::read($ssl, 4096);
        if (defined $rv && $rv > 0) {
            $resp .= $d;
            $want = index($resp, "\r\n\r\n") + 4 + $blen
                if $want < 0 && index($resp, "\r\n\r\n") >= 0;
            last if $want > 0 && length($resp) >= $want;
            select undef, undef, undef, 0.005;         # slow the drain -> keep wbuf backed up past HIWAT
            next;
        }
        last if defined $rv && $rv == 0;               # EOF
        my $e = Net::SSLeay::get_error($ssl, defined $rv ? $rv : -1);
        last unless $e == Net::SSLeay::ERROR_WANT_READ() || $e == Net::SSLeay::ERROR_WANT_WRITE();
    }
    _save($result, $resp);
    exit 0;
}

my $cw = EV::child($client_pid, 0, sub { EV::break() });
my $tw = EV::timer(90, 0, sub { EV::break() });
EV::run();
waitpid($client_pid, 0);
kill 'TERM', $origin_pid; waitpid($origin_pid, 0);

my $resp = do { local $/; open my $f, '<', $result or die "no result: $!"; <$f> };
my ($rbody) = ($resp // '') =~ /\r\n\r\n(.*)\z/s;
$rbody //= '';
is(length($rbody), $blen,
   "streamed body length is exact ($blen bytes) -- no truncation, no duplicated block");
ok($rbody eq $body,
   'streamed body is byte-identical to the origin under backpressure (no duplicated/dropped 16 KiB block)')
    or diag('first mismatch at byte ' . (first_diff($rbody, $body) // '?'));

done_testing;

sub _save { my ($path, $data) = @_; open my $f, '>', $path or die $!; print $f $data; close $f }
sub first_diff {
    my ($a, $b) = @_;
    my $n = length($a) < length($b) ? length($a) : length($b);
    for (my $i = 0; $i < $n; $i++) { return $i if substr($a, $i, 1) ne substr($b, $i, 1) }
    return length($a) == length($b) ? undef : $n;
}
