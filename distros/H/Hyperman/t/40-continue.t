#!perl
use strict;
use warnings;
use lib "t/lib";
use Test::More;
use HMTest qw(free_ports quiet_child server_status server_reap);
use IO::Socket::INET;
use IO::Select;
use Time::HiRes ();
use Hyperman ();

# Expect: 100-continue (RFC 9110 10.1.1). A client that means to send a large
# body may ask permission first and wait for an interim 100 before spending
# the upload. A server that never answers does not break such a client - it
# stalls it, for however long that client is prepared to wait, on every
# request. And the refusal matters more than the permission: a body over
# max_body is answered on the headers, before the client sends any of it.
#
# TEST METHOD: every case writes the request HEAD and then reads with a
# deadline BEFORE writing any body. That ordering is the assertion - an
# interim response can only be in that first read if it was sent without the
# body, which is the whole contract.

my ($port) = free_ports(1);
plan skip_all => 'no free port' unless $port;

my $kid = fork;
die "fork: $!" unless defined $kid;
if ($kid == 0) {
    quiet_child();
    require Hyperman;
    Hyperman->run(
        app => sub {
            my $env = shift;
            my $b = '';
            $env->{'psgi.input'}->read($b, $env->{CONTENT_LENGTH})
                if $env->{'psgi.input'} && $env->{CONTENT_LENGTH};
            [ 200, [ 'Content-Type' => 'text/plain' ], [ 'got ' . length $b ] ];
        },
        host => '127.0.0.1', port => $port, workers => 1,
        max_body => 4096,
    );
    exit 0;
}

sub sock {
    for (1 .. 40) {
        return undef if server_status($kid);
        my $s = IO::Socket::INET->new(PeerAddr => '127.0.0.1',
                                      PeerPort => $port, Proto => 'tcp');
        if ($s) { binmode $s; $s->autoflush(1); return $s }
        Time::HiRes::sleep(0.1);
    }
    return undef;
}

# Read for up to $secs, returning early once $until matches what has arrived.
# A case that expects NOTHING pays the whole $secs, so it is kept short.
sub drain {
    my ($s, $secs, $until) = @_;
    my $sel = IO::Select->new($s);
    my $buf = '';
    my $deadline = Time::HiRes::time() + $secs;
    while (1) {
        return $buf if $until && $buf =~ $until;
        my $left = $deadline - Time::HiRes::time();
        return $buf if $left <= 0;
        next unless $sel->can_read($left);
        my $n = sysread($s, my $chunk, 65536);
        return $buf if !defined $n || $n == 0;
        $buf .= $chunk;
    }
}

my $FINAL = qr{\r\n\r\n(?:got \d+)?\z};

# ---- the interim arrives, and the body follows it ---------------------------

{
    my $s = sock();
    unless ($s) {
        my $why = server_status($kid) || 'no answer on the port';
        plan skip_all => "server did not start: $why";
    }
    $s->print("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n"
              . "Expect: 100-continue\r\nConnection: close\r\n\r\n");
    my $early = drain($s, 5, qr{\r\n\r\n});
    like $early, qr{\AHTTP/1\.1 100 Continue\r\n\r\n\z},
        'the interim 100 is sent before the body, and is only the interim';
    $s->print('hello');
    my $rest = drain($s, 5, $FINAL);
    like $rest, qr{\AHTTP/1\.1 200 }, 'the final response follows it';
    like $rest, qr{got 5\z}, '...and the app got the body';
    close $s;
}

# ---- once per request, not once per readable event --------------------------

# The headers stay in the read buffer until the body is whole, so the parse
# that decides this runs again on every readable event. Without a bit on the
# connection a trickled body collects one 100 per packet.
{
    my $s = sock();
    $s->print("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 6\r\n"
              . "Expect: 100-continue\r\nConnection: close\r\n\r\n");
    my $early = drain($s, 5, qr{\r\n\r\n});
    like $early, qr{100 Continue}, 'trickled body: the interim arrives';
    for my $c (split //, 'abcdef') {
        $s->print($c);
        Time::HiRes::sleep(0.05);
    }
    my $all = $early . drain($s, 5, $FINAL);
    my $n = () = $all =~ /100 Continue/g;
    is $n, 1, '...exactly one 100 Continue for the whole request';
    like $all, qr{got 6\z}, '...and the trickle was reassembled';
    close $s;
}

# ---- a body over max_body is refused before it is sent ----------------------

# The point of the expectation. Without it this refusal costs the client the
# whole upload and the server the whole read; with it the client is told on
# the headers and sends nothing.
{
    my $s = sock();
    $s->print("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 1048576\r\n"
              . "Expect: 100-continue\r\n\r\n");
    my $early = drain($s, 5, qr{\r\n\r\n});
    like $early, qr{\AHTTP/1\.1 413 },
        'a declared body over max_body is refused on the headers';
    unlike $early, qr{100 Continue},
        '...and is never promised a continue it would not honour';
    close $s;
}

# ---- an expectation the server cannot meet ---------------------------------

{
    my $s = sock();
    $s->print("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n"
              . "Expect: the-moon-on-a-stick\r\n\r\n");
    my $early = drain($s, 5, qr{\r\n\r\n});
    like $early, qr{\AHTTP/1\.1 417 Expectation Failed},
        'an unknown expectation is refused with 417, not silently ignored';
    close $s;
}

# 100-continue with anything beside it is still an expectation this server
# cannot meet as a whole, so it is refused rather than half-honoured.
{
    my $s = sock();
    $s->print("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n"
              . "Expect: 100-continue, jam-tomorrow\r\n\r\n");
    my $early = drain($s, 5, qr{\r\n\r\n});
    like $early, qr{\AHTTP/1\.1 417 }, 'a list with an unknown member is 417';
    close $s;
}

# ---- HTTP/1.0 ---------------------------------------------------------------

# RFC 9110: a 100-continue expectation from an HTTP/1.0 client MUST be
# ignored. Such a client is not waiting for an interim response and would not
# know what to do with one - it would read it as the response.
{
    my $s = sock();
    $s->print("POST / HTTP/1.0\r\nHost: x\r\nContent-Length: 5\r\n"
              . "Expect: 100-continue\r\n\r\nhello");
    my $r = drain($s, 5, $FINAL);
    unlike $r, qr{100 Continue}, 'an HTTP/1.0 Expect is ignored';
    like $r, qr{\AHTTP/1\.[01] 200 }, '...and the request is served normally';
    close $s;
}

# ---- a body that is already here --------------------------------------------

# Nothing is waiting on permission that has already been acted on, and RFC
# 9110 lets the interim response be omitted once the body has arrived.
{
    my $s = sock();
    $s->print("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n"
              . "Expect: 100-continue\r\nConnection: close\r\n\r\nhello");
    my $r = drain($s, 5, $FINAL);
    unlike $r, qr{100 Continue},
        'a request that already carries its body gets no interim';
    like $r, qr{\AHTTP/1\.1 200 .*got 5\z}s, '...just its answer';
    close $s;
}

# ---- chunked ----------------------------------------------------------------

{
    my $s = sock();
    $s->print("POST / HTTP/1.1\r\nHost: x\r\nTransfer-Encoding: chunked\r\n"
              . "Expect: 100-continue\r\nConnection: close\r\n\r\n");
    my $early = drain($s, 5, qr{\r\n\r\n});
    like $early, qr{\AHTTP/1\.1 100 Continue},
        'a chunked body is asked for the same way';
    $s->print("5\r\nhello\r\n0\r\n\r\n");
    my $rest = drain($s, 5, $FINAL);
    like $rest, qr{got 5\z}, '...and arrives';
    close $s;
}

# ---- keep-alive: each request asks for itself -------------------------------

{
    my $s = sock();
    my $seen = '';
    for my $i (1 .. 2) {
        $s->print("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n"
                  . "Expect: 100-continue\r\n\r\n");
        my $early = drain($s, 5, qr{\r\n\r\n});
        like $early, qr{100 Continue}, "keep-alive request $i is answered";
        $s->print('hello');
        $seen .= $early . drain($s, 5, qr{got 5\z});
    }
    my $n = () = $seen =~ /100 Continue/g;
    is $n, 2, 'two requests, two interim responses';
    close $s;
}

# ---- and nothing changes for a client that did not ask ----------------------

{
    my $s = sock();
    $s->print("POST / HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n"
              . "Connection: close\r\n\r\n");
    my $early = drain($s, 1, qr{\r\n\r\n});
    is $early, '', 'no Expect, no interim - the server waits for the body';
    $s->print('hello');
    like drain($s, 5, $FINAL), qr{\AHTTP/1\.1 200 }, '...then answers';
    close $s;
}

unless (defined server_status($kid)) {
    kill 'TERM', $kid;
    my $reaped = 0;
    for (1 .. 100) {
        last if $reaped = defined server_status($kid);
        Time::HiRes::sleep(0.1);
    }
    unless ($reaped) { kill 'KILL', $kid; server_reap($kid) }
}

done_testing;
