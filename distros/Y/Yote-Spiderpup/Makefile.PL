use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Yote::Spiderpup',
    VERSION_FROM     => 'lib/Yote/Spiderpup.pm',
    ABSTRACT         => 'Compile YAML recipes into reactive JavaScript and HTML',
    AUTHOR           => 'Eric Wolf',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010',
    EXE_FILES        => ['bin/pupserver'],
    PREREQ_PM        => {
        'CSS::LESSp'      => 0,
        'YAML'            => 0,
        'JSON::PP'        => 0,
        'IO::Socket::SSL' => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
    },
);
