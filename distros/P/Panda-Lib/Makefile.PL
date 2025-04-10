use 5.018;
use Config;
use Panda::Install;

my %params = (
    NAME          => 'Panda::Lib',
    VERSION_FROM  => 'lib/Panda/Lib.pm',
    ABSTRACT_FROM => 'lib/Panda/Lib.pod',
    PREREQ_PM     => {'Time::HiRes' => 0},
    TEST_REQUIRES => {'Test::Fatal' => 0, 'JSON::XS' => 0},
    CPLUS         => 11,
    SRC           => ['src'],
    INC           => '-Isrc',
    BIN_DEPS      => ['Panda::Export', 'Panda::XS', 'CPP::panda::lib'],
    BIN_SHARE     => {
        CPLUS    => 11,
        INCLUDE  => {'src' => '/'},
        TYPEMAPS => {
            'typemap'        => '',
        }
    },
    CCFLAGS  => '-Wall -Wextra',
    OPTIMIZE  => '-g0 -O2',
    #CC => 'clang++',
);

write_makefile(%params);

