use strict;
use warnings;
use Config;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::_Resolver',
    VERSION_FROM     => '../lib/Linux/Event/_Resolver.pm',
    ABSTRACT         => 'Private asynchronous resolver for Linux::Event sockets',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    PM               => {},
    XS               => { 'Resolver.xs' => 'Resolver.c' },
    OBJECT           => 'Resolver$(OBJ_EXT)',
    CCFLAGS          => "$Config{ccflags} -pthread",
    LIBS             => ['-lpthread'],
    clean            => { FILES => 'Resolver.c' },
);
