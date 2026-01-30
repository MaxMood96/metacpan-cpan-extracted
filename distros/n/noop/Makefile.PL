use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'noop',
    VERSION_FROM => 'lib/noop.pm',
    OBJECT       => 'noop$(OBJ_EXT)',
    C            => ['noop.c'],
    XS           => {},
);
