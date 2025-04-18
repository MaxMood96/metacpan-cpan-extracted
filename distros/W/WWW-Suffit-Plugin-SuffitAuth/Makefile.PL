#!/usr/bin/perl -w
use strict;
use ExtUtils::MakeMaker;

my $build_requires = {
        'ExtUtils::MakeMaker'   => 6.60,
        'Test::More'            => 0.94,
    };

my $prereq_pm = {
        'Mojolicious'           => 7.94,    # Ubuntu = libmojolicious-perl          RHEL = perl-Mojolicious
        'WWW::Suffit::Client'   => 1.02,    # Ubuntu = libwww-suffit-client-perl    RHEL = perl-WWW-Suffit-Client
        'WWW::Suffit'           => 1.08,    # Ubuntu = libwww-suffit-perl           RHEL = perl-WWW-Suffit
    };

WriteMakefile(
    'NAME'              => 'WWW::Suffit::Plugin::SuffitAuth',
    'MIN_PERL_VERSION'  => 5.020001,
    'VERSION_FROM'      => 'lib/WWW/Suffit/Plugin/SuffitAuth.pm',
    'ABSTRACT_FROM'     => 'lib/WWW/Suffit/Plugin/SuffitAuth.pm',
    'BUILD_REQUIRES'    => $build_requires,
    'PREREQ_PM'         => $prereq_pm,
    'AUTHOR'            => 'Serz Minus (Sergey Lepenkov) <abalama@cpan.org>',
    'LICENSE'           => 'perl',
    'META_MERGE'        => {
        'meta-spec' => {version => 2},
        prereqs     => {runtime => {requires => {perl => '5.020'}}},
        resources   => {
            homepage    => 'https://sourceforge.net/projects/www-suffit-plugin-suffitauth/',
            license     => 'https://dev.perl.org/licenses',
            repository      => {
                    type => 'git',
                    url  => 'https://abalama@git.code.sf.net/p/www-suffit-plugin-suffitauth/code',
                    web  => 'https://sourceforge.net/p/www-suffit-plugin-suffitauth/code/ci/master/tree/',
                  },
        },
    },
);

1;
