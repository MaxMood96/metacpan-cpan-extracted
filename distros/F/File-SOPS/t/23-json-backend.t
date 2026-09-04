#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use Crypt::Age;
use File::SOPS;

# ----------------------------------------------------------------------------
# The JSON wire format must not depend on what the calling program loaded.
#
# JSON::MaybeXS binds to a backend ONCE per process, to whichever of
# Cpanel::JSON::XS and JSON::XS is already in %INC, so before docs/adr/0005 the
# same data was written differently depending on the caller -- and CryptX,
# which File::SOPS::Encrypted loads, drags JSON::XS in on its own. The three
# backends disagree on floats in ways that are not cosmetic:
#
#   * JSON::XS writes an NV -0.0 as `-0`, which parses back as the INTEGER
#     zero and digests as "0" while the MAC covers "-0" -- the document fails
#     its own MAC, here and in sops (exit 51).
#   * JSON::PP writes `0`, losing the sign entirely: same failure.
#   * JSON::XS's DECODER is not correctly rounded: it reads `0.3` back as the
#     double whose shortest form is 0.30000000000000004, so File::SOPS in a
#     JSON::XS process refused valid sops documents.
#
# EVERY check below runs in a fresh child perl, because this file -- like every
# other .t in the suite -- has already bound a backend by the time it runs, and
# an in-process check therefore cannot see the defect at all.
# ----------------------------------------------------------------------------

# Runs $code in a fresh perl with this process's @INC, $preload loaded FIRST
# (before anything of ours), and returns its stdout.
sub _in_a_fresh_perl {
    my ($preload, $code, @args) = @_;
    my @inc = map { "-I$_" } grep { !ref } @INC;
    my @pre = $preload ? ("-M$preload") : ();
    open my $p, '-|', $^X, @inc, @pre, '-e', $code, @args
        or die "cannot fork a perl: $!";
    my $out = do { local $/; <$p> };
    close $p;
    return defined $out ? $out : '';
}

# '' is "whatever File::SOPS itself pulls in", which is the ordinary caller.
my @PRELOADS = ('', 'JSON::XS', 'Cpanel::JSON::XS', 'JSON::PP');

sub _available {
    my ($module) = @_;
    return 1 unless $module;
    my $file = $module; $file =~ s{::}{/}g; $file .= '.pm';
    return eval { require $file; 1 } ? 1 : 0;
}

# ----------------------------------------------------------------------------
# (a) Emitted bytes are identical whatever the caller loaded first.
# ----------------------------------------------------------------------------

my $EMIT_CHILD = <<'CHILD';
use File::SOPS::Format::JSON;
print File::SOPS::Format::JSON->emit({
    one       => 1.0,
    two       => 2.0,
    negzero   => -0.0,
    half      => 1.5,
    big       => 1e20,
    small     => 1.5e-7,
    int       => 42,
    negint    => -1,
    huge_int  => 9223372036854775807,
    str       => '1.0',
    "k\x{e9}y"=> "va\x{ef}ue",
    nothing   => undef,
    nested    => { z => 1, a => 2.0 },
    list      => [ 1, '2', 2.5 ],
});
CHILD

my %emitted;
for my $preload (@PRELOADS) {
    my $name = $preload || '(nothing)';
    SKIP: {
        skip "$preload is not installed", 1 unless _available($preload);
        $emitted{$name} = _in_a_fresh_perl($preload, $EMIT_CHILD);
        ok(length $emitted{$name}, "emit() produced output with $name preloaded")
            or diag("child perl printed nothing");
    }
}

my ($reference_name) = grep { defined $emitted{$_} } '(nothing)', @PRELOADS;
for my $name (sort keys %emitted) {
    next if $name eq $reference_name;
    is($emitted{$name}, $emitted{$reference_name},
        "emit() writes identical bytes with $name preloaded")
        or diag("the JSON backend is being decided by the calling program "
              . "again -- see docs/adr/0005\n"
              . "--- $reference_name ---\n$emitted{$reference_name}"
              . "--- $name ---\n$emitted{$name}");
}

# And the bytes are the ones ADR 0005 chose, so that re-pinning the whole
# distribution to a different backend is a failure and not a silent success:
# `-0.0` is the rendering both implementations can verify, and `1.0` is the one
# sops accepts (it writes `1` itself, which digests identically).
if (defined $emitted{$reference_name}) {
    like($emitted{$reference_name}, qr/"negzero" : -0\.0/,
        'an NV -0.0 is written as -0.0, not as -0 (JSON::XS) or 0 (JSON::PP)')
        or diag("-0 parses back as the integer zero and digests as \"0\" while "
              . "the MAC covers \"-0\"; such a document fails its own MAC and "
              . "sops's");
    like($emitted{$reference_name}, qr/"one" : 1\.0/,
        'an NV 1.0 is written as 1.0');
    like($emitted{$reference_name}, qr/"int" : 42/,
        'and an integer is still written as an integer');
}

# ----------------------------------------------------------------------------
# (b) Parsed values are identical -- measured as the bytes that reach the MAC.
#
# This is the half that rejects other people's documents: value_to_bytes is
# what the digest is taken over, so a decoder that is one ULP off makes a valid
# sops file fail verification here.
# ----------------------------------------------------------------------------

my $PARSE_CHILD = <<'CHILD';
use File::SOPS::Format::JSON;
use File::SOPS::Encrypted;
my ($data) = File::SOPS::Format::JSON->parse(
    '{"a":0.3,"b":0.7,"c":1.0,"d":-0.0,"e":0.30000000000000004,"f":123.456}'
);
print join ',', map { File::SOPS::Encrypted->value_to_bytes($data->{$_}) }
                sort keys %$data;
CHILD

my %parsed;
for my $preload (@PRELOADS) {
    my $name = $preload || '(nothing)';
    SKIP: {
        skip "$preload is not installed", 1 unless _available($preload);
        $parsed{$name} = _in_a_fresh_perl($preload, $PARSE_CHILD);
        is($parsed{$name}, '0.3,0.7,1,-0,0.30000000000000004,123.456',
            "parse() reads floats back exactly with $name preloaded")
            or diag("the decoder is not correctly rounded (JSON::XS reads 0.3 "
                  . "as 0.30000000000000004), so a document written by sops "
                  . "fails MAC verification here -- see docs/adr/0005");
    }
}

# ----------------------------------------------------------------------------
# (c) A document with these values survives its own round trip, in every
#     process. This is the failure a caller actually sees: `-0` fails the MAC
#     that was computed over `-0`, and it does so with no configuration beyond
#     the default unencrypted_suffix.
# ----------------------------------------------------------------------------

my ($public, $secret) = Crypt::Age->generate_keypair();
my $tempdir = tempdir(CLEANUP => 1);
my $keyfile = "$tempdir/identity";
open my $kfh, '>:raw', $keyfile or die $!;
print $kfh $secret;
close $kfh;

my $ROUNDTRIP_CHILD = <<'CHILD';
use File::SOPS;
my ($public, $keyfile) = @ARGV;
my $secret = do { open my $r, '<:raw', $keyfile or die $!; local $/; <$r> };
my $encrypted = eval {
    File::SOPS->encrypt(
        data => {
            negzero_unencrypted => -0.0,
            third_unencrypted   => 0.3,
            one_unencrypted     => 1.0,
            secret              => 'hunter2',
        },
        recipients => [$public],
        format     => 'json',
    );
};
if ($@) { print "encrypt died: $@"; exit }
my $back = eval { File::SOPS->decrypt(encrypted => $encrypted, identities => [$secret]) };
if ($@) { my $why = (split /\n/, $@)[0]; print "decrypt died: $why"; exit }
printf "%s|%s|%s|%s", $back->{negzero_unencrypted}, $back->{third_unencrypted},
                      $back->{one_unencrypted}, $back->{secret};
CHILD

for my $preload (@PRELOADS) {
    my $name = $preload || '(nothing)';
    SKIP: {
        skip "$preload is not installed", 1 unless _available($preload);
        my $out = _in_a_fresh_perl($preload, $ROUNDTRIP_CHILD, $public, $keyfile);
        is($out, "0|0.3|1|hunter2",
            "a JSON document with unencrypted floats round-trips with $name preloaded")
            or diag("child perl printed '$out'");
    }
}

done_testing();
