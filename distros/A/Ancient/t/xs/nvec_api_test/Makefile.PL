use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

# Platform-specific linking against nvec shared library
# On non-macOS platforms, symbols from nvec aren't automatically visible
my $extra_libs = '';
my $extra_ldfrom = '';

if ($^O eq 'linux' || $^O eq 'freebsd' || $^O eq 'openbsd' || $^O eq 'netbsd' ||
    $^O eq 'solaris' || $^O eq 'sunos' || $^O eq 'dragonfly') {
    # Unix ELF systems: link against nvec.so with $ORIGIN-relative rpath
    # $ORIGIN means "directory of this .so file" - nvec.so is in ../nvec/
    $extra_libs = '-Wl,-rpath,\$ORIGIN/../nvec';
    $extra_ldfrom = '../../../blib/arch/auto/nvec/nvec.so';
}
elsif ($^O eq 'MSWin32' || $^O eq 'cygwin' || $^O eq 'msys') {
    # Windows/Cygwin/MSYS: link against nvec DLL
    my $dll_ext = $Config{dlext} || 'dll';
    $extra_ldfrom = "../../../blib/arch/auto/nvec/nvec.$dll_ext";
}
# macOS/darwin: no special linking needed (flat namespace makes symbols visible)

my %makefile_args = (
    NAME              => 'nvec_api_test',
    VERSION           => '0.01',
    PREREQ_PM         => {},
    ABSTRACT          => 'Test module for nvec C API',
    AUTHOR            => 'LNATION <email@lnation.org>',
    LICENSE           => 'perl',
    LIBS              => [$extra_libs],
    DEFINE            => '',
    INC               => '-I. -I../../../xs/nvec',
    C                 => ['nvec_api_test.c'],
    OBJECT            => 'nvec_api_test$(OBJ_EXT)',
    OPTIMIZE          => '-O3',
    INST_LIB          => '../../../blib/lib',
    INST_ARCHLIB      => '../../../blib/arch',
);

# On Linux, link against nvec.so directly
if ($extra_ldfrom) {
    $makefile_args{OBJECT} = "nvec_api_test\$(OBJ_EXT) $extra_ldfrom";
}

WriteMakefile(%makefile_args);
