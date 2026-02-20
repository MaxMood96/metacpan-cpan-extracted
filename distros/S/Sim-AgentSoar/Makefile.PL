use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Sim::AgentSoar',
    VERSION_FROM     => 'lib/Sim/AgentSoar.pm',
    ABSTRACT_FROM    => 'lib/Sim/AgentSoar.pm',
    AUTHOR           => 'Gian Luca Brunetti <gianluca.brunetti\@gmail.com>',
    LICENSE          => 'gpl_3',
    MIN_PERL_VERSION => '5.014',

    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },

    PREREQ_PM => {
        'strict'    => 0,
        'warnings'  => 0,
        'JSON::PP'  => 0,
        'File::Temp'=> 0,
    },

    TEST_REQUIRES => {
        'Test::More' => 0,
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            bugtracker => {
                web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Sim-AgentSoar',
            },
        },
    },
);
