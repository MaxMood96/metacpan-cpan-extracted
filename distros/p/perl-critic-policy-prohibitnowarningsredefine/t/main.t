use strict;
use warnings;

use re '/aa';

use 5.014;

use Test::More;

use Perl::Critic;
use Perl::Critic::Policy::ProhibitNoWarningsRedefine;

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for
# a .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets -- which then fail for want of POD rather than for redefining.
# Note the hyphen in -single-policy: -single_policy is accepted and silently
# ignored, leaving all 200-odd policies switched on.
my $critic = Perl::Critic->new( -profile => q{}, '-single-policy' => 'ProhibitNoWarningsRedefine', -severity => 1 );

sub violations {
    my ($source) = @_;
    return scalar $critic->critique( \"use strict;\nuse warnings;\n$source\n" );
}

my %prohibited = (
    'quoted'          => q{no warnings 'redefine';},
    'qw list'         => q{no warnings qw{redefine once};},
    'double quoted'   => q{no warnings "redefine";},
    'bare no warnings'=> q{no warnings;},
);

foreach my $case ( sort keys %prohibited ) {
    is( violations( $prohibited{$case} ), 1, "$case is a violation" );
}

my %allowed = (
    'another category'  => q{no warnings 'once';},
    'several others'    => q{no warnings qw{uninitialized numeric};},
    'use warnings'      => q{use warnings 'redefine';},
    'no strict'         => q{no strict 'refs';},
    'Test::MockModule'  => q{my $m = Test::MockModule->new('X'); $m->redefine( y => sub { 1 } );},
);

foreach my $case ( sort keys %allowed ) {
    is( violations( $allowed{$case} ), 0, "$case is not a violation" );
}

is( violations(q{no warnings 'redefine';  ## no critic (ProhibitNoWarningsRedefine)}), 0, "an explicit no-critic is what signs it off" );

# The guarded categories are configurable.
{
    my $configured = Perl::Critic->new(
        -profile         => \"[ProhibitNoWarningsRedefine]\ncategories = prototype\n",
        '-single-policy' => 'ProhibitNoWarningsRedefine',
        -severity        => 1,
    );

    is( scalar $configured->critique( \"use strict;\nno warnings 'prototype';\n" ),
        1, 'a configured category is a violation' );
    is( scalar $configured->critique( \"use strict;\nno warnings 'redefine';\n" ),
        0, 'and one left out of the list is not' );
}

done_testing();
