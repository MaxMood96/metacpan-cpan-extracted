use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'const',
    VERSION_FROM     => '../../lib/const.pm',
    MIN_PERL_VERSION => '5.014',
    OBJECT       => 'const$(OBJ_EXT)',
    C            => ['const.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
);
