use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'heap',
    VERSION_FROM     => '../../lib/heap.pm',
    MIN_PERL_VERSION => '5.010',
    OBJECT       => 'heap$(OBJ_EXT)',
    C            => ['heap.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
);
