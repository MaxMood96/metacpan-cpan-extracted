use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use Curl::Impersonate;

# A local plain-HTTP origin (fork) to exercise header/body edge cases without
# the network. curl-impersonate applies its headers to http:// too.
socket(my $srv, PF_INET, SOCK_STREAM, 0) or die "socket: $!";
setsockopt($srv, SOL_SOCKET, SO_REUSEADDR, 1);
bind($srv, sockaddr_in(0, inet_aton('127.0.0.1'))) or die "bind: $!";
listen($srv, 5) or die "listen: $!";
my $port = (sockaddr_in(getsockname($srv)))[0];

my $pid = fork // die "fork: $!";
if (!$pid) {
    for (1..6) {
        accept(my $c, $srv) or last;
        my $req = '';
        while (index($req, "\r\n\r\n") < 0) { sysread($c, my $b, 4096) or last; $req .= $b }
        my ($path) = $req =~ m{^\S+\s+(\S+)};
        if (($path // '') =~ /204/) {
            syswrite($c, "HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n");
        } else {
            my $body = 'hello';
            syswrite($c, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n"
                . "Set-Cookie: a=1\r\nSet-Cookie: b=2\r\nSet-Cookie: c=3\r\n"
                . "Content-Length: " . length($body) . "\r\nConnection: close\r\n\r\n$body");
        }
        close $c;
    }
    exit 0;
}
close $srv;

# bodyless response (204): on_headers must still fire (streaming) -- finding A
{
    my $m = Curl::Impersonate->multi;
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    my ($status, $got_headers, $body_calls, $done);
    $m->add_streaming($h, { url => "http://127.0.0.1:$port/status/204" }, {
        on_headers => sub { $status = $_[0]; $got_headers = 1 },
        on_body    => sub { $body_calls++; 0 },
        on_done    => sub { $done = 1 },
    });
    $m->perform_blocking;
    ok($got_headers, 'on_headers fires for a bodyless (204) response');
    is($status, 204, 'the 204 status reached on_headers');
    ok(!$body_calls, 'on_body not called for a bodyless response');
    ok($done, 'on_done fired');
}

# multiple Set-Cookie preserved as an arrayref -- finding C
{
    my $c = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 10);
    my $r = $c->get("http://127.0.0.1:$port/cookies");
    my $sc = $r->{headers}{'set-cookie'};
    is(ref $sc, 'ARRAY', 'repeated Set-Cookie kept as an arrayref');
    is_deeply($sc, ['a=1', 'b=2', 'c=3'], 'all Set-Cookie values preserved')
        if ref $sc eq 'ARRAY';
    is($r->{headers}{'content-type'}, 'text/plain', 'a single-valued header stays a scalar');
}

# A CR or LF in a caller-supplied header value would split the request: libcurl
# passes the line through verbatim, so the origin sees an extra header. These
# croak before anything reaches the wire.
{
    my $h = Curl::Impersonate->new(impersonate => 'chrome131', timeout => 3);
    for my $case (['CRLF in a value', "good\r\nX-Injected: yes"],
                  ['LF in a value',   "a\nb"],
                  ['NUL in a value',  "a\0b"]) {
        my ($what, $val) = @$case;
        my $sent = eval { $h->request(url => "http://127.0.0.1:$port/x",
                                      headers => { 'X-Test' => $val }); 1 };
        ok(!$sent, "$what is rejected");
        like($@, qr/contains CR, LF or NUL/, "...with a message naming why")
            if !$sent;
    }
    my $sent = eval { $h->request(url => "http://127.0.0.1:$port/x",
                                  headers => { "X-Bad\r\nX-Evil" => '1' }); 1 };
    ok(!$sent, 'CRLF in a header NAME is rejected too');
}

kill 'TERM', $pid; waitpid($pid, 0);
done_testing;
