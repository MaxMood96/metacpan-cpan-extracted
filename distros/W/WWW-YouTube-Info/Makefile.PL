use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'WWW::YouTube::Info',
    VERSION_FROM      => 'lib/WWW/YouTube/Info.pm', # finds $VERSION
    PREREQ_PM         => {
        LWP::Simple => 6.31,
        LWP::Protocol::https => 6.07,
    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/WWW/YouTube/Info.pm', # retrieve abstract from module
       AUTHOR         => 'east') : ()),
);
