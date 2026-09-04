use 5.008003;
use strict;
use warnings;
use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
    NAME             => 'Catalyst::Seal',
    AUTHOR           => ['LNATION <email@lnation.org>'],
    VERSION_FROM     => 'lib/Catalyst/Seal.pm',
    ABSTRACT_FROM    => 'lib/Catalyst/Seal.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.014',
    XS               => { 'Seal.xs' => 'Seal.c' },
    OBJECT           => 'Seal$(OBJ_EXT)',
    INC              => '-I.',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::More' => '0.88',   # done_testing
        'Storable'   => '0',
        'POSIX'      => '0',
    },
    PREREQ_PM => {
        'Catalyst::Runtime' => '5.90',
        'Class::MOP'        => '0',
        'Moose'             => '0',
        'Carp'              => '0',
        'Scalar::Util'      => '0',
        'Sub::Util'         => '1.40',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/ThisUsedToBeAnEmail/Catalyst-Seal.git',
                web  => 'https://github.com/ThisUsedToBeAnEmail/Catalyst-Seal',
            },
        },
    },
    macro => { TARFLAGS   => "--format=ustar -c -v -f" },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Catalyst-Seal-*' },
);

# Compatibility with old versions of ExtUtils::MakeMaker
unless (eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 }) {
    my $test_requires = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$test_requires} = values %$test_requires;
}

unless (eval { ExtUtils::MakeMaker->VERSION('6.55_03'); 1 }) {
    my $build_requires = delete $WriteMakefileArgs{BUILD_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$build_requires} = values %$build_requires;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
    unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete $WriteMakefileArgs{LICENSE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };
delete $WriteMakefileArgs{META_MERGE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.46'); 1 };

WriteMakefile(%WriteMakefileArgs);

# MakeMaker tracks neither include/*.h nor anything INCLUDEd by the .xs, so
# without this an edit to a header does not rebuild and the next test run
# quietly exercises the previous build. The glob runs at configure time, so
# re-run Makefile.PL after adding a header.
package MY;
sub depend {
    my @headers = glob 'include/*.h';
    return '' unless @headers;
    return "Seal\$(OBJ_EXT) : Seal.xs @headers\n";
}
