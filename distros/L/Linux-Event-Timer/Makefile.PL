use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Linux::Event::Timer',
    AUTHOR       => 'Joshua Day',
    VERSION_FROM => 'lib/Linux/Event/Timer.pm',
    ABSTRACT     => 'Thin wrapper around Linux::FD::Timer (timerfd)',
    LICENSE      => 'perl',
    MIN_PERL_VERSION => '5.036',
    PREREQ_PM    => {
        'Linux::FD::Timer' => '0.015',
        'Fcntl'            => 0,
        'Carp'             => 0,
        'Scalar::Util'     => 0,
    },
    TEST_REQUIRES => {
        'Test::More'       => 0,
        'Time::HiRes'      => 0,
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/haxmeister/perl-linux-event-timer.git',
                web  => 'https://github.com/haxmeister/perl-linux-event-timer',
            },
            bugtracker => {
                web => 'https://github.com/haxmeister/perl-linux-event-timer/issues',
            },
        },
    },
);
