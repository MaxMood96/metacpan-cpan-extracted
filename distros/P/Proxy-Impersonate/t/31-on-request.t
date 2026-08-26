use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use Proxy::Impersonate::Connection;

# Read whatever the connection wrote back, WITHOUT blocking. A blocking sysread
# here turns any assertion failure into a hang instead of a report: proving that
# a fail-open regression is caught is worthless if catching it wedges the suite.
sub drain {
    my ($sock) = @_;
    $sock->blocking(0);
    my $out = '';
    while (defined(my $n = sysread($sock, my $buf, 8192))) { last unless $n; $out .= $buf }
    return $out;
}

# on_request: the per-request interception hook. Exercised at the Connection
# level with a fake Multi, so no TLS and no network are involved -- the hook
# fires in _forward, which is reached by feeding a tunnelled request into rbuf.

{
    package FakeMulti;
    sub new { bless { calls => [] }, shift }
    sub add_streaming { my ($s, $h, $req, $cbs) = @_; push @{$s->{calls}}, { req => $req, cbs => $cbs } }
    sub resume {}
    sub remove {}
}

# Build a connection already in the tunnelled state, feed it one GET, and return
# ($conn, $multi, $client_socket) so a test can inspect both what went upstream
# and what was written back to the client.
sub tunnelled {
    my (%o) = @_;
    socketpair(my $client, my $srv, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
    my $multi = FakeMulti->new;
    my $conn  = Proxy::Impersonate::Connection->new(
        fd => $srv, cert => undef, multi => $multi,
        make_handle => sub { bless {}, 'FakeHandle' }, on_close => sub {},
        %o,
    );
    $conn->{state}        = 'tls';
    $conn->{connect_host} = 'ex.com:443';
    $conn->{rbuf} = "GET /p?q=1 HTTP/1.1\r\nHost: ex.com\r\nAccept: */*\r\n"
                  . "Cookie: a=1\r\nReferer: https://ex.com/\r\nAccept-Language: en\r\n\r\n";
    $conn->_process;
    return ($conn, $multi, $client);
}

# --- no hook: unchanged behaviour ---
{
    my ($conn, $multi) = tunnelled();
    is(scalar @{ $multi->{calls} }, 1, 'without on_request the request goes upstream');
    is($multi->{calls}[0]{req}{url}, 'https://ex.com:443/p?q=1', '...with the tunnelled URL');
}

# --- observe: the hook sees method, url, headers and host ---
{
    my %seen; my $hdrs;
    my ($conn, $multi) = tunnelled(on_request => sub {
        my ($r) = @_;
        %seen = (method => $r->{method}, url => $r->{url}, host => $r->{host});
        $hdrs = { %{ $r->{headers} } };
        return;                       # proceed unchanged
    });
    is($seen{method}, 'GET',   'on_request sees the method');
    is($seen{url}, 'https://ex.com:443/p?q=1', 'on_request sees the full URL');
    is($seen{host}, 'ex.com',  'on_request sees the bare host');
    is(scalar @{ $multi->{calls} }, 1, 'returning nothing lets the request proceed');

    # The headers the hook sees are the ones this proxy FORCES on top of
    # curl-impersonate's template -- what the browser sent that must be carried
    # through. Cookie and Referer are there...
    is($hdrs->{cookie},  'a=1',              'on_request sees Cookie');
    is($hdrs->{referer}, 'https://ex.com/',  'on_request sees Referer');
    # ...but Accept / Accept-Language are NOT: curl-impersonate supplies those
    # from its fingerprint template, and forwarding the browser's own would
    # break the very fingerprint this proxy exists to reproduce. Pinning this
    # so the docs and the behaviour cannot drift apart.
    ok(!exists $hdrs->{accept},          'template headers (accept) are NOT exposed');
    ok(!exists $hdrs->{'accept-language'}, 'template headers (accept-language) are NOT exposed');
}

# --- rewrite: url, method, headers and body are all honoured in place ---
{
    my ($conn, $multi) = tunnelled(on_request => sub {
        my ($r) = @_;
        $r->{url} =~ s{/p\?q=1$}{/rewritten};
        $r->{method} = 'POST';
        $r->{headers}{'x-injected'} = 'yes';
        $r->{body} = 'hello';
        return;
    });
    my $req = $multi->{calls}[0]{req};
    is($req->{url}, 'https://ex.com:443/rewritten', 'a rewritten url is what goes upstream');
    is($req->{method}, 'POST', 'a rewritten method is honoured');
    is($req->{headers}{'x-injected'}, 'yes', 'an injected header is honoured');
    is($req->{body}, 'hello', 'a rewritten body is honoured');
}

# --- mock: returning a hashref answers locally and never goes upstream ---
{
    my ($conn, $multi, $client) = tunnelled(on_request => sub {
        return { status => 418, headers => { 'content-type' => 'text/plain' },
                 body => 'teapot' };
    });
    is(scalar @{ $multi->{calls} }, 0, 'a mocked request never reaches the network');
    my $got = drain($client);
    like($got, qr{\AHTTP/1\.1 418\b}, 'the synthetic status reaches the client');
    like($got, qr{content-type: text/plain}i, 'the synthetic headers reach the client');
    like($got, qr{content-length: 6}i, 'content-length is computed from the body, not trusted');
    like($got, qr{teapot\z}, 'the synthetic body reaches the client');
}

# --- a mock that LIES about content-length must not desynchronise the stream ---
{
    my ($conn, $multi, $client) = tunnelled(on_request => sub {
        return { status => 200, headers => { 'content-length' => 999 }, body => 'four' };
    });
    my $got = drain($client);
    like($got, qr{content-length: 4}i, "a handler's wrong content-length is overridden, not echoed");
    unlike($got, qr{content-length: 999}i, '...and the bogus value never reaches the client');
}

# --- block: an abort closes the connection without answering ---
{
    my ($conn, $multi) = tunnelled(on_request => sub { 'abort' });
    is(scalar @{ $multi->{calls} }, 0, 'an aborted request never reaches the network');
    ok($conn->{_dead}, 'abort closes the connection');
}

# --- a dying handler FAILS CLOSED: the request must not slip through ---
{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    my ($conn, $multi, $client) = tunnelled(on_request => sub { die "boom\n" });
    is(scalar @{ $multi->{calls} }, 0,
       'a request whose handler died does NOT go upstream (fails closed)');
    my $got = drain($client);
    like($got, qr{\AHTTP/1\.1 502\b}, 'the client is told the request was refused');
    like(join('', @warnings), qr/on_request died/, 'the exception is reported, not swallowed');
}

# --- keep-alive still works after a mocked response (the length is exact, so
#     the connection stays usable rather than being closed defensively) ---
{
    my ($conn, $multi, $client) = tunnelled(on_request => sub {
        return { status => 200, body => 'ok' };
    });
    ok(!$conn->{_dead}, 'the connection survives a mocked response');
    is($conn->{inflight}, undef, 'nothing is left in flight');
    # a second request on the same connection is served too
    $conn->{rbuf} = "GET /second HTTP/1.1\r\nHost: ex.com\r\n\r\n";
    $conn->_process;
    my $got = drain($client);
    my @statuses = $got =~ m{HTTP/1\.1 (\d+)}g;
    is(scalar @statuses, 2, 'a second request on the same connection is answered');
}

done_testing;
