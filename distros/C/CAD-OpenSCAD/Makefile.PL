use strict;
use warnings;
use 5.6.1;  
use ExtUtils::MakeMaker;
WriteMakefile
(
    NAME         => 'CAD::OpenSCAD',
    VERSION_FROM => 'lib/CAD/OpenSCAD.pm',
    AUTHOR       => 'Saif Ahmed <saiftynet { at } gmail.com>',
    ABSTRACT     => 'Module to generate 3D Objects as .scad files from Perl',
    LICENSE      =>  'Perl',
    MIN_PERL_VERSION  => 5.18,
    PREREQ_PM    => {
        'Object::Pad'            => '0.801',
    },
    BUILD_REQUIRES => {
		
    },
    TEST_REQUIRES => {
		'Test::Simple' => '0',
		},
);
