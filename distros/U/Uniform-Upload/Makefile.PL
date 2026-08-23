use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Uniform::Upload',
    AUTHOR           => 'Joshua S. Day <HAX@cpan.org>',
    VERSION_FROM     => 'lib/Uniform/Upload.pm',
    ABSTRACT_FROM    => 'lib/Uniform/Upload.pm',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.010000',

    PREREQ_PM => {
        'Uniform::Exceptions' => '1.00',
        'Uniform::Utils'      => '1.01', # for parse_size_limit()
    },

    TEST_REQUIRES => {
        'Test::More'      => '0.88',
        'Test::Exception' => '0',
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/haxmeister/perl-Uniform-Upload',
                web  => 'https://github.com/haxmeister/perl-Uniform-Upload',
            },
            bugtracker => {
                web  => 'https://github.com/haxmeister/perl-Uniform-Upload/issues',
            },
        },
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Uniform-Upload-*' },
);
