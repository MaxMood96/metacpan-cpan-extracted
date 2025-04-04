use 5.008;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Parallel::parallel_map',
    VERSION_FROM      => 'lib/Parallel/parallel_map.pm', # finds $VERSION
    PREREQ_PM         => {Parallel::DataPipe=>0.12}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Parallel/parallel_map.pm', # retrieve abstract from module
       AUTHOR         => 'Oleksandr Kharchenko <okharch@gmail.com>') : ()),
);
