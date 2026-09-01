use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

# Punk's pk_abi.h, for the three context accessors pak_clos.h uses.
# ExtUtils::Depends when Punk is installed, its include directory when this is
# a checkout beside it. Absolute, because `make disttest` prepends the outer
# INC to the distdir build and a relative ../Punk/include then resolves
# against the wrong root - where an installed older header wins silently.
my @PROVIDERS = ( [ 'Punk' => '../Punk/include' ] );

my $INC = '-Iinclude';
{
    my $dep;
    if (eval { $dep = ExtUtils::Depends->new('Punk::APIKey',
                          map { $_->[0] } @PROVIDERS); 1 } && $dep) {
        my %v = $dep->get_makefile_vars;
        $INC .= ' ' . $v{INC} if $v{INC};
    }
    else {
        require Cwd;
        my @missing = grep { !-d $_->[1] } @PROVIDERS;
        die "Punk::APIKey needs " . join(', ', map { $_->[0] } @missing)
          . " installed, or present as sibling directories.\n" if @missing;
        $INC .= join '', map { ' -I' . (Cwd::abs_path($_->[1]) || $_->[1]) }
                              @PROVIDERS;
    }
}

# Naming PM replaces MakeMaker's auto-detected map, and that map only ever
# held .pm and .pod anyway. This distribution also ships a Sqitch project
# under lib/, none of which is either - so the map is built by walking lib/,
# and everything under it installs. A hand-written list is the documented way
# to lose a file.
my %PM;
{
    my @todo = ('lib');
    while (my $dir = shift @todo) {
        opendir my $dh, $dir or next;
        for my $e (sort readdir $dh) {
            next if $e eq '.' || $e eq '..';
            my $p = "$dir/$e";
            if (-d $p) { push @todo, $p; next }
            (my $to = $p) =~ s{\Alib/}{\$(INST_LIB)/};
            $PM{$p} = $to;
        }
    }
}

my %WriteMakefileArgs = (
    NAME             => 'Punk::APIKey',
    PM               => \%PM,
    AUTHOR           => ['LNATION <email@lnation.org>'],
    VERSION_FROM     => 'lib/Punk/APIKey.pm',
    ABSTRACT_FROM    => 'lib/Punk/APIKey.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000',
    # Needed at CONFIGURE time: the block above asks ExtUtils::Depends for
    # Punk's installed header before it can write a Makefile, and PREREQ_PM
    # is only honoured afterwards.
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
        'ExtUtils::Depends'   => '0.404',
        'Punk'                => '0.32',   # provides pk_abi.h
    },
    TEST_REQUIRES => {
        'Test::More' => '0',
    },
    # 0.32 and not lower: install_kw (0.04), rate_hit (0.05), on_compile
    # (0.30) and Punk::Command->load_app (0.31) are all older than that, but
    # 0.32 is where `punk doctor` loads every Punk::Command::* before it
    # prints - which is what makes this distribution's row appear without
    # `punk apikey` having been the command that ran.
    PREREQ_PM => {
        'Punk' => '0.32',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        prereqs => {
            runtime => {
                recommends => {
                    # The schema registers itself through it when it is
                    # there; the POD carries the DDL when it is not.
                    'Punk::Sqitch' => '0.01',
                },
            },
            test => {
                recommends => {
                    'DBD::SQLite' => '0',    # the DDL against a real database
                    'App::Sqitch' => '0',    # and a real deploy of it
                },
            },
        },
    },
    INC    => $INC,
    macro  => { TARFLAGS => "--format=ustar -c -v -f" },
    dist   => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean  => { FILES => 'Punk-APIKey-*' },
    # MakeMaker maps APIKey.xs -> .c and rescans neither the INCLUDE:
    # fragments nor the headers, so an edit to either does not rebuild. Force
    # it.
    depend => {
        'APIKey.c' => join(' ', glob('xs/*.xs')),
        'APIKey.o' => join(' ', glob('include/pak/*.h')),
    },
);

unless (eval { ExtUtils::MakeMaker->VERSION('6.64'); 1 }) {
    my $tr = delete $WriteMakefileArgs{TEST_REQUIRES} || {};
    @{$WriteMakefileArgs{PREREQ_PM}}{keys %$tr} = values %$tr;
}
delete $WriteMakefileArgs{META_MERGE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.46'); 1 };
delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
    unless eval { ExtUtils::MakeMaker->VERSION('6.52'); 1 };
delete $WriteMakefileArgs{MIN_PERL_VERSION}
    unless eval { ExtUtils::MakeMaker->VERSION('6.48'); 1 };
delete $WriteMakefileArgs{LICENSE}
    unless eval { ExtUtils::MakeMaker->VERSION('6.31'); 1 };

WriteMakefile(%WriteMakefileArgs);
