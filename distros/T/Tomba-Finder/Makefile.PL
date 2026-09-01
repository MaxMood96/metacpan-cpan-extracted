use 5.026001;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Tomba::Finder',
    VERSION_FROM      => 'lib/Tomba/Client.pm',
    ABSTRACT_FROM     => 'lib/Tomba/Finder.pm',
    AUTHOR            => 'Mohamed Ben rebia <b.mohamed@tomba.io>',
    LICENSE           => 'apache_2_0',
    MIN_PERL_VERSION  => '5.026001',
    PREREQ_PM         => {
        'LWP::UserAgent' => '0',
        'JSON'           => '0',
        'URI'            => '0',
        'URI::Escape'    => '0',
        'HTTP::Headers'  => '0',
        'HTTP::Request'  => '0',
        'parent'         => '0',
    },
    TEST_REQUIRES     => {
        'Test::More'     => '0.98',
    },
    META_MERGE        => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/tomba-io/perl.git',
                web  => 'https://github.com/tomba-io/perl',
            },
            bugtracker => {
                web => 'https://github.com/tomba-io/perl/issues',
            },
            homepage => 'https://tomba.io',
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Tomba-Finder-*' },
);
