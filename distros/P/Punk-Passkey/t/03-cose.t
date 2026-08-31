#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PPKTest qw(fixture fixture_dir b64u_decode auth_data cose_bytes
               have_openssl openssl_accepts_pem);
use Punk::Passkey ();

# The COSE key seam, against keys made by real authenticators.
#
# The claim being tested is not "the encoder produces some bytes". It
# is that the bytes are a SubjectPublicKeyInfo describing the same key
# the authenticator meant - and this distribution's own opinion is
# worthless as evidence for that, so openssl is the oracle: it loads
# the PEM only if the point is genuinely on P-256, and it prints back
# the curve and the coordinates, which are compared against the ones
# the COSE map carried.
#
# t/fixtures/README records that the same check was run before these
# fixtures were checked in. Running it again here is the point: it is
# the seam that is under test now, not the fixtures.

sub decode {
    my ($b) = @_;
    $Punk::Passkey::ERR = '';
    my $g = Punk::Passkey::_decode_cbor($b);
    return ($g, $Punk::Passkey::ERR);
}

my @fixtures = qw(
    reg-none.txt
    reg-packed-yubikey.txt
    reg-packed-windows-hello.txt
    reg-fido-u2f.txt
);

my $openssl = have_openssl();
diag('openssl not found - the independent key check will be skipped')
    unless $openssl;

for my $name (@fixtures) {
    my $path = fixture_dir() . "/$name";
    unless (-f $path) { fail("missing fixture $name"); next }

    subtest $name => sub {
        my $f = fixture($name);
        my ($att, $err) = decode(b64u_decode($f->{attestationObject}));
        is($err, '', 'the captured attestation object decodes');
        is(ref $att, 'HASH', '...to a map');

        my $ad = auth_data($att->{authData});
        ok($ad, 'authenticatorData reads');
        ok($ad->{up}, 'user presence was set when this was captured');
        ok($ad->{at}, 'and attested credential data is present');
        ok(length $ad->{credentialId} > 0, 'there is a credential id');
        # the ceiling the spec puts on a credential id; every real one
        # is far under it, and the ceremonies refuse anything over
        ok(length $ad->{credentialId} <= 1023,
            'within the 1023-byte ceiling the spec sets');

        my ($key, $kerr) = decode($ad->{cose});
        is($kerr, '', 'the COSE key decodes');
        is($key->{1}, 2, 'kty 2: an EC2 key');
        is($key->{3}, -7, 'alg -7: ES256');
        is($key->{-1}, 1, 'crv 1: P-256');
        is(length $key->{-2}, 32, 'x is 32 bytes');
        is(length $key->{-3}, 32, 'y is 32 bytes');

        my ($pem, $alg) = Punk::Passkey::_cose_to_pem($key);
        ok($pem, 'the key converts to PEM') or diag $Punk::Passkey::ERR;
        is($alg, -7, '...reporting the algorithm from the key itself, '
                   . 'not from anywhere the caller could disagree with');
        like($pem, qr/\A-----BEGIN PUBLIC KEY-----\n/, '...armoured');
        like($pem, qr/-----END PUBLIC KEY-----\n\z/, '...and terminated');

      SKIP: {
            skip 'no openssl', 3 unless $openssl;
            my ($ok, $text) = openssl_accepts_pem($pem);
            ok($ok, 'openssl loads it - so the point is really on the curve')
                or diag $text;
            like($text, qr/P-256|prime256v1/i,
                '...and calls it P-256, the curve the COSE map named');
            # the coordinates openssl prints must be the ones that went in
            # openssl prints the point as colon-separated octets over
            # several lines, and the LAST octet carries no trailing
            # colon - so the run has to allow a bare pair at the end or
            # the comparison silently comes up one byte short.
            my $xy = lc join '', ($text =~ /pub:\s*((?:[0-9a-f]{2}[:\s]*)+)/s
                                  ? $1 : '');
            $xy =~ s/[^0-9a-f]//g;
            my $want = '04' . unpack('H*', $key->{-2}) . unpack('H*', $key->{-3});
            is($xy, $want,
                'the point openssl read back is byte-for-byte the one the '
              . 'authenticator sent');
        }
    };
}

# ---- the COSE key with something legitimate behind it ------------------------
# authData may carry extension data after the credential's public key.
# The whole-document decoder refuses trailing bytes, correctly, so the
# ceremonies read the key with the prefix decoder instead and are told
# how much it consumed - which is also how they find where the
# extensions start.
{
    my $f = fixture('reg-none.txt');
    my ($att) = decode(b64u_decode($f->{attestationObject}));
    my $cose  = cose_bytes($att);

    $Punk::Passkey::ERR = '';
    my ($key, $used) = Punk::Passkey::_decode_cbor_prefix($cose);
    ok($key, 'the key decodes as a prefix');
    is($used, length $cose,
        'consuming exactly the key when nothing follows it');

    # the same key with extension bytes appended
    my $with_ext = $cose . "\xa1\x63\x66\x6f\x6f\x01";      # {"foo": 1}
    $Punk::Passkey::ERR = '';
    my ($key2, $used2) = Punk::Passkey::_decode_cbor_prefix($with_ext);
    ok($key2, 'and still decodes with extension data behind it');
    is($used2, length $cose, '...reporting where the key ended');
    is_deeply([sort keys %$key2], [sort keys %$key],
        '...having read the same key, not one byte more');

    # while the strict entry point refuses the same input, which is the
    # difference between the two and the reason both exist
    my (undef, $err) = decode($with_ext);
    like($err, qr/trailing bytes/,
        'the whole-document decoder refuses what the prefix decoder '
      . 'accepts - a document with something after it is only allowed '
      . 'where something after it is expected');
}

# ---- what the allowlist refuses ----------------------------------------------
# Each of these starts from a real key and changes exactly one thing,
# so what is being tested is the rule and not the parser.

my $real = do {
    my $f = fixture('reg-none.txt');
    my ($att) = decode(b64u_decode($f->{attestationObject}));
    my ($k)   = decode(cose_bytes($att));
    $k;
};
ok($real, 'a real key to vary from');

sub vary {
    my (%change) = @_;
    my %k = %$real;
    $k{$_} = $change{$_} for keys %change;
    delete $k{$_} for grep { !defined $change{$_} && exists $change{$_} }
                      keys %change;
    return \%k;
}

my @refusals = (
    {   name => 'a curve that is not P-256',
        key  => sub { vary(-1 => 2) },              # P-384
        why  => qr/P-256/,
    },
    {   name => 'an algorithm off the allowlist',
        key  => sub { vary(3 => -8) },              # EdDSA
        why  => qr/algorithm other than ES256/,
    },
    {   name => 'a key type that is neither EC2 nor RSA',
        key  => sub { vary(1 => 5) },               # Symmetric
        why  => qr/neither EC2 nor RSA/,
    },
    {   name => 'x one byte short',
        key  => sub { vary(-2 => substr($real->{-2}, 1)) },
        why  => qr/x is not 32 bytes/,
    },
    {   name => 'x one byte long',
        key  => sub { vary(-2 => "\x00" . $real->{-2}) },
        why  => qr/x is not 32 bytes/,
    },
    {   name => 'y one byte short',
        key  => sub { vary(-3 => substr($real->{-3}, 1)) },
        why  => qr/y is not 32 bytes/,
    },
    {   name => 'no algorithm at all',
        key  => sub { my $k = { %$real }; delete $k->{3}; $k },
        why  => qr/no alg/,
    },
    {   name => 'no x',
        key  => sub { my $k = { %$real }; delete $k->{-2}; $k },
        why  => qr/no x/,
    },
);

for my $r (@refusals) {
    $Punk::Passkey::ERR = '';
    my ($pem) = Punk::Passkey::_cose_to_pem($r->{key}->());
    is($pem, undef, "refused: $r->{name}");
    like($Punk::Passkey::ERR, $r->{why}, '...for the documented reason');
}

# A 31-byte x is refused rather than left-padded: the two are a
# different key, and repairing input is how two documents become one.
{
    my $short = vary(-2 => substr($real->{-2}, 1));
    my ($pem) = Punk::Passkey::_cose_to_pem($short);
    is($pem, undef, 'a short coordinate is refused');
    my ($full) = Punk::Passkey::_cose_to_pem($real);
    my $padded = vary(-2 => "\x00" . substr($real->{-2}, 1));
    my ($pad_pem) = Punk::Passkey::_cose_to_pem($padded);
    ok($pad_pem, 'while a genuinely 32-byte coordinate converts');
    isnt($pad_pem, $full,
        'and padding one to length gives a DIFFERENT key - which is why '
      . 'the short one is refused instead of repaired');
}

done_testing;
