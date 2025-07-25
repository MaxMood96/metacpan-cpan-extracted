use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    (MM->can('signature_target') ? (SIGN => 1) : ()),
    NAME             => 'Mail::Run::Crypt',
    AUTHOR           => q{Tom Ryder <tom@sanctum.geek.nz>},
    VERSION_FROM     => 'lib/Mail/Run/Crypt.pm',
    ABSTRACT_FROM    => 'lib/Mail/Run/Crypt.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => '5.008001',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
        'Test::More' => '0',
    },
    PREREQ_PM => {
        'Carp'                      => 0,
        'English'                   => 0,
        'Getopt::Long::Descriptive' => 0,
        'IPC::Run3'                 => 0,
        'Mail::GnuPG'               => 0,
        'MIME::Entity'              => 0,
    },
    EXE_FILES => ['bin/runcrypt'],
    META_MERGE => {
        'meta-spec' => { version => 2 },
        provides => {
            'Mail::Run::Crypt' => {
                version => '0.12',
                file => 'lib/Mail/Run/Crypt.pm',
            },
        },
        resources => {
            homepage => 'https://dev.sanctum.geek.nz/cgit/Mail-Run-Crypt.git/',
            repository => {
                type => 'git',
                url => 'https://sanctum.geek.nz/code/Mail-Run-Crypt.git/',
                web => 'https://dev.sanctum.geek.nz/cgit/Mail-Run-Crypt.git/',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Mail-Run-Crypt-*' },
);
