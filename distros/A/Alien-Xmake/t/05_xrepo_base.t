use v5.40;
use blib;
use Test2::V0 '!subtest', -no_srand => 1;
use Test2::Util::Importer 'Test2::Tools::Subtest' => ( subtest_streamed => { -as => 'subtest' } );
use Path::Tiny qw[path cwd];
use Alien::Xrepo::Base;
use File::Temp qw[tempdir];
use experimental 'class';

# Test package
class Alien::Xrepo::TestPackage : isa(Alien::Xrepo::Base) {
    method pkg_name {'zlib'}
}

# A subclass that overrides the default install options
class Alien::Xrepo::TestPackageWithOpts : isa(Alien::Xrepo::Base) {
    method pkg_name     {'zlib'}
    method install_opts { return ( kind => 'shared' ); }
}
my $tmp = path( tempdir( CLEANUP => 1 ) );
#
my $alien = Alien::Xrepo::TestPackage->new( root => $tmp, verbose => 1 );
isa_ok $alien, ['Alien::Xrepo::Base'], 'isa Alien::Xrepo::Base';

# Delegation before any installation returns safe defaults
subtest 'pre-install delegation' => sub {
    my $fresh = Alien::Xrepo::TestPackage->new( root => $tmp, verbose => 0 );
    is $fresh->libpath,               undef, 'libpath is undef before install';
    is $fresh->ffi_lib,               undef, 'ffi_lib is undef before install';
    is $fresh->version,               undef, 'version is undef before install';
    is $fresh->kind,                  undef, 'kind is undef before install';
    is $fresh->cflags,                '',    'cflags is empty before install';
    is $fresh->libs,                  '',    'libs is empty before install';
    is $fresh->find_header('zlib.h'), undef, 'find_header is undef before install';
    my @bins0 = $fresh->bin_dir;
    is [@bins0],             [ U() ], 'bin_dir is empty before install';
    is $fresh->package_info, undef,   'package_info is undef before install';
};

# Test install
my $info = $alien->install;
ok $info,           'Installed package';
ok $alien->libpath, 'Got libpath: ' . $alien->libpath;
ok $alien->ffi_lib, 'Got ffi_lib';
ok $alien->cflags,  'Got cflags: ' . $alien->cflags;
ok $alien->libs,    'Got libs: ' . $alien->libs;
is $alien->kind, 'library', 'Kind is library';
ok $alien->version, 'Got version: ' . $alien->version;

# package_info returns the underlying metadata object
my $pi = $alien->package_info;
isa_ok $pi, ['Alien::Xrepo::PackageInfo'], 'package_info returns PackageInfo';
is $pi->version, $alien->version, 'package_info version matches delegation';
is $pi->kind,    $alien->kind,    'package_info kind matches delegation';
is $pi->libpath, $alien->libpath, 'package_info libpath matches delegation';
like $alien->cflags, qr{-I}, 'cflags include at least one -I include flag';
my $cflag_inc_count = () = $alien->cflags =~ /-I/g;
is $cflag_inc_count, scalar @{ $pi->includedirs }, 'one -I flag per includedir';

# bin_dir lists the directories holding executables / DLLs. A pure library (zlib) only carries one
# when its install root has a bin/ subdir (e.g. DLLs on Windows); on Unix the shared lib sits in
# lib/ so bin_dir may be empty. What is guaranteed is that it mirrors package_info and never lies
# about the layout.
my @zlib_bin_dirs = $alien->bin_dir;
is [@zlib_bin_dirs], [ $alien->package_info->bin_dir ], 'zlib bin_dir matches package_info';
if (@zlib_bin_dirs) {
    my $expect = path( $alien->package_info->installdir )->child('bin');
    ok( ( map { path($_) } @zlib_bin_dirs )[0] eq $expect, 'zlib bin_dir is the installdir/bin dir' );
}
else {
    ok !-d path( $alien->package_info->installdir )->child('bin'), 'zlib has no bin/ subdir on this platform, so bin_dir is empty';
}

# Idempotency: installing again reuses the cached package
my $info2 = $alien->install;
ok $info2,          'Install is idempotent';
ok $info2->libpath, 'Re-installed package has a libpath';

# Test delegation and headers
my $header = $alien->find_header('zlib.h');
ok $header,    'Found zlib.h';
ok -f $header, 'Header file exists';

# Test that a missing header returns undef
my $missing = $alien->find_header('does_not_exist.h');
ok !defined $missing, 'find_header returns undef for a missing header';

# Test version_constraint via a dedicated subclass
subtest 'version constraint' => sub {
    my $constrained = Alien::Xrepo::TestPackage->new( root => $tmp, verbose => 0, version_constraint => '1.3.x' );
    my $cinfo       = $constrained->install;
    ok $cinfo,                       'Installed with version constraint';
    ok $cinfo->version =~ /^v?1\.3/, 'Version satisfies 1.3.x constraint: ' . $cinfo->version;
};
subtest 'with binary package' => sub {

    class Alien::Xrepo::TestBin : isa(Alien::Xrepo::Base) {
        method pkg_name {'ninja'}
    }
    my $alien_bin = Alien::Xrepo::TestBin->new( root => $tmp, verbose => 1 );
    my $info_bin  = $alien_bin->install;
    ok $info_bin, 'Installed ninja';
    is $alien_bin->kind, 'binary', 'Kind is binary';
    my @bin_dirs = $alien_bin->bin_dir;
    ok @bin_dirs, 'Got bin_dir';
    is [ $alien_bin->bin_dir ], [ $alien_bin->package_info->bin_dir ], 'bin_dir matches package_info';

    # Upgrade (verify it runs without error)
    ok $alien_bin->upgrade, 'Upgrade ninja';
};

# install_opts is respected during the Builder phase; at runtime install still succeeds with the
# explicit opts passed to install()
subtest install_opts => sub {
    my $with_opts = Alien::Xrepo::TestPackageWithOpts->new( root => $tmp, verbose => 0 );
    ok $with_opts->can('install_opts'), 'subclass implements install_opts';
    my $optinfo = $with_opts->install;
    ok $optinfo, 'Installed package with install_opts';
    is $optinfo->kind, 'library', 'Shared library kind after install with opts';
};

# Multi-package: pkg_name may return a list/arrayref of names; each is installed and recorded
# separately, mirroring Alien::Build's `pkg_name => [...]`.
subtest 'multiple packages' => sub {

    # zlib (library) is the primary; ninja (binary) is the secondary.
    class Alien::Xrepo::TestMulti : isa(Alien::Xrepo::Base) {
        method pkg_name { [ 'zlib', 'ninja' ] }
    }
    my $multi = Alien::Xrepo::TestMulti->new( root => $tmp, verbose => 0 );
    is [ $multi->package_names ], [ 'zlib', 'ninja' ], 'package_names returns both in order';
    my $minfo = $multi->install;
    ok $minfo,          'Multi-package install succeeded';
    ok $minfo->libpath, 'Primary package has a libpath';

    # Per-package delegation
    ok $multi->libpath('zlib'), 'zlib libpath via package name';
    is $multi->kind('zlib'),  'library', 'zlib kind is library';
    is $multi->kind('ninja'), 'binary',  'ninja kind is binary';
    ok $multi->cflags('zlib'), 'zlib cflags via package name';
    is $multi->package_info('zlib')->kind,  'library', 'package_info zlib kind';
    is $multi->package_info('ninja')->kind, 'binary',  'package_info ninja kind';

    # ninja is a binary with no library libpath; it instead has bin_dir
    is $multi->libpath('ninja'), undef, 'ninja (binary) has no libpath';
    ok $multi->bin_dir('ninja'), 'ninja bin_dir via package name';

    # No-arg delegation still refers to the primary package
    ok $multi->package_info, 'package_info (no arg) resolves to the primary package';
    is $multi->kind, 'library', 'kind (no arg) is the primary (library)';

    # Headers are searched per-package
    ok $multi->find_header( 'zlib.h', 'zlib' ), 'zlib.h findable via package name';
    ok $multi->find_header('zlib.h'),           'zlib.h findable on the primary package (no arg)';
};

# Alien::Build-aligned accessors: alt(), split_flags(), dynamic_libs(), install_type(), dist_dir(),
# and the *_static aliases.
subtest 'alien-style accessors' => sub {
    my $alien = Alien::Xrepo::TestPackage->new( root => $tmp, verbose => 0 );
    $alien->install;

    # alt() without a name returns the primary (self); with a name a delegate.
    is $alien->alt,         $alien, 'alt() returns self for the primary package';
    is $alien->alt('zlib'), $alien, 'alt(primary) returns self';

    # install_type: share once installed, system before.
    is $alien->install_type, 'share', 'install_type is share after install';
    my $fresh = Alien::Xrepo::TestPackage->new( root => $tmp, verbose => 0 );
    is $fresh->install_type, 'system', 'install_type is system before install';

    # split_flags turns a flags string into a list.
    is [ $alien->split_flags( $alien->cflags ) ], [ split ' ', $alien->cflags ], 'split_flags splits cflags';
    is [ $alien->split_flags('') ],               [ U() ],                       'split_flags of empty string is empty';
    is [ $alien->split_flags(undef) ],            [ U() ],                       'split_flags of undef is empty';

    # *_static aliases return the same flags.
    is $alien->cflags_static, $alien->cflags, 'cflags_static aliases cflags';
    is $alien->libs_static,   $alien->libs,   'libs_static aliases libs';

    # dynamic_libs enumerates the library files of the package.
    my @dynlibs = $alien->dynamic_libs;
    ok @dynlibs, 'dynamic_libs returns at least one library path';

    # dist_dir points at where the package lives.
    ok $alien->dist_dir, 'dist_dir is defined after install';
};

# alt() selects a non-primary package across the whole accessor surface.
subtest 'alt delegate' => sub {

    class Alien::Xrepo::TestMultiAlt : isa(Alien::Xrepo::Base) {
        method pkg_name { [ 'zlib', 'ninja' ] }
    }
    my $multi = Alien::Xrepo::TestMultiAlt->new( root => $tmp, verbose => 0 );
    $multi->install;
    my $alt_ninja = $multi->alt('ninja');
    isa_ok $alt_ninja, ['Alien::Xrepo::Base::Alt'], 'alt(ninja) is a delegate';
    is $alt_ninja->kind,     'binary', 'alt(ninja)->kind is binary';
    is $alt_ninja->pkg_name, 'ninja',  'alt(ninja)->pkg_name is ninja';
    is $alt_ninja->libpath,  undef,    'alt(ninja)->libpath is undef (binary)';
    ok $alt_ninja->bin_dir,  'alt(ninja)->bin_dir populated';
    ok $alt_ninja->dist_dir, 'alt(ninja)->dist_dir populated';
    is $alt_ninja->install_type, 'share', 'alt(ninja)->install_type is share';
    my $alt_zlib = $multi->alt('zlib');
    is $alt_zlib->kind, 'library', 'alt(zlib)->kind is library';
    ok $alt_zlib->libpath, 'alt(zlib)->libpath populated';
    ok $alt_zlib->cflags,  'alt(zlib)->cflags populated';
    is $alt_ninja->alt('zlib')->kind, 'library', 'delegate->alt(zlib) re-selects';

    # accessor name arg and alt() agree.
    is $multi->alt('zlib')->libpath, $multi->libpath('zlib'), 'alt(zlib)->libpath == libpath(zlib)';
};
#
done_testing;
