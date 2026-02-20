package Sim::AgentSoar::Node;

use strict;
use warnings;

our $VERSION = '0.06';

sub new 
{
    my ($class, %args) = @_;

    my $self = 
    {
        id       => $args{id},
        parent   => $args{parent},
        value    => $args{value},
        metric   => $args{metric},
        depth    => $args{depth},
        operator => $args{operator},
    };

    return bless $self, $class;
}

sub id       { $_[0]->{id} }
sub parent   { $_[0]->{parent} }
sub value    { $_[0]->{value} }
sub metric   { $_[0]->{metric} }
sub depth    { $_[0]->{depth} }
sub operator { $_[0]->{operator} }

1;


=pod

=head1 NAME

Sim::AgentSoar::Node - Formal search state representation

=head1 DESCRIPTION

Sim::AgentSoar::Node represents a single state in the explicit search tree
managed by C<Sim::AgentSoar::AgentSoar>.

Each node is an immutable snapshot of the search state at a given depth.
It encodes both structural position in the tree and evaluation metadata.

=head2 Conceptual Role

A Node formalizes the separation between:

=over 4

=item * Structural recursion (tree topology)

=item * Deterministic evaluation (metric)

=item * Heuristic action (operator_applied)

=back

Nodes do not contain behavioral logic. They are purely representational.

This design enforces:

=over 4

=item * Deterministic state tracking

=item * Explicit parent-child relationships

=item * Transparent reconstruction of solution paths

=item * Isolation of heuristic decisions from structural control

=back

=head2 Fields

Each Node instance contains:

=over 4

=item * id

Unique numeric identifier.

=item * parent

Identifier of the parent node (undef for root).

=item * value

Domain state value (integer in calibration domain).

=item * metric

Evaluation score relative to target.

=item * depth

Depth in search tree.

=item * operator

Operator applied to reach this node.

=back

=head2 Research Significance

The Node abstraction embodies the explicit search paradigm:

AgentSoar is structural, not narrative.

Heuristics may influence expansion,
but the search state remains fully inspectable and reconstructible.

This makes the architecture suitable for:

=over 4

=item * Empirical evaluation

=item * Deterministic replay

=item * Controlled architectural evolution

=item * Instrumented experimentation

=back

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=cut
