use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::Stream::_Connection',
    VERSION_FROM     => '../lib/Linux/Event/Stream.pm',
    ABSTRACT         => 'Internal nonblocking Stream connection support',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'Connection.xs' => 'Connection.c' },
    OBJECT           => 'Connection$(OBJ_EXT)',
    clean            => { FILES => 'Connection.c' },
);
