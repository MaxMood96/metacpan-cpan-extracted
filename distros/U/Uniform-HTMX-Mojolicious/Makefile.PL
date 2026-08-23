use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Uniform::HTMX::Mojolicious',
    AUTHOR           => 'Joshua S. Day <HAX@cpan.org>',
    VERSION_FROM     => 'lib/Uniform/HTMX/Mojolicious.pm',
    ABSTRACT_FROM    => 'lib/Uniform/HTMX/Mojolicious.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000',

    PREREQ_PM => {
        'Uniform::HTMX' => '0.14', # Requires your custom polished version!
        'Mojolicious'   => '9.00', # Baseline modern Mojolicious support
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
                url  => 'https://github.com/haxmeister/perl-Uniform-HTMX-Mojolicious',
                web  => 'https://github.com/haxmeister/perl-Uniform-HTMX-Mojolicious',
            },
            bugtracker => {
		web => 'https://github.com/haxmeister/perl-Uniform-HTMX-Mojolicious/issues',
            },
        },
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Uniform-HTMX-Mojolicious-*' },
);
