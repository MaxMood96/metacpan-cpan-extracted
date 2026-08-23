use strict;
use warnings;
use Config;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::Signal',
    VERSION_FROM     => '../lib/Linux/Event/Signal.pm',
    ABSTRACT         => 'Subclass-defined signalfd handling for Linux::Event',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'Signal.xs' => 'Signal.c' },
    OBJECT           => 'Signal$(OBJ_EXT)',
    CCFLAGS          => "$Config{ccflags} -pthread",
    LIBS             => ['-lpthread'],
    clean            => { FILES => 'Signal.c' },
);
