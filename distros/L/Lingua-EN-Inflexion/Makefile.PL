use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Lingua::EN::Inflexion',
    AUTHOR              => 'Damian Conway <DCONWAY@CPAN.org>',
    VERSION_FROM        => 'lib/Lingua/EN/Inflexion.pm',
    ABSTRACT_FROM       => 'lib/Lingua/EN/Inflexion.pm',
    PL_FILES            => {},
    LICENSE             => 'artistic2',
    MIN_PERL_VERSION    => 5.010,
    PREREQ_PM => {
        'Test::More'             => 0,
        'Lingua::EN::Nums2Words' => 1.16,
        'Lingua::EN::Words2Nums' => 0,
        'match::smart'           => 0.010,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Lingua-EN-Inflexion-*' },
);
