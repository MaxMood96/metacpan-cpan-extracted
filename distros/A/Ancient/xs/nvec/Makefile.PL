use ExtUtils::MakeMaker;
use Config;

# Platform-specific linker flags for symbol export
# nvec_api_test (and other XS modules) link against nvec to use the C API
my %platform_args;
if ($^O eq 'linux' || $^O eq 'freebsd' || $^O eq 'openbsd' || $^O eq 'netbsd' ||
    $^O eq 'solaris' || $^O eq 'sunos' || $^O eq 'dragonfly') {
    # Unix ELF systems: export symbols and set SONAME
    $platform_args{LDDLFLAGS} = $Config{lddlflags} . ' -Wl,--export-dynamic -Wl,-soname,nvec.so';
}
elsif ($^O eq 'MSWin32' || $^O eq 'cygwin' || $^O eq 'msys') {
    # Windows/Cygwin/MSYS: export all symbols for DLL linking
    $platform_args{LDDLFLAGS} = ($Config{lddlflags} || '') . ' -Wl,--export-all-symbols';
}
# macOS/darwin: no special flags needed (flat namespace exports symbols automatically)

WriteMakefile(
    NAME              => 'nvec',
    VERSION_FROM      => '../../lib/nvec.pm',
    MIN_PERL_VERSION  => '5.010',
    PREREQ_PM         => {},
    ABSTRACT          => 'SIMD-accelerated numeric vectors',
    AUTHOR            => 'LNATION <email@lnation.org>',
    LICENSE           => 'perl',
    LIBS              => [''],
    DEFINE            => '',
    INC               => '-I.',
    C                 => ['nvec.c'],
    OBJECT            => 'nvec$(OBJ_EXT)',
    OPTIMIZE          => '-O3',
    INST_LIB          => '../../blib/lib',
    INST_ARCHLIB      => '../../blib/arch',
    %platform_args,
);
