use v5.10; use strict; use warnings;
use Test::More;
use EV::WebKit::Protocol;

# The wire codec, on its own. No browser, no event loop, no socket -- which is
# the whole reason it is a separate module.

is(EV::WebKit::Protocol::PROTO, 1, 'protocol version is 1');

# encode: one line, newline-terminated, UTF-8 OCTETS (this goes on a socket)
my $line = EV::WebKit::Protocol::encode({ i => 1, m => 'go', a => ['x'] });
like($line, qr/\n\z/, 'encode ends with a newline');
unlike(substr($line, 0, -1), qr/\n/, '...and contains no other newline');
ok(!utf8::is_utf8($line), 'encode returns octets, not characters');

# round-trip
my $dec = EV::WebKit::Protocol::decoder();
my @f = $dec->($line);
is(scalar(@f), 1, 'one line decodes to one frame');
is_deeply($f[0], { i => 1, m => 'go', a => ['x'] }, '...round-tripped intact');

# partial reads: a socket splits wherever it likes, including mid-character
{
    my $d = EV::WebKit::Protocol::decoder();
    my $l = EV::WebKit::Protocol::encode({ i => 2, m => 'title' });
    my @got;
    push @got, $d->($_) for split //, $l;      # feed it one octet at a time
    is(scalar(@got), 1, 'a frame split at every possible boundary still decodes exactly once');
    is($got[0]{i}, 2, '...intact');
}

# several frames in one read
{
    my $d = EV::WebKit::Protocol::decoder();
    my $chunk = join '', map { EV::WebKit::Protocol::encode({ i => $_ }) } 1 .. 3;
    my @got = $d->($chunk);
    is(scalar(@got), 3, 'three frames in one read decode to three frames');
    is_deeply([ map { $_->{i} } @got ], [1,2,3], '...in order');
}

# unicode survives the wire
{
    my $d = EV::WebKit::Protocol::decoder();
    my $text = "caf\x{e9} \x{4e2d}\x{6587} \x{1f600}";
    my @got = $d->(EV::WebKit::Protocol::encode({ i => 9, r => $text }));
    is($got[0]{r}, $text, 'unicode round-trips (encode octets, decode characters)');
}

# garbage must not kill the server: one client's bad line is that client's problem
{
    my $d = EV::WebKit::Protocol::decoder();
    my @got = $d->(qq({"i":1,"m":"go"}\n) . qq(not json at all\n) . qq({"i":2}\n));
    is(scalar(@got), 3, 'a bad line does not swallow the good ones around it');
    is($got[0]{m}, 'go', 'the frame before it is fine');
    ok($got[1]{_bad}, 'the bad line comes back marked, not thrown');
    is($got[2]{i}, 2, 'the frame after it is fine');
}

# valid JSON that is not an object is still not a frame
{
    my $d = EV::WebKit::Protocol::decoder();
    my @got = $d->(qq(123\n["a"]\n));
    ok($got[0]{_bad} && $got[1]{_bad}, 'a JSON scalar or array is not a frame');
}

# blank lines are nothing
{
    my $d = EV::WebKit::Protocol::decoder();
    my @got = $d->(qq(\n\n{"i":1}\n));
    is(scalar(@got), 1, 'blank lines are ignored');
}

# a client that opens a socket and never sends a newline must not eat the machine
{
    my $d = EV::WebKit::Protocol::decoder();
    my @got = $d->('x' x (EV::WebKit::Protocol::MAX_LINE + 1));
    ok($got[0]{_bad}, 'an oversized line is refused rather than buffered forever');
    like($got[0]{_bad}, qr/too long/, '...saying why');
    my @after = $d->(qq({"i":1}\n));
    ok($after[0]{_bad}, '...and the decoder stays refused rather than half-parsing the rest');
}

done_testing;
