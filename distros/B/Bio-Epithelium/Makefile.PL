use 5.028002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Bio::Epithelium',
    VERSION_FROM      => 'lib/Bio/Epithelium.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => { Evo::GA => 0.1.13 }, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/Bio/Epithelium.pm', # retrieve abstract from module
    AUTHOR            => 'koboldwiz <koboldwiz@yahoo.com>',
    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);
