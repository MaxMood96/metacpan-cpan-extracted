use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Uniform::HTMX::PSGI',
    AUTHOR           => 'Joshua S. Day <HAX@cpan.org>',
    VERSION_FROM     => 'lib/Uniform/HTMX/PSGI.pm',
    ABSTRACT_FROM    => 'lib/Uniform/HTMX/PSGI.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000',

    # Downstream dependencies enforce your version 1.01 baseline core first
    PREREQ_PM => {
        'Uniform::HTMX' => '0.11',
    },

    TEST_REQUIRES => {
        'Test::More'      => '0.88',
        'Test::Exception' => '0',
        'Test::Deep'      => '0',
    },
    # Meta documentation structural links for repository discovery
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/haxmeister/perl-Uniform-HTMX-PSGI',
                web  => 'https://github.com/haxmeister/perl-Uniform-HTMX-PSGI',
            },
            bugtracker => {
		web => 'https://github.com/haxmeister/perl-Uniform-HTMX-PSGI/issues',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Uniform-HTMX-PSGI-*' },
);
