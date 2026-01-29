use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Jinja2::TT2',
    AUTHOR           => 'Luciano Federico Pereira',
    VERSION_FROM     => 'lib/Jinja2/TT2.pm',
    ABSTRACT         => 'Transpile Jinja2 templates to Template Toolkit 2',
    LICENSE          => 'lgpl_2_1',
    MIN_PERL_VERSION => '5.020',

    EXE_FILES => ['bin/jinja2tt2'],

    PREREQ_PM => {
        # Core modules only - no external dependencies
    },

    TEST_REQUIRES => {
        'Test::More' => '0.98',
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/lucianofedericopereira/jinja2tt2.git',
                web  => 'https://github.com/lucianofedericopereira/jinja2tt2',
            },
            bugtracker => {
                web => 'https://github.com/lucianofedericopereira/jinja2tt2/issues',
            },
        },
        keywords => [qw(jinja2 template-toolkit transpiler tt2 template)],
    },

    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Jinja2-TT2-*' },
);
