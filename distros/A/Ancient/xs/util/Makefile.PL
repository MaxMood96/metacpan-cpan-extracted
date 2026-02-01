use strict;
use warnings;
use ExtUtils::MakeMaker;
use Config;

# Platform-specific linker flags for symbol export
# Other XS modules can use util_callbacks.h to register C-level callbacks
my %platform_args;
if ($^O eq 'linux' || $^O eq 'freebsd' || $^O eq 'openbsd' || $^O eq 'netbsd' ||
    $^O eq 'solaris' || $^O eq 'sunos' || $^O eq 'dragonfly') {
    # Unix ELF systems: export symbols and set SONAME
    $platform_args{LDDLFLAGS} = $Config{lddlflags} . ' -Wl,--export-dynamic -Wl,-soname,util.so';
}
elsif ($^O eq 'MSWin32' || $^O eq 'cygwin' || $^O eq 'msys') {
    # Windows/Cygwin/MSYS: export all symbols for DLL linking
    $platform_args{LDDLFLAGS} = ($Config{lddlflags} || '') . ' -Wl,--export-all-symbols';
}
# macOS/darwin: no special flags needed (flat namespace exports symbols automatically)

WriteMakefile(
    NAME             => 'util',
    VERSION_FROM     => '../../lib/util.pm',
    MIN_PERL_VERSION => '5.014',
    OBJECT       => 'util$(OBJ_EXT)',
    C            => ['util.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
    %platform_args,
);
