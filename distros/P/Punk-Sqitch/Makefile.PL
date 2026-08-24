use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;

# Pure Perl, on purpose: nothing here runs per request. The boot check
# (phase 1) is one SELECT in the parent, and the rest is a CLI wrapping a
# Moo application. The C the Punk family writes earns its keep on hot
# paths, and this distribution has none.

my %WriteMakefileArgs = (
    NAME             => 'Punk::Sqitch',
    AUTHOR           => ['LNATION <email@lnation.org>'],
    VERSION_FROM     => 'lib/Punk/Sqitch.pm',
    ABSTRACT_FROM    => 'lib/Punk/Sqitch.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000',
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
    },
    TEST_REQUIRES => {
        'Test::More'  => '0',
        'File::Temp'  => '0',
    },
    PREREQ_PM => {
        'Punk'        => '0.31',     
        'App::Sqitch' => 'v1.0.0',   
        'URI::db'     => '0',        
        'DBI'         => '0',        
        'Cwd'         => '0',
        'File::Spec'  => '0',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            license => ['http://www.opensource.org/licenses/artistic-license-2.0'],
        },
        prereqs => {
            runtime => {
                recommends => {
                    'DBD::SQLite' => '0',   # the engine the tests deploy to
                },
            },
        },
    },
    macro => { TARFLAGS => "--format=ustar -c -v -f" },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES => 'Punk-Sqitch-*' },
    test  => { TESTS => 't/*.t' },
);

# compatibility with older MakeMakers
unless (eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 }) {
    my $tr = delete $WriteMakefileArgs{TEST_REQUIRES};
    my $pp = $WriteMakefileArgs{PREREQ_PM};
    $pp->{$_} = $tr->{$_} for keys %$tr;
}
delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };

WriteMakefile(%WriteMakefileArgs);
