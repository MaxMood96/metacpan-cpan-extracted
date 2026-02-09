use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Linux::Event::Clock',
    AUTHOR            => 'Joshua Day',
    VERSION_FROM      => 'lib/Linux/Event/Clock.pm',
    ABSTRACT_FROM     => 'lib/Linux/Event/Clock.pm',
    LICENSE           => 'perl',
    MIN_PERL_VERSION  => '5.14.0',
    PREREQ_PM         => {
        'Carp'         => 0,
        'Time::HiRes'  => 0,
    },
    TEST_REQUIRES     => {
        'Test::More'   => 0,
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/haxmeister/perl-linux-event-clock.git',
                web  => 'https://github.com/haxmeister/perl-linux-event-clock',
            },
            bugtracker => {
                web => 'https://github.com/haxmeister/perl-linux-event-clock/issues',
            },
        },
    },
);
