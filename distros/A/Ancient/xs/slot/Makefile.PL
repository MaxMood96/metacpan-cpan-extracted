use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'slot',
    VERSION_FROM     => '../../lib/slot.pm',
    MIN_PERL_VERSION => '5.010',
    OBJECT       => 'slot$(OBJ_EXT)',
    C            => ['slot.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
);
