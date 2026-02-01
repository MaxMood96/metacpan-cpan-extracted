use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

# Platform-specific linking against util shared library
# On non-macOS platforms, symbols from util aren't automatically visible
my $extra_libs = '';
my $extra_ldfrom = '';

if ($^O eq 'linux' || $^O eq 'freebsd' || $^O eq 'openbsd' || $^O eq 'netbsd' ||
    $^O eq 'solaris' || $^O eq 'sunos' || $^O eq 'dragonfly') {
    # Unix ELF systems: link against util.so with $ORIGIN-relative rpath
    # $ORIGIN means "directory of this .so file" - util.so is in ../util/
    $extra_libs = '-Wl,-rpath,\$ORIGIN/../util';
    $extra_ldfrom = '../../../blib/arch/auto/util/util.so';
}
elsif ($^O eq 'MSWin32' || $^O eq 'cygwin' || $^O eq 'msys') {
    # Windows/Cygwin/MSYS: link against util DLL
    my $dll_ext = $Config{dlext} || 'dll';
    $extra_ldfrom = "../../../blib/arch/auto/util/util.$dll_ext";
}
# macOS/darwin: no special linking needed (flat namespace makes symbols visible)

my %makefile_args = (
    NAME              => 'util_export_test',
    VERSION           => '0.01',
    PREREQ_PM         => {},
    ABSTRACT          => 'Test module for util export registry C API',
    AUTHOR            => 'LNATION <email@lnation.org>',
    LICENSE           => 'perl',
    LIBS              => [$extra_libs],
    DEFINE            => '',
    INC               => '-I. -I../../../xs/util',
    C                 => ['util_export_test.c'],
    OBJECT            => 'util_export_test$(OBJ_EXT)',
    OPTIMIZE          => '-O3',
    INST_LIB          => '../../../blib/lib',
    INST_ARCHLIB      => '../../../blib/arch',
);

# On Linux, link against util.so directly
if ($extra_ldfrom) {
    $makefile_args{OBJECT} = "util_export_test\$(OBJ_EXT) $extra_ldfrom";
}

WriteMakefile(%makefile_args);
