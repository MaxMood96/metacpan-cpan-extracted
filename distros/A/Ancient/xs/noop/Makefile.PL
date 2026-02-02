use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'noop',
    VERSION_FROM     => '../../lib/noop.pm',
    MIN_PERL_VERSION => '5.010',
    OBJECT       => 'noop$(OBJ_EXT)',
    C            => ['noop.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
);
