#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use File::SOPS;
use Crypt::Age;

# ----------------------------------------------------------------------------
# decrypt must be deterministic: the same document decrypted twice, or two
# identical documents decrypted once each, must produce the same values.
#
# It was not. Roughly one type:float leaf in a hundred came back an order of
# magnitude out -- a stored 1e20 returned as 1e21 -- with the ciphertext, the
# MAC and the document all intact. The cause was outside this distribution but
# reached the caller through it:
#
#   * CryptX's gcm_decrypt_verify returns the plaintext in an SV whose PV
#     buffer is NOT NUL-terminated at SvCUR. That violates Perl's PV
#     invariant, and Perl's own string->number conversion depends on it:
#     sv_2nv falls through to Atof(SvPVX) -- a C string read with no length --
#     for anything grok_number cannot resolve as an integer within a UV, which
#     is every float and every integer wider than 64 bits.
#
#   * So `$plaintext + 0.0` read past the plaintext into whatever byte the
#     allocator happened to leave after it. When that byte was an ASCII digit
#     it became part of the number: "100000000000000000000" parsed as
#     1000000000000000000000.
#
# The fix normalises the scalar where it crosses out of CryptX
# (File::SOPS::Encrypted::decrypt_bytes), so both numeric reads in
# _deserialize_value, the MAC digest and any caller of decrypt_bytes are
# downstream of it.
#
# This test is necessarily statistical: the defect fired only when the byte
# after the buffer was one of the ten digit characters, so a single round trip
# proved nothing and 30 of them proved nothing either -- that sample size is
# what kept this filed as a test flake through two releases. The loop below
# decrypts ~3000 float leaves. On the machine the defect was found on it failed
# ~1.2% of leaves, so the unfixed code fails this test with probability
# 1 - 0.988**3000, i.e. to every digit that fits in a double. On an allocator
# that never leaves a digit character after a freed chunk it would pass
# vacuously -- that is a property of the defect, not a weakness of the
# assertion, and the assertion is still the only thing that can catch a
# regression here.
#
# Values are large integral floats on purpose: their canonical SOPS form is a
# long run of digits, so one extra digit read past the end moves the value by a
# factor of ten rather than by an ulp, and `==` sees it.
# ----------------------------------------------------------------------------

my ($public, $secret) = Crypt::Age->generate_keypair();

my @VALUES      = (1e20, 1e21, -1e20, 1.25e20, 9.87e19, 1.5e-7);
my $LEAVES      = 50;
my $ROUND_TRIPS = 60;

my %input = map { ('k' . $_ => $VALUES[ $_ % @VALUES ]) } 0 .. $LEAVES - 1;

my $mismatches = 0;
my @examples;

for my $run (1 .. $ROUND_TRIPS) {
    my $encrypted = File::SOPS->encrypt(
        data       => \%input,
        recipients => [$public],
        format     => 'yaml',
    );

    my $out = File::SOPS->decrypt(
        encrypted  => $encrypted,
        identities => [$secret],
    );

    for my $key (sort keys %input) {
        next if $out->{$key} == $input{$key};
        $mismatches++;
        push @examples, sprintf('run %d, %s: stored %s, got back %s',
            $run, $key, $input{$key}, $out->{$key})
            if @examples < 5;
    }
}

is(
    $mismatches,
    0,
    sprintf(
        'every one of %d decrypted type:float leaves came back as the value '
            . 'that was stored',
        $ROUND_TRIPS * $LEAVES
    )
) or diag(join "\n", @examples);

done_testing;
