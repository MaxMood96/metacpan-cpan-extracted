use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use Curl::Impersonate;

# local server: any path but /final -> 302 to /final (with 302-only headers);
# /final -> 200 with a different Content-Type. Exercises follow_redirects.
socket(my $srv, PF_INET, SOCK_STREAM, 0) or die "socket: $!";
setsockopt($srv, SOL_SOCKET, SO_REUSEADDR, 1);
bind($srv, sockaddr_in(0, inet_aton('127.0.0.1'))) or die "bind: $!";
listen($srv, 5) or die "listen: $!";
my $port = (sockaddr_in(getsockname($srv)))[0];
my $pid = fork // die "fork: $!";
if (!$pid) {
    for (1 .. 4) {
        accept(my $c, $srv) or last;
        my $req = ''; while (index($req, "\r\n\r\n") < 0) { sysread($c, my $b, 4096) or last; $req .= $b }
        my ($path) = $req =~ m{^\S+\s+(\S+)};
        if (($path // '') =~ m{/final}) {
            my $body = '{"ok":1}';
            syswrite($c, "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n"
                       . "Content-Length: " . length($body) . "\r\nConnection: close\r\n\r\n$body");
        } else {
            syswrite($c, "HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Type: text/html\r\n"
                       . "Set-Cookie: hop=1\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        }
        close $c;
    }
    exit 0;
}
close $srv;

my $c = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10, follow_redirects => 1);
my $r = $c->get("http://127.0.0.1:$port/start");

is($r->{status}, 200, 'followed the 302 to the final 200');
# the result must carry ONLY the final response's headers, not the 302 hop merged in
is($r->{headers}{'content-type'}, 'application/json',
   'content-type is the final scalar (not an arrayref merged with the 302 text/html)');
ok(!ref $r->{headers}{'content-type'}, 'content-type is a scalar, not an arrayref');
ok(!exists $r->{headers}{location},     'the 302-only Location did not leak into the final headers');
ok(!exists $r->{headers}{'set-cookie'}, 'the 302-only Set-Cookie did not leak into the final headers');

kill 'TERM', $pid; waitpid($pid, 0);
done_testing;
