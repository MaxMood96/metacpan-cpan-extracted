use v5.10; use strict; use warnings;
use Test::More;
use lib 't/lib'; use TWK; TWK::skip_unless_available();
use EV; use EV::WebKit;
use IO::Socket::INET;
plan skip_all => 'on_request needs Proxy::Impersonate 0.01 (the hook it relies on)'
    unless eval { require Proxy::Impersonate; Proxy::Impersonate->VERSION('0.01'); 1 };

# on_request: request interception through the in-process proxy.
#
# WebKitGTK 6.0 offers no mutable request hook of its own: the UI process has
# only the observational 'sent-request' (the mutable 'send-request' does not
# exist in 6.0 at all), and libsoup is unreachable because WebKit2 runs
# networking in a separate process. So interception happens where the plaintext
# actually is -- the MITM proxy this module already spins for
# network_fingerprint.
#
# WHY THIS TEST DOES NOT DRIVE A PAGE LOAD: WebKit bypasses the proxy for local
# addresses. Verified in both directions -- a page load to a 127.0.0.1 origin
# AND to a LAN address reaches the origin directly with the hook never firing,
# and the same is true of the long-proven network_fingerprint path, so it is
# WebKit's routing, not this wiring. Proving interception through a page load
# would therefore need an external host, i.e. real network traffic in the
# suite. Instead: the interception LOGIC is covered exhaustively by
# Proxy::Impersonate's own t/31-on-request.t (29 assertions, mutation-checked),
# and what is tested here is that EV::WebKit wires the hook into a live proxy
# -- by speaking to that proxy exactly as a client would.

# --- validation ---
{
    eval { EV::WebKit->new(window => [200,150], on_request => 'not-a-code-ref') };
    like($@, qr/on_request must be a code reference/, 'on_request rejects a non-coderef');

    eval { EV::WebKit->new(window => [200,150], on_request => sub {}, proxy => 'http://x:1') };
    like($@, qr/mutually exclusive/, 'on_request and an explicit proxy are mutually exclusive');
}

# --- on_request alone spins the proxy (no fingerprint required) ---
{
    my $b = EV::WebKit->new(window => [200,150], on_request => sub { });
    ok(defined $b->proxy_port, 'on_request alone spins the interception proxy');
    cmp_ok($b->proxy_port, '>', 0, '...on a real port');
    $b->quit;
}

# --- the hook is really wired into that proxy: rewrite + mock, driven by a
# direct client request, so no external network is touched ---
SKIP: {
    my @seen;
    my $b = EV::WebKit->new(window => [200,150], on_request => sub {
        my ($req) = @_;
        push @seen, { method => $req->{method}, url => $req->{url}, host => $req->{host} };
        return { status => 418, headers => { 'content-type' => 'text/plain' },
                 body => 'intercepted' };
    });

    # skip, NOT plan skip_all: assertions have already run in this file, and a
    # plan emitted after them is a BAD PLAN -- the harness reports "You planned
    # 0 tests but ran N" and the whole run FAILS. Which would mean failing on
    # exactly the restricted hosts this guard exists to be gentle with.
    my $sock = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => $b->proxy_port,
                                     Proto => 'tcp', Timeout => 5)
        or skip "cannot connect to the interception proxy: $!", 7;
    $sock->blocking(0);
    # absolute-form request, which is what a client sends to an HTTP proxy
    my $req = "GET http://example.test/thing HTTP/1.1\r\nHost: example.test\r\n"
            . "Connection: close\r\n\r\n";
    my $got = '';
    my $ww; $ww = EV::io($sock, EV::WRITE, sub {
        my $n = syswrite($sock, $req);
        if (defined $n) { substr($req, 0, $n, ''); undef $ww unless length $req }
    });
    my $rw = EV::io($sock, EV::READ, sub {
        my $n = sysread($sock, my $buf, 8192);
        return unless defined $n;
        if ($n == 0) { EV::break; return }
        $got .= $buf;
        EV::break if $got =~ /\r\n\r\n/ && $got =~ /intercepted/;
    });
    my $t = EV::timer(15, 0, sub { EV::break });
    EV::run;
    undef $ww; undef $rw; undef $t;
    close $sock;
    $b->quit;

    is(scalar @seen, 1, 'the hook fired for a request made through the proxy')
        or diag('the hook was not reached at all');
    is($seen[0]{method}, 'GET',           'the hook sees the method');
    is($seen[0]{url}, 'http://example.test/thing', 'the hook sees the absolute URL');
    is($seen[0]{host}, 'example.test',    'the hook sees the bare host');
    like($got, qr{\AHTTP/1\.1 418\b},     'the synthetic status reached the client');
    like($got, qr{intercepted},           'the synthetic body reached the client');
    # the whole point: nothing went to the network for example.test
    like($got, qr{content-length: 11}i,   'content-length is computed from the synthetic body');
}

# --- on_response, end to end -------------------------------------------------
#
# This used to construct a browser, assert proxy_port was defined and quit --
# so the handler was never invoked and the assertion could not have failed if
# on_response did nothing at all, which is exactly how a stale install of the
# proxy hid once already.
#
# It can be driven for real: WebKit's local-address bypass is a rule about how
# WEBKIT routes, and has no bearing on what the proxy forwards when spoken to
# directly. So point the proxy at a local origin and check the whole path --
# the hook sees the origin's real status, its edit reaches the client, and the
# origin's own headers and body survive the round trip.
SKIP: {
    my $origin = IO::Socket::INET->new(LocalAddr => '127.0.0.1', LocalPort => 0,
                                       Listen => 5, ReuseAddr => 1)
        or skip "cannot bind an origin socket: $!", 7;
    my $oport = $origin->sockport;
    my (%oconn, $hits);
    $hits = 0;
    my $oacc = EV::io($origin, EV::READ, sub {
        my $c = $origin->accept or return;
        $c->blocking(0);
        my $buf = '';
        my $rw; $rw = EV::io($c, EV::READ, sub {
            my $n = sysread($c, my $ch, 4096);
            if (!defined $n) { return if $!{EAGAIN} || $!{EWOULDBLOCK}; delete $oconn{$c}; return }
            return delete $oconn{$c} unless $n;
            $buf .= $ch;
            return unless $buf =~ /\r?\n\r?\n/;
            delete $oconn{$c};
            $hits++;
            my $body = 'ORIGIN-BODY';
            print $c "HTTP/1.1 203 Non-Authoritative\r\nContent-Type: text/plain\r\n"
                   . "X-From-Origin: yes\r\nContent-Length: " . length($body) . "\r\n"
                   . "Connection: close\r\n\r\n$body";
            close $c;
        });
        $oconn{$c} = $rw;
    });

    my @seen;
    my $b = EV::WebKit->new(window => [200,150],
        on_request  => sub { return },                    # pass through, do not mock
        on_response => sub {
            my ($res) = @_;
            push @seen, { status => $res->{status} };
            $res->{headers}{'x-added-by-hook'} = 'yes';
            return;
        },
    );
    ok(defined $b->proxy_port, 'on_response also spins the interception proxy');

  SKIP: {
    my $sock = IO::Socket::INET->new(PeerAddr => '127.0.0.1', PeerPort => $b->proxy_port,
                                     Proto => 'tcp', Timeout => 5)
        or skip "cannot connect to the interception proxy: $!", 6;
    $sock->blocking(0);
    my $req = "GET http://127.0.0.1:$oport/thing HTTP/1.1\r\nHost: 127.0.0.1:$oport\r\n"
            . "Connection: close\r\n\r\n";
    my $got = '';
    my $ww; $ww = EV::io($sock, EV::WRITE, sub {
        my $n = syswrite($sock, $req);
        if (defined $n) { substr($req, 0, $n, ''); undef $ww unless length $req }
    });
    my $rw = EV::io($sock, EV::READ, sub {
        my $n = sysread($sock, my $buf, 8192);
        return unless defined $n;
        if ($n == 0) { EV::break; return }
        $got .= $buf;
        EV::break if $got =~ /ORIGIN-BODY/;
    });
    my $t = EV::timer(20, 0, sub { EV::break });
    EV::run;
    undef $ww; undef $rw; undef $t; undef $oacc;
    close $sock;
    $b->quit;

    is($hits, 1, 'the proxy really forwarded to the origin (nothing was mocked)');
    is(scalar @seen, 1, 'on_response fired for the forwarded response')
        or diag('the hook was not reached at all');
    is($seen[0]{status}, 203, "...and sees the origin's real status");
    like($got, qr/x-added-by-hook:\s*yes/i, "the hook's added header reached the client");
    like($got, qr/x-from-origin:\s*yes/i,   "...and the origin's own headers survived");
    like($got, qr/ORIGIN-BODY/,             '...as did the body');
  }
}

# on_response accepts only a coderef, and conflicts with an explicit proxy,
# exactly as on_request does -- the validation is shared, so this pins that the
# generalisation did not drop either check.
eval { EV::WebKit->new(window => [200,150], on_response => "nope") };
like($@, qr/on_response must be a code reference/, "on_response rejects a non-coderef");
eval { EV::WebKit->new(window => [200,150], on_response => sub {}, proxy => "http://x:1") };
like($@, qr/mutually exclusive/, "on_response and an explicit proxy are mutually exclusive");

done_testing;
