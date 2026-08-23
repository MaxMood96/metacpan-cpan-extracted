use strict;
use warnings;
use Config;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Linux::Event::Stream::_Resolver',
    VERSION_FROM     => '../lib/Linux/Event/Stream.pm',
    ABSTRACT         => 'Private native asynchronous resolver for Linux::Event::Stream',
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
