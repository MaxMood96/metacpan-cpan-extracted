# vi:set ft=perl:
use strict;
use warnings;

return {
    NAME   => 'Pod::DokuWiki',
    AUTHOR => q{Lukas Mai <l.mai@web.de>},

    MIN_PERL_VERSION => '5.36.0',
    CONFIGURE_REQUIRES => {},
    BUILD_REQUIRES => {},
    TEST_REQUIRES => {
        'Test2::V0' => 0,
    },
    PREREQ_PM => {
        'Carp'     => 0,
        'Pod::Simple' => 3.46,
        'URI::Escape' => 0,
    },
    DEVELOP_REQUIRES => {
        'Pod::Markdown::Githubert' => 0,
        'Test::Pod'                => 1.22,
    },

    depend => {
        Makefile => '$(VERSION_FROM)',
    },

    REPOSITORY => [ codeberg => 'mauke' ],
    LICENSE => 'gpl_3', # or later
};
