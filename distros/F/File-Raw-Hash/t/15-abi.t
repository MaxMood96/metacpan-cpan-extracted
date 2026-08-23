#!perl
use 5.008003;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use File::Raw qw(import);
use File::Raw::Hash;

# The C ABI: resolvable, versioned, and agreeing byte for byte with
# the plugin path. The selftest drives every table member from the C
# side - where the contract actually lives - and reports named flags,
# so a failure names its member instead of reporting "not ok 1". It
# also returns each algorithm's one-shot "abc" digest as hex, which
# this file compares against the same digest taken through file_slurp:
# two paths, one truth.

my $ptr = File::Raw::Hash::_abi_ptr();
ok $ptr, 'the table resolves to a non-NULL pointer';
is $ptr, File::Raw::Hash::_abi_ptr(), 'and is stable across calls';

my $st = File::Raw::Hash::_abi_selftest();
is ref $st, 'HASH', 'selftest reports';
is $st->{version}, 1, 'FRH_ABI_VERSION is 1';
ok $st->{registry_ok}, 'registry: dense ids, names round-trip, '
                     . 'unknowns refused';
ok $st->{digest_ok},   'one-shot digest works for every algorithm';
ok $st->{hmac_ok},     'HMAC-SHA1 matches RFC 2202 case 1 in C';
ok $st->{runner_ok},   'lockstep runner over a split stream equals '
                     . 'the one-shots';
ok $st->{edges_ok},    'double finish, mixed set_hmac, bad ids and '
                     . 'free(NULL) all behave';

# two paths, one truth: the ABI's digest of "abc" against the
# plugin's, for every algorithm the registry names
my ($fh, $path) = tempfile(UNLINK => 1);
binmode $fh;
print $fh 'abc';
close $fh;

my $digests = $st->{digests};
is ref $digests, 'HASH', 'selftest carries per-algorithm digests';

for my $algo (sort keys %$digests) {
    my $hex;
    file_slurp($path, plugin => 'hash', algo => $algo,
               format => 'hex', into => \$hex);
    is $digests->{$algo}, $hex,
        "$algo: ABI one-shot equals the plugin path";
}

# and the known-vector anchor, independent of both paths
is $digests->{sha256},
   'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
   'sha256("abc") is the FIPS 180 vector through the ABI';

done_testing;
