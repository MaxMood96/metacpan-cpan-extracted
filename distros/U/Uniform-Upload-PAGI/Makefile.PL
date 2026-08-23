use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Uniform::Upload::PAGI',
    AUTHOR           => 'Joshua S. Day <HAX@cpan.org>',
    VERSION_FROM     => 'lib/Uniform/Upload/PAGI.pm',
    ABSTRACT_FROM    => 'lib/Uniform/Upload/PAGI.pm',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.010000',

    PREREQ_PM => {
        'Uniform'         => '1.00', # Enforces your base exceptions/utils ecosystem mandate
        'Uniform::Upload' => '0.01', # The abstract file specification layer
    },

    TEST_REQUIRES => {
        'Test::More'      => '0.88',
        'Test::Exception' => '0',
        'Test::Deep'      => '0',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/haxmeister/perl-Uniform-Upload-PAGI',
                web  => 'https://github.com/haxmeister/perl-Uniform-Upload-PAGI',
            },
            bugtracker => {
                web  => 'https://github.com/haxmeister/perl-Uniform-Upload-PAGI/issues',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Uniform-Upload-PAGI-*' },
);
