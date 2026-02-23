use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'DeyeCloud::Client',
    AUTHOR       => 'Volodymyr Pidgornyi <vp@dtel-ix.net>',
    VERSION      => '0.0.2',
    ABSTRACT     => 'perl client interface to Deye Cloud API',
    LICENSE      => 'apache_2_0',
    META_MERGE => {
        'meta-spec' => { version => 2 },
        'resources' => {
            'repository' => {
                'type' => 'git',
                'url'  => 'https://github.com/kornix/perl-DeyeCloud-Client.git',
                'web'  => 'https://github.com/kornix/perl-DeyeCloud-Client',
            }
        }
    },
    PL_FILES     => {},
    PREREQ_PM    => {
        'Test::More' => 0,
    },
    test         => { TESTS => 't/*.t' },
    dist         => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean        => { FILES => 'DeyeCloud-Client-*' },
);

