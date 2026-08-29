use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Physics::CPD',
    DISTNAME      => 'Physics-CPD',
    VERSION_FROM  => 'lib/Physics/CPD/Stellarator.pm',
    ABSTRACT      => 'Generic computational plasma dynamics with stellarator fusion-reactor modelling',
    AUTHOR        => 'Physics-CPD project',
    LICENSE       => 'gpl_3',
    MIN_PERL_VERSION => '5.010',

    # Core physics only needs Moo; plotting needs PDL (declared as recommended).
    PREREQ_PM => {
        'Moo'         => 0,
        'Carp'        => 0,
        'Test::More'  => 0,
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        prereqs     => {
            runtime => {
                recommends => {
                    'PDL'                     => 0,
                    'PDL::Graphics::Gnuplot'  => 0,
                },
            },
        },
        resources => {
            homepage => 'https://www.ipp.mpg.de/w7x',
        },
    },

    dist  => {
        COMPRESS => '$(PERL) -MIO::Compress::Gzip=gzip,:constants -e "my $$f = shift; gzip $$f => qq($$f.gz), -Level => Z_BEST_COMPRESSION or die qq(gzip failed: $$IO::Compress::Gzip::GzipError\n); unlink $$f or die qq(unlink $$f failed: $$!\n)"',
        SUFFIX   => 'gz',
    },
    clean => { FILES    => 'Physics-CPD-* Physics-Stellarator-* *.png' },
);
