use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::Wakeup',
    VERSION_FROM     => '../lib/Linux/Event/Wakeup.pm',
    ABSTRACT         => 'eventfd wakeups for Linux::Event',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'Wakeup.xs' => 'Wakeup.c' },
    OBJECT           => 'Wakeup$(OBJ_EXT)',
    clean            => { FILES => 'Wakeup.c' },
);
