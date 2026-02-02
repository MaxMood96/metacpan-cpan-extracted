use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

# Platform-specific linking against file shared library
my $extra_libs = '';
my $extra_ldfrom = '';

if ($^O eq 'linux' || $^O eq 'freebsd' || $^O eq 'openbsd' || $^O eq 'netbsd' ||
    $^O eq 'solaris' || $^O eq 'sunos' || $^O eq 'dragonfly') {
    # Unix ELF systems: link against file.so with $ORIGIN-relative rpath
    $extra_libs = '-Wl,-rpath,\$ORIGIN/../file';
    $extra_ldfrom = '../../../blib/arch/auto/file/file.so';
}
elsif ($^O eq 'MSWin32' || $^O eq 'cygwin' || $^O eq 'msys') {
    # Windows/Cygwin/MSYS: link against file DLL
    my $dll_ext = $Config{dlext} || 'dll';
    $extra_ldfrom = "../../../blib/arch/auto/file/file.$dll_ext";
}
# macOS/darwin: no special linking needed (flat namespace makes symbols visible)

my %makefile_args = (
    NAME              => 'file_api_test',
    VERSION           => '0.01',
    PREREQ_PM         => {},
    ABSTRACT          => 'Test module for file hooks C API',
    AUTHOR            => 'LNATION <email@lnation.org>',
    LICENSE           => 'perl',
    LIBS              => [$extra_libs],
    DEFINE            => '',
    INC               => '-I. -I../../../xs/file',
    C                 => ['file_api_test.c'],
    OBJECT            => 'file_api_test$(OBJ_EXT)',
    OPTIMIZE          => '-O3',
    INST_LIB          => '../../../blib/lib',
    INST_ARCHLIB      => '../../../blib/arch',
);

# On Linux, link against file.so directly
if ($extra_ldfrom) {
    $makefile_args{OBJECT} = "file_api_test\$(OBJ_EXT) $extra_ldfrom";
}

WriteMakefile(%makefile_args);
