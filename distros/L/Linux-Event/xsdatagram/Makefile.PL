use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::_Socket::Dgram',
    VERSION_FROM     => '../lib/Linux/Event.pm',
    ABSTRACT         => 'Packet-preserving datagram engine for Linux::Event',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'Datagram.xs' => 'Datagram.c' },
    OBJECT           => 'Datagram$(OBJ_EXT)',
    clean            => { FILES => 'Datagram.c' },
);
