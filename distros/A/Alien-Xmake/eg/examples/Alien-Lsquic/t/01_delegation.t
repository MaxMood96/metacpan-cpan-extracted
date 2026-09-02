use v5.40;
use blib;
use Test2::V0;
use Alien::lsquic;
#
my $lsquic = Alien::lsquic->new;

# Pre-install: safe defaults before the package is resolved. Only applies to a
# source checkout with no generated ConfigData (e.g. running `prove t/` cold).
SKIP: {
    my $info = $lsquic->package_info;
    skip 'ConfigData exists (built); delegation already resolves' => 8 if $info;
    is $lsquic->libpath, undef, 'libpath is undef before install';
    is $lsquic->ffi_lib, undef, 'ffi_lib is undef before install';
    is $lsquic->version, undef, 'version is undef before install';
    is $lsquic->kind,    undef, 'kind is undef before install';
    is $lsquic->cflags,  '',    'cflags is empty before install';
    is $lsquic->libs,    '',    'libs is empty before install';
    my @bins = $lsquic->bin_dir;
    is [@bins],               [],    'bin_dir is empty before install';
    is $lsquic->package_info, undef, 'package_info is undef before install';
}

# lsquic is a heavy CMake/Meson/boringssl build; only validate post-build
# delegation when ConfigData was actually generated.
SKIP: {
    my $info = $lsquic->package_info;
    skip 'package not installed; run `perl Build` first' => 4 unless $info;
    ok $lsquic->libpath,                 'libpath resolved';
    ok $lsquic->version,                 'version resolved';
    ok $lsquic->cflags,                  'cflags resolved';
    ok $lsquic->find_header('lsquic.h'), 'lsquic.h findable';
}
#
done_testing;
