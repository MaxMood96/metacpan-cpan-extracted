use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'file',
    VERSION_FROM     => '../../lib/file.pm',
    MIN_PERL_VERSION => '5.014',
    OBJECT       => 'file$(OBJ_EXT)',
    C            => ['file.c'],
    XS           => {},
    INST_LIB     => '../../blib/lib',
    INST_ARCHLIB => '../../blib/arch',
);
