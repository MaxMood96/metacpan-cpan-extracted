#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PPKTest qw(fixture b64u_decode hex_to_bytes);
use Punk::Passkey ();

# One input per refusal branch, and each one must select ITS OWN branch.
#
# The reason each assertion checks the message and not merely the
# failure: a decoder that refused everything would pass a suite that
# only asked "did it fail?", and a refusal that fires from the wrong
# branch is a bug wearing the right answer's clothes. Requiring the
# documented reason for each input is how a branch is actually covered
# - remove any one refusal from ppk_cbor.h and exactly one of these
# stops reporting its reason.
#
# Where a branch can be selected by mutating a REAL document, it is:
# those inputs are a genuine attestation object with one byte changed,
# so they are the shape an attacker would actually send. The rest need
# a structure no real document contains (nesting past the bound, a map
# key that is not a label), and those are built here and said to be.

sub decode {
    my ($bytes) = @_;
    $Punk::Passkey::ERR = '';
    my $got = Punk::Passkey::_decode_cbor($bytes);
    return ($got, $Punk::Passkey::ERR);
}

my $att = b64u_decode(fixture('reg-none.txt')->{attestationObject});
ok(length $att > 200, 'the real attestation object loaded');

# it decodes as it stands - every mutation below is measured against this
{
    my ($got, $err) = decode($att);
    is($err, '', 'and decodes cleanly before anything is done to it');
    ok(ref $got eq 'HASH', '...to a map');
    is(join(',', sort keys %$got), 'attStmt,authData,fmt',
        '...with the three keys WebAuthn defines');
    is($got->{fmt}, 'none', '...and this one is a `none` attestation');
}

# ---- mutations of the real document ------------------------------------------

my @mutation = (
    {   name => 'a trailing byte after a complete document',
        why  => qr/trailing bytes/,
        make => sub { $att . "\x00" },
        note => 'the document is intact; something follows it',
    },
    {   name => 'the last byte removed',
        why  => qr/past end|truncated/,
        make => sub { substr $att, 0, length($att) - 1 },
        note => 'a length that no longer describes what is there',
    },
    {   name => 'the outer map made indefinite-length',
        why  => qr/indefinite/,
        make => sub { my $m = $att; substr($m, 0, 1) = "\xbf"; $m },
        note => 'one byte: a3 (map of 3) becomes bf (map until break)',
    },
    {   name => 'the document wrapped in a tag',
        why  => qr/tag/,
        make => sub { "\xc0" . $att },
        note => 'tag 0, which would change what the bytes underneath mean',
    },
);

for my $m (@mutation) {
    my $bytes = $m->{make}->();
    unless (defined $bytes) {
        fail("could not build: $m->{name}");
        next;
    }
    my ($got, $err) = decode($bytes);
    isnt($err, '', "refused: $m->{name}");
    like($err, $m->{why}, "...for the documented reason ($m->{note})");
}

# ---- the duplicate key, on the real COSE key ---------------------------------
# The COSE key is not part of the outer parse: authData is a byte
# string, so the decoder hands it back whole and the key inside it is
# decoded separately - which is what the ceremonies do, and why a
# mutation there has to be aimed at that second decode rather than the
# first. (Aiming it at the first proves nothing: the bytes are opaque
# and the document still decodes, correctly.)
{
    my ($outer, $err) = decode($att);
    my $cose = PPKTest::cose_bytes($outer);
    ok(defined $cose && length $cose > 40, 'the COSE key came out of authData');

    my ($k, $kerr) = decode($cose);
    is($kerr, '', 'and decodes on its own');
    is(ref $k, 'HASH', '...to a map of labels');
    is($k->{1}, 2, '...kty 2, an EC2 key');
    is($k->{3}, -7, '...alg -7, ES256');

    # one byte: the `03` (alg) label becomes a second `01` (kty)
    my $dup = $cose;
    my $i = index($dup, "\xa5\x01\x02\x03\x26");
    ok($i == 0, 'the COSE key starts with the labels this mutates');
    substr($dup, $i + 3, 1) = "\x01";
    my (undef, $derr) = decode($dup);
    isnt($derr, '', 'a duplicate label is refused');
    like($derr, qr/duplicate map key/,
        '...by name - one label answering twice is the attack, and '
      . 'choosing either answer is how two implementations come to '
      . 'disagree about which algorithm a key names');
}

# ---- branches no real document can select ------------------------------------
# Built here rather than mutated, because nothing an authenticator
# sends is shaped like any of them.

my @constructed = (
    {   name => 'nesting past the depth bound',
        hex  => '81' x 12,                  # twelve nested one-item arrays
        why  => qr/too deep/,
    },
    {   name => 'a map key that is neither an integer nor text',
        hex  => 'a1800101',                 # {[]: 1}
        why  => qr/map key/,
    },
    {   name => 'an array claiming more entries than the whole input',
        hex  => '9a00001001',               # array(4097), no data
        why  => qr/array too long/,
    },
    {   name => 'a map claiming more entries than the whole input',
        hex  => 'ba00001001',               # map(4097), no data
        why  => qr/map too long/,
    },
    {   name => 'an array whose length runs past the end',
        hex  => '8801020304',               # array(8), four items
        why  => qr/past end|truncated/,
    },
    {   name => 'a byte string whose length runs past the end',
        hex  => '58ff0102',                 # bytes(255), two present
        why  => qr/string past end/,
    },
    {   name => 'a reserved additional-information value',
        hex  => '1c',                       # ai 28
        why  => qr/reserved/,
    },
    {   name => 'an argument the input is too short to hold',
        hex  => '1901',                     # two-byte argument, one byte
        why  => qr/truncated argument/,
    },
    {   name => 'an unsigned integer past what an IV holds',
        hex  => '1bffffffffffffffff',
        why  => qr/integer too large/,
    },
    {   name => 'a negative integer past what an IV holds',
        hex  => '3bffffffffffffffff',
        why  => qr/integer too large/,
    },
    {   name => 'a half-width float',
        hex  => 'f93e00',                   # 1.5
        why  => qr/float/,
    },
    {   name => 'a simple value that is not true, false or null',
        hex  => 'f818',                     # simple(24)
        why  => qr/simple value/,
    },
    {   name => 'undefined',
        hex  => 'f7',
        why  => qr/simple value/,
    },
    {   name => 'no input at all',
        hex  => '',
        why  => qr/truncated/,
    },
);

for my $c (@constructed) {
    my ($got, $err) = decode(hex_to_bytes($c->{hex}));
    isnt($err, '', "refused: $c->{name}");
    like($err, $c->{why}, '...for the documented reason');
}

# Every branch above reported a DIFFERENT reason where the
# documentation says they are different things. If two inputs meant to
# select different refusals reported the same one, one of them is
# reaching the wrong branch and its coverage is imaginary.
{
    my %reason;
    for my $c (@constructed) {
        my (undef, $err) = decode(hex_to_bytes($c->{hex}));
        push @{ $reason{$err} }, $c->{name};
    }
    my @collide = grep { @{ $reason{$_} } > 1 } keys %reason;
    # Three reasons are shared by design, because the inputs sharing
    # them select the same branch: the two out-of-range integers, the
    # two ways of running out of input, and undefined alongside
    # simple(24) - both are "a simple value that is not true, false or
    # null". Anything else sharing a reason means an input is reaching
    # a branch it was not aimed at, and its coverage is imaginary.
    my @unexpected = grep {
        $_ ne 'integer too large' && $_ ne 'truncated'
                                  && $_ ne 'simple value'
    } @collide;
    is(scalar @unexpected, 0,
        'each constructed input reaches a distinct refusal')
        or diag join "\n", map { "$_: @{ $reason{$_} }" } @unexpected;
}

# ---- a refusal is not an oracle ----------------------------------------------
# The reason exists for the log. Nothing here should ever be handed to
# the caller who sent the bytes, and the ceremonies in the phases above
# this one return a uniform failure - so this asserts the shape the
# reasons have, not that they are secret.
{
    my (undef, $err) = decode("\xc0" . $att);
    unlike($err, qr/\d{2,}|0x/,
        'a reason names the rule, not an offset an attacker could walk');
}

done_testing;
