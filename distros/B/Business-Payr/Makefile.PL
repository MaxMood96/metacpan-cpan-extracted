#!perl

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Business::Payr',
    VERSION_FROM     => 'lib/Business/Payr.pm',
    AUTHOR           => 'Lee Johnson <leejo@cpan.org>',
    LICENSE          => 'perl',
    MIN_PERL_VERSION => '5.20.0',
    PREREQ_PM => {
        'Moose'                 => '2.1400',
        'Mojolicious'           => '8.52',
        'Try::Tiny::SmartCatch' => '0.5',
        'IO::Socket::SSL'       => '2.009',
        'namespace::autoclean'  => '0.27',
        'Digest::SHA'                   => '5.47',
        'String::Compare::ConstantTime' => '0.321',
        'Carp'                  => 0,
        'JSON'                  => 0,
    },
    BUILD_REQUIRES => {
        'Test::Most'       => '0.33',
        'Test::MockObject' => '1.20140408',
        'Test::Warnings'   => '0.014',
    },
    META_MERGE => {
        resources => {
            license    => 'http://dev.perl.org/licenses/',
            homepage   => 'https://metacpan.org/module/Business::Payr',
            bugtracker => 'https://github.com/payprop/business-payr/issues',
            repository => 'https://github.com/payprop/business-payr'
        },
    },
    test => {
        RECURSIVE_TEST_FILES => 1,
    },
);

# vim: ts=4:sw=4:et
