use strict;
use warnings;
use ExtUtils::MakeMaker;

my $VERSION = MM->parse_version('lib/Uniform/HTMX.pm');

WriteMakefile(
    NAME             => 'Uniform::HTMX',
    AUTHOR           => 'Joshua S. Day <HAX@cpan.org>',
    VERSION_FROM     => 'lib/Uniform/HTMX.pm',
    ABSTRACT_FROM    => 'lib/Uniform/HTMX.pm',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.010000', # Ensures clean parent class feature support

    # Dependencies required to run the module in production
    PREREQ_PM => {
        'Uniform::Utils' => '1.00',
        'JSON::MaybeXS'  => '1.004000',
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
        # ExtUtils::MakeMaker does not auto-populate 'provides' the way
        # Module::Build or Dist::Zilla::Plugin::MetaProvides do, so it's
        # declared explicitly here. $VERSION is parsed from the module
        # itself above, so this stays in sync across releases.
        provides => {
            'Uniform::HTMX' => {
                file    => 'lib/Uniform/HTMX.pm',
                version => $VERSION,
            },
        },
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
