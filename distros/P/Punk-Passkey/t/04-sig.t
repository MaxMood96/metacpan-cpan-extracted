#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use File::Temp ();
use PPKTest qw(fixture b64u_decode auth_data cose_bytes hex_to_bytes
               have_openssl);
use Punk::Passkey ();

# The signature seam: an authenticator signs in ASN.1 DER, JOSE wants
# raw r||s, and this converts.
#
# The test is deliberately NOT "my converter agrees with a second
# converter written in Perl by the same author on the same afternoon".
# Two implementations that share an author share his misreadings, so
# the oracle is the round trip: openssl makes the key and the
# signature, this distribution encodes the key and converts the
# signature, and libcrypto - through Crypt::JWS - says whether the two
# still describe the same thing. A conversion that drops a byte, pads
# the wrong end or mangles a leading zero does not verify.

plan skip_all => 'openssl is needed to make real signatures'
    unless have_openssl();

my $dir = File::Temp->newdir;
my $msg = 'the message that was signed';

sub run { my $c = shift; my $o = `$c 2>&1`; return ($? == 0, $o) }

# ---- ES256, end to end -------------------------------------------------------

my ($pem, $x, $y);
{
    my ($ok) = run("openssl ecparam -name prime256v1 -genkey -noout "
                 . "-out $dir/ec.key");
    ok($ok, 'openssl made a P-256 key');
    (my $o, my $t) = run("openssl ec -in $dir/ec.key -pubout -out $dir/ec.pub");
    my (undef, $text) = run("openssl ec -in $dir/ec.key -text -noout");
    my ($pub) = $text =~ /pub:\s*((?:[0-9a-f]{2}[:\s]*)+)/s;
    $pub =~ s/[^0-9a-f]//g if defined $pub;
    ok(defined $pub && length($pub) == 130,
        'and printed its uncompressed public point');
    $x = hex_to_bytes(substr $pub, 2, 64);
    $y = hex_to_bytes(substr $pub, 66, 64);
}

# the key as a COSE map, the way an authenticator would send it, then
# back out through this distribution's encoder
my $cose = { 1 => 2, 3 => -7, -1 => 1, -2 => $x, -3 => $y };
my ($mypem, $alg) = Punk::Passkey::_cose_to_pem($cose);
ok($mypem, 'the point encodes to PEM here') or diag $Punk::Passkey::ERR;
is($alg, -7, 'as ES256');

{
    # openssl's own PEM for the same key, byte for byte
    open my $fh, '<', "$dir/ec.pub" or die $!;
    my $theirs = do { local $/; <$fh> };
    close $fh;
    (my $a = $mypem)  =~ s/\s+//g;
    (my $b = $theirs) =~ s/\s+//g;
    is($a, $b,
        'and it is byte-for-byte the SubjectPublicKeyInfo openssl writes '
      . 'for the same key - the encoder is checked against the tool, not '
      . 'against its own idea of DER');
}

# sign with openssl, verify through this dist's conversion + Crypt::JWS
open my $mf, '>', "$dir/msg" or die $!;
print {$mf} $msg;
close $mf;

my ($high_bit_r, $high_bit_s, $short_int, $count) = (0, 0, 0, 0);
for my $i (1 .. 40) {
    my ($ok) = run("openssl dgst -sha256 -sign $dir/ec.key "
                 . "-out $dir/sig.$i $dir/msg");
    unless ($ok) { fail("openssl signed run $i"); next }
    open my $sf, '<', "$dir/sig.$i" or die $!;
    binmode $sf;
    my $der = do { local $/; <$sf> };
    close $sf;
    $count++;

    # classify the DER shape, so the loop can report which edge cases
    # it actually reached rather than claiming coverage it did not get
    my $seq_len = ord substr($der, 1, 1);
    my $rlen    = ord substr($der, 3, 1);
    my $slen    = ord substr($der, 5 + $rlen, 1);
    $high_bit_r++ if $rlen == 33;
    $high_bit_s++ if $slen == 33;
    $short_int++  if $rlen < 32 || $slen < 32;

    my $raw = Punk::Passkey::_sig_der_to_raw($der);
    ok(defined $raw && length($raw) == 64, "signature $i converts to 64 bytes")
        or diag "$Punk::Passkey::ERR (r=$rlen s=$slen)";

    my $v = Punk::Passkey::_verify($mypem, -7, $msg, $der);
    is($v, 1, "...and verifies against the message openssl signed")
        or diag $Punk::Passkey::ERR;
}

ok($count >= 30, "$count real signatures were exercised");
ok($high_bit_r + $high_bit_s > 0,
    "the 33-byte DER INTEGER case was reached ($high_bit_r r, $high_bit_s s) "
  . '- the leading zero DER adds when the high bit is set, which a '
  . 'converter that simply copied the bytes would get wrong');
diag("shorter-than-32-byte integers seen: $short_int")
    if $short_int;

# ---- a wrong message does not verify -----------------------------------------
# Without this the test above would pass just as well against a verify
# that returned 1 unconditionally.
{
    my ($ok) = run("openssl dgst -sha256 -sign $dir/ec.key -out $dir/s0 $dir/msg");
    open my $sf, '<', "$dir/s0" or die $!;
    binmode $sf;
    my $der = do { local $/; <$sf> };
    close $sf;
    is(Punk::Passkey::_verify($mypem, -7, $msg, $der), 1, 'the real pair verifies');
    is(Punk::Passkey::_verify($mypem, -7, "$msg!", $der), 0,
        'the same signature over a different message does not');
    my $bad = $der;
    substr($bad, -1, 1) = chr((ord(substr($bad, -1, 1)) ^ 0xff) & 0xff);
    my $v = Punk::Passkey::_verify($mypem, -7, $msg, $bad);
    ok(!$v, 'and a signature with a byte flipped does not');
}

# ---- RS256 -------------------------------------------------------------------
# Windows Hello registers RSA keys, so the RSA half of the encoder is
# not decoration. PKCS#1 signatures are already the width JOSE wants,
# so nothing is converted - but the key still has to be encoded, and
# that is real DER with real lengths rather than a constant.
{
    my ($ok) = run("openssl genrsa -out $dir/rsa.key 2048");
    ok($ok, 'openssl made a 2048-bit RSA key');
    run("openssl rsa -in $dir/rsa.key -pubout -out $dir/rsa.pub");
    my (undef, $text) = run("openssl rsa -in $dir/rsa.key -text -noout");
    my ($modhex) = $text =~ /modulus:\s*((?:[0-9a-f]{2}[:\s]*)+)/s;
    $modhex =~ s/[^0-9a-f]//g;
    $modhex =~ s/\A00//;                       # openssl prints the sign octet
    my $n = hex_to_bytes($modhex);
    is(length $n, 256, 'with a 256-byte modulus');
    my $e = hex_to_bytes('010001');

    my ($rpem, $ralg) = Punk::Passkey::_cose_to_pem(
        { 1 => 3, 3 => -257, -1 => $n, -2 => $e });
    ok($rpem, 'the RSA key encodes to PEM') or diag $Punk::Passkey::ERR;
    is($ralg, -257, 'as RS256');

    open my $fh, '<', "$dir/rsa.pub" or die $!;
    my $theirs = do { local $/; <$fh> };
    close $fh;
    (my $a = $rpem)   =~ s/\s+//g;
    (my $b = $theirs) =~ s/\s+//g;
    is($a, $b, 'byte-for-byte what openssl writes for the same modulus '
             . 'and exponent - the DER lengths are right, not merely '
             . 'accepted');

    run("openssl dgst -sha256 -sign $dir/rsa.key -out $dir/rsa.sig $dir/msg");
    open my $sf, '<', "$dir/rsa.sig" or die $!;
    binmode $sf;
    my $sig = do { local $/; <$sf> };
    close $sf;
    is(Punk::Passkey::_verify($rpem, -257, $msg, $sig), 1,
        'and an RS256 signature verifies through it, unconverted');
    is(Punk::Passkey::_verify($rpem, -257, "$msg!", $sig), 0,
        'while one over a different message does not');
}

# ---- what the converter refuses ----------------------------------------------

my @bad = (
    {   name => 'not a SEQUENCE',
        hex  => '3102020101020101',
        why  => qr/SEQUENCE/,
    },
    {   name => 'a sequence length that does not match what follows',
        hex  => '3020020101020101',
        why  => qr/sequence length mismatch/,
    },
    {   name => 'a second element that is not an INTEGER',
        hex  => '3006020101040101',
        why  => qr/expected an INTEGER/,
    },
    {   name => 'an integer wider than a P-256 coordinate',
        hex  => '3047022100' . ('aa' x 32) . '022100' . ('bb' x 32),
        why  => qr/sequence length mismatch|integer too wide/,
    },
    {   name => 'a negative integer',
        hex  => '3006020180020101',
        why  => qr/negative integer/,
    },
    {   name => 'a non-minimal leading zero',
        hex  => '3007020200010201' . '01',
        why  => qr/non-minimal integer/,
    },
    {   name => 'trailing bytes after the two integers',
        hex  => '30070201010201010a',
        why  => qr/sequence length mismatch|trailing/,
    },
    {   name => 'a long-form length',
        hex  => '3081020201010201',
        why  => qr/long-form|mismatch|too short/,
    },
    {   name => 'nothing at all',
        hex  => '',
        why  => qr/too short/,
    },
);

for my $b (@bad) {
    $Punk::Passkey::ERR = '';
    my $raw = Punk::Passkey::_sig_der_to_raw(hex_to_bytes($b->{hex}));
    is($raw, undef, "refused: $b->{name}");
    like($Punk::Passkey::ERR, $b->{why}, '...for the documented reason');
}

# A short integer IS padded, because the raw form is fixed-width and a
# 31-byte r is a legitimate r that happened to be small. That is
# reading a magnitude, not repairing input - the distinction the COSE
# coordinate rule turns the other way, and worth pinning so the two do
# not get 'made consistent' later.
{
    my $der = hex_to_bytes('3006020101020102');    # r = 1, s = 2
    my $raw = Punk::Passkey::_sig_der_to_raw($der);
    ok(defined $raw, 'a small r and s convert');
    is(length $raw, 64, '...to the full 64 bytes');
    is(unpack('H*', substr($raw, 0, 32)), ('00' x 31) . '01',
        '...with r left-padded, big-endian');
    is(unpack('H*', substr($raw, 32)), ('00' x 31) . '02', '...and s likewise');
}

done_testing;
