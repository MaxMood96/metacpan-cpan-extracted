use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'JSON::Parser::Regexp',
    VERSION_FROM      => 'lib/JSON/Parser/Regexp.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {'Regexp::Grammars' => 0}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/JSON/Parser/Regexp.pm', # retrieve abstract from module
    AUTHOR            => '',
    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);
