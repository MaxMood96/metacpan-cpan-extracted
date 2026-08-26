use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use Curl::Impersonate;

# local plain-HTTP echo origin (returns the request it received in the body)
socket(my $srv, PF_INET, SOCK_STREAM, 0) or die "socket: $!";
setsockopt($srv, SOL_SOCKET, SO_REUSEADDR, 1);
bind($srv, sockaddr_in(0, inet_aton('127.0.0.1'))) or die "bind: $!";
listen($srv, 5) or die "listen: $!";
my $port = (sockaddr_in(getsockname($srv)))[0];
my $pid = fork // die "fork: $!";
if (!$pid) {
    for (1..4) {
        accept(my $c, $srv) or last;
        my $req = ''; while (index($req, "\r\n\r\n") < 0) { sysread($c, my $b, 4096) or last; $req .= $b }
        syswrite($c, "HTTP/1.1 200 OK\r\nContent-Length: " . length($req) . "\r\nConnection: close\r\n\r\n$req");
        close $c;
    }
    exit 0;
}
close $srv;

my $c = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
my $get = $c->get("http://127.0.0.1:$port/");
my $greq = $get->{body} // '';   # the whole body IS the echoed request

# a bodyless GET must not send Content-Type/Content-Length (was: POSTFIELDS=NULL
# left method=POST, so curl emitted them -- a "no browser does this" tell)
unlike($greq, qr/content-type:/i,   'bodyless GET sends no Content-Type');
unlike($greq, qr/content-length:/i, 'bodyless GET sends no Content-Length');
like($greq, qr{^GET /}, 'request is a GET');

# no h2c upgrade headers on cleartext (real Chrome only speaks h2 over TLS/ALPN)
unlike($greq, qr/upgrade:\s*h2c/i, 'cleartext request carries no Upgrade: h2c');
unlike($greq, qr/http2-settings:/i, 'cleartext request carries no HTTP2-Settings');

# a POST with a body still carries them
my $post = $c->request(method => 'POST', url => "http://127.0.0.1:$port/", body => 'x=1');
my $preq = $post->{body} // '';
like($preq, qr/content-length: 3/i, 'a POST with a body keeps Content-Length');

# an empty-body POST still frames Content-Length: 0 (Chrome does; the bodyless
# reset must not strip it for a body-bearing method the way it does for a GET)
my $epost = $c->request(method => 'POST', url => "http://127.0.0.1:$port/", body => '');
my $ereq = $epost->{body} // '';
like($ereq, qr{^POST /}, 'empty-body request is still a POST');
like($ereq, qr/content-length: 0/i, 'an empty-body POST frames Content-Length: 0');

kill 'TERM', $pid; waitpid($pid, 0);
done_testing;
