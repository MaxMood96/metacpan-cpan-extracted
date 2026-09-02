use v5.40;
use blib;
use Test2::V0;
use Alien::Zstandard;
#
my $zstd = Alien::Zstandard->new;

# Pre-install: safe defaults before the package is resolved. Only applies to a
# source checkout with no generated ConfigData (e.g. running `prove t/` cold).
SKIP: {
    my $info = $zstd->package_info;
    skip 'ConfigData exists (built); delegation already resolves' => 9 if $info;
    is $zstd->libpath,               undef, 'libpath is undef before install';
    is $zstd->ffi_lib,               undef, 'ffi_lib is undef before install';
    is $zstd->version,               undef, 'version is undef before install';
    is $zstd->kind,                  undef, 'kind is undef before install';
    is $zstd->cflags,                '',    'cflags is empty before install';
    is $zstd->libs,                  '',    'libs is empty before install';
    is $zstd->find_header('zstd.h'), undef, 'find_header is undef before install';
    my @bins = $zstd->bin_dir;
    is [@bins],             [],    'bin_dir is empty before install';
    is $zstd->package_info, undef, 'package_info is undef before install';
}

# Resolved state (post-build or already-installed) validates the real paths.
SKIP: {
    my $info = $zstd->package_info;
    skip 'package not installed; run `perl Build` first' => 7 unless $info;
    ok $zstd->libpath, 'libpath resolved';
    ok $zstd->ffi_lib, 'ffi_lib resolved';
    ok $zstd->version, 'version resolved';
    is $zstd->kind, 'library', 'kind is library';
    like $zstd->cflags, qr{-I}, 'cflags has an include flag';
    like $zstd->libs,   qr{-l}, 'libs has a link flag';
    ok $zstd->find_header('zstd.h'), 'zstd.h findable';
}
#
done_testing;
