use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Uniform::HTMX',
    AUTHOR           => 'Joshua S. Day <HAX@cpan.org>',
    VERSION_FROM     => 'lib/Uniform/HTMX.pm',
    ABSTRACT_FROM    => 'lib/Uniform/HTMX.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000', # Ensures clean parent class feature support

    # Dependencies required to run the module in production
    PREREQ_PM => {
	'Uniform'       => '1.00',
        'JSON::MaybeXS' => '1.004000',
    },

    # Dependencies required purely for executing unit tests
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
                url  => 'https://github.com/haxmeister/perl-Uniform-HTMX',
                web  => 'https://github.com/haxmeister/perl-Uniform-HTMX',
            },
            bugtracker => {
		web => 'https://github.com/haxmeister/perl-Uniform-HTMX/issues',
            },
        },
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Uniform-HTMX-*' },
);
