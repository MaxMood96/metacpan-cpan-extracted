use strict;
use warnings;
use ExtUtils::MakeMaker;

die "Linux::Event supports Linux only\n" if $^O ne 'linux';

WriteMakefile(
    NAME             => 'Linux::Event',
    VERSION_FROM     => 'lib/Linux/Event.pm',
    ABSTRACT         => 'Linux-native reactor, streams, datagrams, and processes',
    AUTHOR           => 'Joshua S. Day <hax@cpan.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.036000',
    DIR              => [qw(xsloop xsstream xstls xsconnection xsresolver xssignal xslistener xswakeup xsdatagram xsprocess)],
    CONFIGURE_REQUIRES => {
        'ExtUtils::CBuilder'  => 0,
        'ExtUtils::MakeMaker' => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Socket' => '2.033',
    },
    META_MERGE       => {
        no_index => {
            package => [qw(
                Linux::Event::_Registration
                Linux::Event::_Resolver
                Linux::Event::_Resolver::_Native
                Linux::Event::_SocketConfig
                Linux::Event::Datagram::_ReadyTimer
                Linux::Event::Signal::_Descriptor
                Linux::Event::Signal::_Engine
                Linux::Event::Signal::_Service
                Linux::Event::Stream::_Connection
                Linux::Event::Stream::_Deadline
                Linux::Event::Stream::XSDescriptor
                Linux::Event::Stream::XSState
                Linux::Event::Timer::_Descriptor
                Linux::Event::Wakeup::_OwnerState
            )],
        },
        resources => {
            homepage   => 'https://github.com/haxmeister/perl-linux-event',
            bugtracker => {
                web => 'https://github.com/haxmeister/perl-linux-event/issues',
            },
            repository => {
                type => 'git',
                url  => 'https://github.com/haxmeister/perl-linux-event.git',
                web  => 'https://github.com/haxmeister/perl-linux-event',
            },
        },
    },
);
