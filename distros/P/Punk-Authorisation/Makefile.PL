use 5.010;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::Depends;

# Punk, asserted at configure time. ExtUtils::Depends when it is installed,
# its include directory when this is a checkout beside it. Absolute, because
# `make disttest` prepends the outer INC to the distdir build and a relative
# ../Punk/include then resolves against the wrong root - where an installed
# older header wins silently.
#
# What this buys is the assertion and not a header: nothing here includes
# pk_abi.h. include/pau/pau_clos.h reads the context slots directly, against
# the layout Punk's ABI fixes, and says so where it does it. The -I is kept
# for the day that stops being true.
my @PROVIDERS = ( [ 'Punk' => '../Punk/include' ] );

my $INC = '-Iinclude';
{
    my $dep;
    if (eval { $dep = ExtUtils::Depends->new('Punk::Authorisation',
                          map { $_->[0] } @PROVIDERS); 1 } && $dep) {
        my %v = $dep->get_makefile_vars;
        $INC .= ' ' . $v{INC} if $v{INC};
    }
    else {
        require Cwd;
        my @missing = grep { !-d $_->[1] } @PROVIDERS;
        die "Punk::Authorisation needs " . join(', ', map { $_->[0] } @missing)
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
    NAME             => 'Punk::Authorisation',
    PM               => \%PM,
    AUTHOR           => ['LNATION <email@lnation.org>'],
    VERSION_FROM     => 'lib/Punk/Authorisation.pm',
    ABSTRACT_FROM    => 'lib/Punk/Authorisation.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010000',
    # Needed at CONFIGURE time: the block above asks ExtUtils::Depends for
    # Punk before it can write a Makefile, and PREREQ_PM is only honoured
    # afterwards.
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => '0',
        'ExtUtils::Depends'   => '0.404',
        'Punk'                => '0.32',
    },
    TEST_REQUIRES => {
        'Test::More' => '0',
    },
    PREREQ_PM => {
        # 0.32 for $app->auth_config - the role ladder and the roles hook the
        # `auth` keyword already holds, which is where this plugin reads them
        # rather than being told them twice. Also the release where `punk
        # doctor` loads every Punk::Command::* on @INC, so this distribution's
        # row appears without one of its commands having been run first.
        'Punk' => '0.32',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        prereqs => {
            test => {
                recommends => {
                    'DBD::SQLite' => '0',    # the grants half, against the DDL
                },
            },
        },
    },
    INC    => $INC,
    macro  => { TARFLAGS => "--format=ustar -c -v -f" },
    dist   => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean  => { FILES => 'Punk-Authorisation-*' },
    # MakeMaker maps Authorisation.xs -> .c and rescans neither the INCLUDE:
    # fragments nor the headers, so an edit to either does not rebuild. Force
    # it. Both globs run at configure time: a header added later is not in
    # this list until Makefile.PL is run again.
    depend => {
        'Authorisation.c' => join(' ', glob('xs/*.xs')),
        'Authorisation.o' => join(' ', glob('include/pau/*.h')),
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
