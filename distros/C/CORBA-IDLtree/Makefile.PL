use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'CORBA::IDLtree',
    AUTHOR           => q{Oliver M. Kellogg <olivermkellogg@gail.com>},
    VERSION_FROM     => 'lib/CORBA/IDLtree.pm',
    ABSTRACT_FROM    => 'lib/CORBA/IDLtree.pm',
    LICENSE          => 'artistic_2',
    PL_FILES         => {},
    MIN_PERL_VERSION => '5.008_003',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    BUILD_REQUIRES => {
        'Test::More' => '0',
    },
    PREREQ_PM => {
        #'ABC'              => '1.6',
        #'Foo::Bar::Module' => '5.0401',
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'CORBA-IDLtree-*' },
);
