use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'lru',
    VERSION_FROM     => '../../lib/lru.pm',
    MIN_PERL_VERSION => '5.010',
    OBJECT       => 'lru$(OBJ_EXT)',
    C            => ['lru.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
);
