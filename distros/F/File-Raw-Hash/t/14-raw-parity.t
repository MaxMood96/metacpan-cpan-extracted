#!perl
use 5.008003;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use File::Raw qw(import);
use File::Raw::Hash;

# The raw format against the hex format, every algorithm, plain and
# HMAC-wrapped. This is the phase-0 gate of plan_frh_abi: the C ABI
# hands out raw digest bytes through the HF_RAW path, so raw and
# formatted output must be the same bytes under different clothes -
# including the HMAC outer pass, which runs before formatting and
# must therefore be identical in both.
#
# (The plan assumed raw bytes died inside finish and a new seam was
# needed; HF_RAW already existed end to end. This test is what makes
# that discovery load-bearing instead of lucky.)

my @ALGOS = qw(sha256 sha512 sha1 md5 crc32 xxh64 blake3);
my @HMAC  = qw(sha256 sha512 sha1 md5);

# multi-block content so streaming boundaries are exercised too
my $content = join '', map { chr(33 + $_ % 90) } 0 .. 9999;

my ($fh, $path) = tempfile(UNLINK => 1);
binmode $fh;
print $fh $content;
close $fh;

for my $algo (@ALGOS) {
    my ($raw, $hex);
    file_slurp($path, plugin => 'hash', algo => $algo,
               format => 'raw', into => \$raw);
    file_slurp($path, plugin => 'hash', algo => $algo,
               format => 'hex', into => \$hex);
    is unpack('H*', $raw), $hex, "$algo: raw is unhexed hex";
}

for my $algo (@HMAC) {
    my ($raw, $hex);
    file_slurp($path, plugin => 'hash', algo => $algo,
               hmac_key => 'a key longer than nothing',
               format => 'raw', into => \$raw);
    file_slurp($path, plugin => 'hash', algo => $algo,
               hmac_key => 'a key longer than nothing',
               format => 'hex', into => \$hex);
    is unpack('H*', $raw), $hex, "hmac-$algo: raw is unhexed hex";
}

# and the empty stream, where a formatting bug hides easiest
my ($efh, $epath) = tempfile(UNLINK => 1);
close $efh;
for my $algo (@ALGOS) {
    my ($raw, $hex);
    file_slurp($epath, plugin => 'hash', algo => $algo,
               format => 'raw', into => \$raw);
    file_slurp($epath, plugin => 'hash', algo => $algo,
               format => 'hex', into => \$hex);
    is unpack('H*', $raw), $hex, "$algo: raw parity on the empty stream";
}

done_testing;
