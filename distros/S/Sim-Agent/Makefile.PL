use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Sim::Agent',
    VERSION_FROM => 'lib/Sim/Agent.pm',
    PREREQ_PM    => {},
    EXE_FILES    => ['bin/sim-agent'],
);
