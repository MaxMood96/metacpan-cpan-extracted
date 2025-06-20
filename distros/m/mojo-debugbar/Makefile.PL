#!/usr/bin/env perl
use 5.006;

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Mojo::Debugbar',
    AUTHOR           => q{Adrian Crisan <adrian.crisan88@gmail.com>},
    VERSION_FROM     => 'lib/Mojo/Debugbar.pm',
    ABSTRACT_FROM    => 'lib/Mojo/Debugbar.pm',
    LICENSE          => 'MIT',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Mojolicious' => 0,
        'Test::More' => 0,
        'Time::HiRes' => 0,
        'Devel::StackTrace' => 0,
    },
    META_MERGE   => {
        no_index       => {directory => ['t']},
        resources => {
            bugtracker => {
                web => 'https://gitlab.com/AuroraSoftware/mojo-debugbar/issues'
            },
            license    => ['https://opensource.org/licenses/MIT'],
            repository => {
                type => 'git',
                url  => 'https://gitlab.com/AuroraSoftware/mojo-debugbar.git',
                web  => 'https://gitlab.com/AuroraSoftware/mojo-debugbar',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Mojo-Debugbar-*' },
    test      => {TESTS => 't/*.t'},
);
