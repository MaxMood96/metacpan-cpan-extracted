use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'App::Envdoctor',
    VERSION_FROM  => 'lib/App/Envdoctor.pm',
    ABSTRACT      => 'Local-first consistency checker for environment variables (native Perl port)',
    AUTHOR        => 'Arun Natesan',
    LICENSE       => 'mit',
    MIN_PERL_VERSION => '5.010',
    EXE_FILES     => ['bin/envdoctor'],
    PREREQ_PM     => {},
    TEST_REQUIRES => { 'Test::More' => 0 },
    META_MERGE    => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/arun-skg/envdoctor.git',
                web  => 'https://github.com/arun-skg/envdoctor',
            },
        },
    },
);
