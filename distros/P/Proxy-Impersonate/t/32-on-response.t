use v5.10; use strict; use warnings;
use Test::More;
use Socket;
use Proxy::Impersonate::Connection;

# on_response: the counterpart to on_request. Fires when the upstream headers
# arrive, so status and headers can be observed or rewritten before the client
# sees them -- stripping Content-Security-Policy is the usual reason.
#
# Driven at the Connection level with a fake Multi, so no TLS and no network.

sub drain {   # non-blocking: a failure must report, not hang (see t/31)
    my ($sock) = @_;
    $sock->blocking(0);
    my $out = '';
    while (defined(my $n = sysread($sock, my $buf, 8192))) { last unless $n; $out .= $buf }
    return $out;
}

{
    package FakeMulti;
    sub new { bless { cbs => undef }, shift }
    sub add_streaming { my ($s, $h, $req, $cbs) = @_; $s->{cbs} = $cbs; $s->{req} = $req }
    sub resume {}
    sub remove {}
}

# Run one tunnelled GET, then feed it an upstream response head.
sub respond {
    my (%o) = @_;
    my $status  = delete $o{status}  // 200;
    my $hdrs    = delete $o{hdrs}    // { 'content-type' => 'text/html', 'content-length' => 5 };
    socketpair(my $client, my $srv, AF_UNIX, SOCK_STREAM, PF_UNSPEC) or die "socketpair: $!";
    my $multi = FakeMulti->new;
    my $conn  = Proxy::Impersonate::Connection->new(
        fd => $srv, cert => undef, multi => $multi,
        make_handle => sub { bless {}, 'FakeHandle' }, on_close => sub {}, %o,
    );
    $conn->{state} = 'tls';
    $conn->{connect_host} = 'ex.com:443';
    $conn->{rbuf} = "GET /p HTTP/1.1\r\nHost: ex.com\r\n\r\n";
    $conn->_process;
    $multi->{cbs}{on_headers}->($status, $hdrs);
    return drain($client);
}

# --- no hook: unchanged ---
{
    my $got = respond();
    like($got, qr{\AHTTP/1\.1 200\b}, 'without on_response the status passes through');
    like($got, qr{content-type: text/html}i, '...and the headers do too');
}

# --- observe ---
{
    my %seen;
    my $got = respond(on_response => sub {
        my ($res) = @_;
        %seen = (status => $res->{status}, ct => $res->{headers}{'content-type'},
                 url => $res->{url}, method => $res->{method}, host => $res->{host});
        return;
    });
    is($seen{status}, 200,        'on_response sees the status');
    is($seen{ct}, 'text/html',    'on_response sees the response headers');
    is($seen{url}, 'https://ex.com:443/p', 'on_response sees the request URL');
    is($seen{method}, 'GET',      'on_response sees the request method');
    is($seen{host}, 'ex.com',     'on_response sees the bare host');
}

# --- rewrite status and headers ---
{
    my $got = respond(
        status => 403,
        hdrs   => { 'content-type' => 'text/html', 'content-length' => 5,
                    'content-security-policy' => "default-src 'none'" },
        on_response => sub {
            my ($res) = @_;
            $res->{status} = 200;                           # rewrite the status
            delete $res->{headers}{'content-security-policy'};   # the usual reason
            $res->{headers}{'x-added'} = 'yes';
            return;
        });
    like($got, qr{\AHTTP/1\.1 200\b},          'a rewritten status reaches the client');
    unlike($got, qr{content-security-policy}i, 'a deleted header is really gone');
    like($got, qr{x-added: yes}i,              'an added header reaches the client');
}

# --- FRAMING is ours, not the handler's -------------------------------------
# A handler that edits content-length would not desynchronise its own
# connection, it would desynchronise the browser's -- so the framing headers are
# snapshotted and forced back after the hook runs.
{
    my $got = respond(
        hdrs => { 'content-type' => 'text/plain', 'content-length' => 5 },
        on_response => sub {
            my ($res) = @_;
            $res->{headers}{'content-length'}    = 99999;
            $res->{headers}{'transfer-encoding'} = 'chunked';
            return;
        });
    like($got, qr{content-length: 5}i,      "a handler's content-length is overridden, not echoed");
    unlike($got, qr{content-length: 99999}, '...and the bogus value never reaches the client');
    unlike($got, qr{transfer-encoding}i,    'a handler cannot smuggle transfer-encoding back in');
}

# ...and a handler cannot ADD a content-length where we deliberately had none
# (unknown length means we close to delimit, so a length would be a lie).
{
    my $got = respond(
        hdrs => { 'content-type' => 'text/plain' },          # no content-length
        on_response => sub { $_[0]{headers}{'content-length'} = 7; return });
    unlike($got, qr{content-length}i, 'a handler cannot invent a content-length');
    like($got, qr{connection: close}i, '...and our close-to-delimit decision stands');
}

# --- a dying handler FAILS OPEN, unlike on_request --------------------------
# The request has already been made and the response fetched; refusing it would
# break the page over a bug in an observer, and there is no security decision
# left to protect.
{
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings, $_[0] };
    my $got = respond(on_response => sub { die "boom\n" });
    like($got, qr{\AHTTP/1\.1 200\b}, 'a response whose handler died still reaches the client');
    like(join('', @warnings), qr/on_response died/, 'the exception is reported, not swallowed');
}

done_testing;
