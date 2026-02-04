use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Stefo',
    VERSION_FROM     => 'lib/Stefo.pm',
    ABSTRACT_FROM    => 'lib/Stefo.pm',
    AUTHOR           => 'LNATION <email@lnation.org>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010',
    
    XS               => { 'Stefo.xs' => 'Stefo.c' },
    OBJECT           => 'Stefo$(OBJ_EXT)',
    
    PREREQ_PM => {
        'strict'   => 0,
        'warnings' => 0,
        'XSLoader' => 0,
    },
    
    TEST_REQUIRES => {
        'Test::More' => '0.88',
    },
    
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'git://github.com/LNATION/Stefo.git',
                web  => 'https://github.com/LNATION/Stefo',
            },
            bugtracker => {
                web => 'https://github.com/LNATION/Stefo/issues',
            },
        },
        keywords => [
            'optree', 'compile', 'optimize', 'bytecode', 'xs',
            'performance', 'type', 'constraint', 'predicate'
        ],
    },
    
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.64',
    },
    
    clean => {
        FILES => 'Stefo-* *.o *.bs Stefo.c',
    },
);
