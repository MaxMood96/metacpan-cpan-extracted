use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'CPAN::Changes::Parser::KeepAChangeLog',
    AUTHOR           => q{Dave Cross <dave@perlhacks.com>},
    VERSION_FROM     => 'lib/CPAN/Changes/Parser/KeepAChangeLog.pm',
    ABSTRACT_FROM    => 'lib/CPAN/Changes/Parser/KeepAChangeLog.pm',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::More' => '0',
    },
    PREREQ_PM => {
        'Moo'                     => '0',
        'CPAN::Changes::Parser'   => '0',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'CPAN-Changes-Parser-KeepAChangeLog-*' },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/davorg-cpan/cpan-changes-parser-keepachangelog.git',
                web  => 'https://github.com/davorg-cpan/cpan-changes-parser-keepachangelog',
            },
            bugtracker => {
                web => 'https://github.com/davorg-cpan/cpan-changes-parser-keepachangelog/issues',
            },
        },
    },
);
