use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::Listener',
    VERSION_FROM     => '../lib/Linux/Event/Listener.pm',
    ABSTRACT         => 'Native accepting engine for Linux::Event::Listener',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'Listener.xs' => 'Listener.c' },
    OBJECT           => 'Listener$(OBJ_EXT)',
    clean            => { FILES => 'Listener.c' },
);
