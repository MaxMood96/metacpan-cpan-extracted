use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Uniform::HTMX::Dancer2',
    AUTHOR           => 'Joshua S. Day <HAX@cpan.org>',
    VERSION_FROM     => 'lib/Uniform/HTMX/Dancer2.pm',
    ABSTRACT_FROM    => 'lib/Uniform/HTMX/Dancer2.pm',
    LICENSE          => 'mit',
    MIN_PERL_VERSION => '5.020',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::More'            => '0.98',
        'Plack::Test'           => '0',
        'HTTP::Request::Common' => '0',
    },
    PREREQ_PM => {
        'Dancer2::Plugin' => '0',
        'Uniform::HTMX'   => '0.016',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/haxmeister/perl-Uniform-HTMX-Dancer2.git',
                web  => 'https://github.com/haxmeister/perl-Uniform-HTMX-Dancer2',
            },
            bugtracker => {
                web => 'https://github.com/haxmeister/perl-Uniform-HTMX-Dancer2/issues',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Uniform-HTMX-Dancer2-*' },
);
