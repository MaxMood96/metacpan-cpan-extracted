use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Bored',
    VERSION_FROM     => 'lib/Bored.pm',
    ABSTRACT         => 'Enterprise-grade procrastination and entropy maximization',
    AUTHOR           => 'Pinocchio <pinocchio@example.com>',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010',
    
    XS               => { 'Bored.xs' => 'Bored.c' },
    OBJECT           => 'Bored$(OBJ_EXT)',
    
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
    },
    
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '6.64',
    },
    
    clean => {
        FILES => 'bored-* *.o *.bs bored.c',
    },
);
