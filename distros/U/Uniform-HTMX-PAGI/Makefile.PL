use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Uniform::HTMX::PAGI',
    AUTHOR           => 'Joshua S. Day <HAX@cpan.org>',
    VERSION_FROM     => 'lib/Uniform/HTMX/PAGI.pm',
    ABSTRACT_FROM    => 'lib/Uniform/HTMX/PAGI.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000',

    # Downstream dependencies enforce your version 1.01 baseline core first
    PREREQ_PM => {
        'Uniform::HTMX' => '0.15',
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
                url  => 'https://github.com/haxmeister/perl-Uniform-HTMX-PAGI',
                web  => 'https://github.com/haxmeister/perl-Uniform-HTMX-PAGI',
            },
            bugtracker => {
		web => 'https://github.com/haxmeister/perl-Uniform-HTMX-PAGI/issues',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Uniform-HTMX-PAGI-*' },
);
