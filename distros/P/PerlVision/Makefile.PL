use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'PerlVision',
    AUTHOR              => q{Ashish Gulhati <perlvision at hash.neo.email>},
    VERSION_FROM        => 'lib/PerlVision.pm',
    ABSTRACT_FROM       => 'lib/PerlVision.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'unrestricted')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Curses' => 1.45,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'PerlVision-*' },
);
