use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Net::IPData',
    VERSION_FROM     => 'lib/Net/IPData.pm',
    ABSTRACT_FROM    => 'lib/Net/IPData.pm',
    AUTHOR           => 'Net::IPData contributors',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010001',
    PREREQ_PM        => {
        'HTTP::Tiny'   => '0.034',    # core since 5.14, need SSL support
        'JSON::PP'     => '2.27',     # core since 5.14
        'Carp'         => '0',
        'Scalar::Util' => '0',
    },
    TEST_REQUIRES => {
        'Test::More' => '0.96',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            homepage   => 'https://ipdata.co/',
            repository => {
                type => 'git',
                url  => 'https://github.com/ipdata/perl.git',
                web  => 'https://github.com/ipdata/perl',
            },
            bugtracker => {
                web => 'https://github.com/ipdata/perl/issues',
            },
        },
        prereqs => {
            runtime => {
                recommends => {
                    'IO::Socket::SSL' => '1.56',
                    'Net::SSLeay'     => '1.49',
                },
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES    => 'Net-IPData-*' },
);
