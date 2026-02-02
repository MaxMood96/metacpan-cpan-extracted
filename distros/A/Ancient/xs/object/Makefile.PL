use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

# Platform-specific linker flags for symbol export
# Other XS modules can use object_types.h to register C-level type checks
my %platform_args;
if ($^O eq 'linux' || $^O eq 'freebsd' || $^O eq 'openbsd' || $^O eq 'netbsd' ||
    $^O eq 'solaris' || $^O eq 'sunos' || $^O eq 'dragonfly') {
    # Unix ELF systems: export symbols and set SONAME
    $platform_args{LDDLFLAGS} = $Config{lddlflags} . ' -Wl,--export-dynamic -Wl,-soname,object.so';
}
elsif ($^O eq 'MSWin32' || $^O eq 'cygwin' || $^O eq 'msys') {
    # Windows/Cygwin/MSYS: export all symbols for DLL linking
    $platform_args{LDDLFLAGS} = ($Config{lddlflags} || '') . ' -Wl,--export-all-symbols';
}
# macOS/darwin: no special flags needed (flat namespace exports symbols automatically)

WriteMakefile(
    NAME             => 'object',
    VERSION_FROM     => '../../lib/object.pm',
    MIN_PERL_VERSION => '5.010',
    OBJECT       => 'object$(OBJ_EXT)',
    C            => ['object.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
    %platform_args,
);
