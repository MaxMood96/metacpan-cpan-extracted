use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::Kernel::Event',
    VERSION_FROM     => '../lib/Linux/Event/Kernel/Event.pm',
    ABSTRACT         => 'eventfd wakeups for Linux::Event',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'Event.xs' => 'Event.c' },
    OBJECT           => 'Event$(OBJ_EXT)',
    clean            => { FILES => 'Event.c' },
);
