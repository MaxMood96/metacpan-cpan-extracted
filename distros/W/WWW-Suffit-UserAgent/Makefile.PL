#!/usr/bin/perl -w
use strict;
use ExtUtils::MakeMaker;

my $build_requires = {
        'ExtUtils::MakeMaker'   => 6.60,
        'Test::More'            => 0.94,
    };

my $prereq_pm = {
        'Mojolicious'           => 7.94,    # Ubuntu = libmojolicious-perl          RHEL = perl-Mojolicious
        'WWW::Suffit'           => 1.00,
    };

WriteMakefile(
    'NAME'              => 'WWW::Suffit::UserAgent',
    'MIN_PERL_VERSION'  => 5.020001,
    'VERSION_FROM'      => 'lib/WWW/Suffit/UserAgent.pm',
    'ABSTRACT_FROM'     => 'lib/WWW/Suffit/UserAgent.pm',
    'BUILD_REQUIRES'    => $build_requires,
    'PREREQ_PM'         => $prereq_pm,
    'AUTHOR'            => 'Serz Minus (Sergey Lepenkov) <abalama@cpan.org>',
    'LICENSE'           => 'perl',
    'META_MERGE'        => {
        'meta-spec' => {version => 2},
        prereqs     => {runtime => {requires => {perl => '5.020'}}},
        resources   => {
            homepage    => 'https://sourceforge.net/projects/www-suffit-useragent/',
            license     => 'https://dev.perl.org/licenses',
            repository      => {
                    type => 'git',
                    url  => 'https://abalama@git.code.sf.net/p/www-suffit-useragent/code',
                    web  => 'https://sourceforge.net/p/www-suffit-useragent/code/ci/master/tree/',
                  },
        },
    },
);

1;
