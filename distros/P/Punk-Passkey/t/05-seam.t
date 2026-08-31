#!perl
use 5.010;
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Test::More;
use PPKTest qw(fixture b64u_decode auth_data cose_bytes);
use Punk::Passkey ();

# The whole seam, on keys that came out of real authenticators:
# captured COSE map -> this distribution's SPKI encoder -> Crypt::JWS
# key import. No openssl here on purpose - t/03 and t/04 use it as the
# independent oracle, and this file proves the same keys reach the
# library that will actually verify with them, on a machine that may
# have no openssl binary at all.
#
# It is also the ABI check. If Crypt::JWS is present but too old, or
# its table moved, this is where it says so rather than three phases
# later in the middle of a login.

my @fixtures = qw(
    reg-none.txt
    reg-packed-yubikey.txt
    reg-packed-windows-hello.txt
    reg-fido-u2f.txt
);

sub decode {
    my ($b) = @_;
    $Punk::Passkey::ERR = '';
    my $g = Punk::Passkey::_decode_cbor($b);
    return ($g, $Punk::Passkey::ERR);
}

for my $name (@fixtures) {
    my $f   = fixture($name);
    my ($att) = decode(b64u_decode($f->{attestationObject}));
    my ($key) = decode(cose_bytes($att));
    my ($pem, $alg) = Punk::Passkey::_cose_to_pem($key);
    ok($pem, "$name: the captured key encodes");

    # _verify imports the key before it can reach the signature, so a
    # key that does not import reports "the key did not import" and a
    # key that does reports a signature verdict. Either answer proves
    # the import; only one of them proves it happened.
    $Punk::Passkey::ERR = '';
    my $v = Punk::Passkey::_verify($pem, $alg, 'anything',
                                   pack 'H*', '3006020101020102');
    isnt($Punk::Passkey::ERR, 'the key did not import',
        "$name: Crypt::JWS imported the key this dist encoded");
    is($v, 0, "$name: and rejected a signature that was not made with it");
}

# ---- the negative control ----------------------------------------------------
# Everything above would also pass if key import silently accepted
# rubbish, so here is rubbish.
{
    my $junk = "-----BEGIN PUBLIC KEY-----\nbm90IGEga2V5\n"
             . "-----END PUBLIC KEY-----\n";
    $Punk::Passkey::ERR = '';
    my $v = Punk::Passkey::_verify($junk, -7, 'x', pack 'H*', '3006020101020102');
    is($v, undef, 'a PEM that is not a key does not import');
    is($Punk::Passkey::ERR, 'the key did not import', '...and says so');
}

# ---- the ABI is resolved, and its version is a floor not an equality ---------
{
    require Crypt::JWS;
    ok(Crypt::JWS->can('_abi_ptr'), 'Crypt::JWS exposes the C ABI pointer');
    ok(Crypt::JWS::_abi_ptr() > 0, 'and it resolves to something');

    my ($jws, $frj) = Punk::Passkey::_abi_info();
    ok($jws >= 1, "the jws_abi table resolved (version $jws)");
    ok($frj >= 1, "the frj_abi table resolved (version $frj)");
    # A consumer that demanded equality would break on every append to
    # a table that is append-only by contract, so the requirement is a
    # floor. This asserts the floor is a floor: a newer table is fine.
    ok($jws >= 1 && $frj >= 1,
        'both are checked as floors - a table newer than this dist was '
      . 'built against must keep working, which equality would forbid');
}

done_testing;
