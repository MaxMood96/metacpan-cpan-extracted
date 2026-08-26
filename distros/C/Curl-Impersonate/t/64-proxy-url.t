use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use Curl::Impersonate;

# Two local servers: a CONNECT-less HTTP proxy that rewrites nothing but records
# that it was used, and an origin that redirects once. Between them they cover
# the proxy option and the effective url the response reports.
sub listener {
    socket(my $s, PF_INET, SOCK_STREAM, 0) or die "socket: $!";
    setsockopt($s, SOL_SOCKET, SO_REUSEADDR, 1);
    bind($s, sockaddr_in(0, inet_aton('127.0.0.1'))) or die "bind: $!";
    listen($s, 10) or die "listen: $!";
    return ($s, (sockaddr_in(getsockname($s)))[0]);
}
sub slurp_req { my $c = shift; my $r = '';
    while (index($r, "\r\n\r\n") < 0) { sysread($c, my $b, 4096) or last; $r .= $b } $r }

my ($origin, $oport) = listener();
my ($proxy,  $pport) = listener();

my $opid = fork // die "fork: $!";
if (!$opid) {
    for (1 .. 6) {
        accept(my $c, $origin) or last;
        my $req = slurp_req($c);
        my ($path) = $req =~ m{^\S+\s+(\S+)};
        if (($path // '') =~ m{/final}) {
            print $c "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nhi";
        } else {
            print $c "HTTP/1.1 302 Found\r\nLocation: http://127.0.0.1:$oport/final\r\n"
                   . "Content-Length: 0\r\nConnection: close\r\n\r\n";
        }
        close $c;
    }
    exit 0;
}
# Minimal forward proxy: absolute-URI request line, relay to the origin verbatim.
my $ppid = fork // die "fork: $!";
if (!$ppid) {
    for (1 .. 6) {
        accept(my $c, $proxy) or last;
        my $req = slurp_req($c);
        my ($host, $port, $path) = $req =~ m{^\S+\s+http://([^/:]+):(\d+)(\S*)};
        if (!defined $host) { close $c; next }
        socket(my $up, PF_INET, SOCK_STREAM, 0) or next;
        connect($up, sockaddr_in($port, inet_aton($host))) or next;
        $req =~ s{^(\S+)\s+http://[^/]+}{$1 };            # absolute-URI -> origin-form
        $req =~ s{\r\nProxy-Connection:[^\r\n]*}{}i;
        syswrite($up, $req);
        my $resp = ''; while (sysread($up, my $b, 4096)) { $resp .= $b }
        # Stamp every relayed response, so the assertions below fail if the
        # request went direct instead -- which it otherwise would, and still
        # succeed, since the origin is reachable either way.
        $resp =~ s{\r\n}{\r\nX-Proxied: yes\r\n};
        syswrite($c, $resp);
        close $up; close $c;
    }
    exit 0;
}
close $origin; close $proxy;

my $c = Curl::Impersonate->new(
    impersonate      => 'chrome131',
    proxy            => "http://127.0.0.1:$pport",
    follow_redirects => 1,
    timeout          => 15,
);
my $res = $c->get("http://127.0.0.1:$oport/start");

kill 'TERM', $_ for $opid, $ppid;
waitpid $_, 0 for $opid, $ppid;

is($res->{error}, undef, 'request through the proxy succeeded')
    or diag "error=$res->{error} code=$res->{code}";
is($res->{status}, 200, 'got the final status');
is($res->{body}, 'hi', 'got the final body');
is($res->{url}, "http://127.0.0.1:$oport/final",
   'url reports where the request ended up, not where it was aimed');
is($res->{headers}{'x-proxied'}, 'yes', 'the request really went through the proxy');

done_testing;
