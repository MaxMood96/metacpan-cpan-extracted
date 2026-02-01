use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'doubly',
    VERSION_FROM     => '../../lib/doubly.pm',
    MIN_PERL_VERSION => '5.014',
    OBJECT       => 'doubly$(OBJ_EXT)',
    C            => ['doubly.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
);
