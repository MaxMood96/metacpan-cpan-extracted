#!/usr/bin/env perl

use v5.14;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME               => 'Test::PostgreSQL::v2',
    AUTHOR             => q{Mohammad Sajid Anwar <mohammad.anwar@yahoo.com>},
    VERSION_FROM       => 'lib/Test/PostgreSQL/v2.pm',
    ABSTRACT_FROM      => 'lib/Test/PostgreSQL/v2.pm',
    LICENSE            => 'artistic_2',
    MIN_PERL_VERSION   => 5.014,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    PREREQ_PM => {
        'File::Temp'       => 0,
        'File::Spec'       => 0,
        'File::Which'      => 0,
        'Time::HiRes'      => 0,
        'POSIX'            => 0,
        'IO::Socket::INET' => 0,
    },
    TEST_REQUIRES => {
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Test-PostgreSQL-v2-*' },
    (eval { ExtUtils::MakeMaker->VERSION(6.46) } ? (META_MERGE => {
        'meta-spec' => { version => 2 },
        provides    => {
            'Test::PostgreSQL::v2' => {
                file    => 'lib/Test/PostgreSQL/v2.pm',
                version => MM->parse_version('lib/Test/PostgreSQL/v2.pm')
            },
            'Test::DBIx::Class::SchemaManager::Trait::Testpostgresqlv2' => {
                file    => 'lib/Test/DBIx/Class/SchemaManager/Trait/Testpostgresqlv2.pm',
                version => MM->parse_version('lib/Test/DBIx/Class/SchemaManager/Trait/Testpostgresqlv2.pm')
            },
        },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/manwar/Test-PostgreSQL-v2.git',
                web  => 'https://github.com/manwar/Test-PostgreSQL-v2',
            },
            bugtracker => {
                web  => 'https://github.com/manwar/Test-PostgreSQL-v2/issues'
            },
        }})
     : ()
    ),
);
