use strict;
use warnings;

use re '/aa';

use 5.014;

use Test::More;

use Perl::Critic;
use Perl::Critic::Policy::ProhibitUseLib;

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for
# a .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets -- which then fail for want of POD rather than for use lib.
# Note the hyphen in -single-policy: -single_policy is accepted and silently
# ignored, leaving all 200-odd policies switched on.
my $critic = Perl::Critic->new( -profile => q{}, '-single-policy' => 'ProhibitUseLib', -severity => 1 );

sub violations {
    my ($source) = @_;
    return scalar $critic->critique( \"use strict;\nuse warnings;\n$source\n" );
}

my %prohibited = (
    'FindBin relative path' => q{use lib "$FindBin::Bin/../lib";},
    'absolute path'         => q{use lib '/opt/myapp/lib';},
    'several at once'       => q{use lib 'lib', 't/lib';},
    'lib::relative'         => q{use lib::relative '../lib';},
);

foreach my $case ( sort keys %prohibited ) {
    is( violations( $prohibited{$case} ), 1, "$case is a violation" );
}

my %allowed = (
    'FindBin::libs'       => q{use FindBin::libs;},
    'FindBin itself'      => q{use FindBin;},
    'no lib'              => q{no lib '/opt/myapp/lib';},
    'a module named libz' => q{use libz;},
    'lib::abs by default' => q{use lib::abs '../lib';},
    'unshifting @INC'     => q{unshift @INC, '/opt/myapp/lib';},
    'a sub named lib'     => q{sub lib { return 1 }},
);

foreach my $case ( sort keys %allowed ) {
    is( violations( $allowed{$case} ), 0, "$case is not a violation" );
}

is( violations(q{use lib '/opt/myapp/lib';  ## no critic (ProhibitUseLib)}), 0, "an explicit no-critic is what signs it off" );

# The pragma list is configurable, so a shop that has settled on one of the
# others can say so.
{
    my $configured = Perl::Critic->new(
        -profile         => \"[ProhibitUseLib]\nmodules = lib lib::abs\n",
        '-single-policy' => 'ProhibitUseLib',
        -severity        => 1,
    );

    is( scalar $configured->critique( \"use strict;\nuse lib::abs '../lib';\n" ),
        1, 'a configured module name is a violation' );
    is( scalar $configured->critique( \"use strict;\nuse lib::relative '../lib';\n" ),
        0, 'and one left out of the list is not' );
}

done_testing();
