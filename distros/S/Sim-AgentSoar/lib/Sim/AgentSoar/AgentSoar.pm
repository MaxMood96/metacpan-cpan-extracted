package Sim::AgentSoar::AgentSoar;

use strict;
use warnings;

our $VERSION = '0.06';

use Sim::AgentSoar::Engine;
use Sim::AgentSoar::Node;

sub new 
{
    my ($class, %args) = @_;

    my $self = 
    {
        worker               => $args{worker},
        max_depth            => $args{max_depth} // 20,
        branching_factor     => $args{branching_factor} // 1,
        regression_tolerance => $args{regression_tolerance},

        stats => 
        {
            nodes_expanded   => 0,
            children_created => 0,
            llm_calls        => 0,
            corrections      => 0,
        },
    };

    die "worker required" unless $self->{worker};

    return bless $self, $class;
}

sub run 
{
    my ($self, %args) = @_;

    my $start  = $args{start};
    my $target = $args{target};

    die "start required"  unless defined $start;
    die "target required" unless defined $target;

    my @OPEN;
    my %VISITED;
    my %NODES;
    my $node_id = 0;

    my $root = Sim::AgentSoar::Node->new(
        id       => $node_id,
        parent   => undef,
        value    => $start,
        metric   => Sim::AgentSoar::Engine->metric($start, $target),
        depth    => 0,
        operator => undef,
    );

    push @OPEN, $root;
    $VISITED{$start} = 1;
    $NODES{$node_id} = $root;
    $node_id++;

    while (@OPEN) {

        # Best-first by (metric, depth)
        @OPEN = sort 
        {
            $a->metric <=> $b->metric
            ||
            $a->depth  <=> $b->depth
        } @OPEN;

        my $node = shift @OPEN;
        $self->{stats}->{nodes_expanded}++;

        if ($node->metric == 0) 
        {
            return $self->_reconstruct_path($node, \%NODES);
        }

        next if $node->depth >= $self->{max_depth};

        my @children =
            $self->_expand_node($node, $target, \%VISITED, \$node_id);
        
        $self->{stats}->{children_created} += scalar @children;
        push @OPEN, @children;
    }

    return undef;
}

sub _expand_node 
{
    my ($self, $node, $target, $visited, $node_id_ref) = @_;

    my @children;
    my %local_proposals;
    my $attempts = 0;
    my $max_attempts = 10;

    while (
        @children < $self->{branching_factor}
        && $attempts < $max_attempts
    ) 
    {

        $self->{stats}->{llm_calls}++;
        my $operator = $self->{worker}->propose(
            value  => $node->value,
            metric => $node->metric,
            target => $target,
        );

        $attempts++;

        next unless defined $operator;
        next if $local_proposals{$operator}++;

        my $new_value =
            Sim::AgentSoar::Engine->apply_operator(
                $node->value, $operator
            );

        next unless Sim::AgentSoar::Engine->valid_value($new_value);

        my $new_metric =
            Sim::AgentSoar::Engine->metric($new_value, $target);

        # ---- Correction stage ----
        if (defined $self->{regression_tolerance}) 
        {
        
           $self->{stats}->{llm_calls}++;
           $self->{stats}->{corrections}++;

            my $corrected =
                $self->{worker}->correct(
                    value                => $node->value,
                    target               => $target,
                    operator             => $operator,
                    old_metric           => $node->metric,
                    new_metric           => $new_metric,
                    regression_tolerance => $self->{regression_tolerance},
                );

            if (defined $corrected && $corrected ne $operator) 
            {

                $operator = $corrected;

                $new_value =
                    Sim::AgentSoar::Engine->apply_operator(
                        $node->value, $operator
                    );

                next unless Sim::AgentSoar::Engine->valid_value($new_value);

                $new_metric =
                    Sim::AgentSoar::Engine->metric($new_value, $target);
            }
        }
        # ---- End correction ----

        next if $visited->{$new_value};

        my $child = Sim::AgentSoar::Node->new(
            id       => $$node_id_ref,
            parent   => $node->id,
            value    => $new_value,
            metric   => $new_metric,
            depth    => $node->depth + 1,
            operator => $operator,
        );

        $visited->{$new_value} = 1;
        $$node_id_ref++;

        push @children, $child;
    }

    return @children;
}

sub _reconstruct_path 
{
    my ($self, $node, $nodes) = @_;

    my @path;

    while ($node) 
    {
        unshift @path, 
        {
            value    => $node->value,
            operator => $node->operator,
        };

        my $parent_id = $node->parent;
        $node = defined $parent_id ? $nodes->{$parent_id} : undef;
    }

    return \@path;
}

sub stats 
{
    my ($self) = @_;
    return $self->{stats};
}

1;


=pod

=head1 NAME

Sim::AgentSoar::AgentSoar - Explicit SOAR-inspired search controller with LLM-guided operator selection

=head1 SYNOPSIS

  use Sim::AgentSoar::AgentSoar;
  use Sim::AgentSoar::Worker;

  my $worker = Sim::AgentSoar::Worker->new(
      model => 'llama3.2:1b',
  );

  my $search = Sim::AgentSoar::AgentSoar->new(
      worker               => $worker,
      branching_factor     => 2,
      regression_tolerance => 2,
      max_depth            => 20,
  );

  my $path = $search->run(
      start  => 4,
      target => 19,
  );

=head1 DESCRIPTION

Sim::AgentSoar::AgentSoar implements an explicit state-space search architecture
inspired by the classical SOAR cognitive model, but reinterpreted with modern
LLM-assisted heuristic control. Indeed, the model substitute the flat, uplfront
planning mode of LLMs with a Soar-like Subgoalling approach.
The last Lisp implementation, Soar 5.0, has been taken as a reference.

The architecture strictly separates:

=over 4

=item * Structural recursion (search tree expansion)

=item * Deterministic evaluation (Engine)

=item * Heuristic proposal (Worker / LLM)

=item * Optional bounded local correction

=back

Unlike purely LLM-driven agents, this module preserves deterministic
control over state validation, search ordering, and termination criteria.
The LLM is never allowed to:

=over 4

=item * Evaluate goal satisfaction

=item * Modify search ordering

=item * Override state validity

=item * Introduce nondeterministic structural changes

=back

This guarantees that heuristic instability cannot corrupt the search backbone.

=head2 AgentSoar Model

The search procedure maintains:

=over 4

=item * An OPEN list ordered by (metric, depth)

=item * A VISITED set preventing state repetition

=item * A bounded branching factor

=item * Optional regression tolerance logic

=back

Each node expansion proceeds as follows:

=over 4

=item 1. The Worker proposes an operator.

=item 2. The Engine deterministically applies and evaluates the operator.

=item 3. If regression exceeds tolerance, a single correction pass is allowed.

=item 4. Valid child nodes are inserted into OPEN.

=back

The recursion is structural (tree-based), not narrative.

=head2 Instrumentation

The module records runtime statistics accessible via C<stats()>:

  {
      nodes_expanded   => ...,
      children_created => ...,
      llm_calls        => ...,
      corrections      => ...,
  }

This supports empirical evaluation of heuristic efficiency.

=head1 CONSTRUCTOR

=head2 new

  my $search = Sim::AgentSoar::AgentSoar->new(
      worker               => $worker,   # required
      branching_factor     => 2,         # default 1
      regression_tolerance => 2,         # optional
      max_depth            => 20,        # default 20
  );

=head1 METHODS

=head2 run

  my $path = $search->run(
      start  => $start,
      target => $target,
  );

Executes the search and returns an array reference describing the solution
path, or undef if no solution is found within constraints.

=head2 stats

Returns a hash reference of runtime statistics.

=head1 RESEARCH NOTES

This implementation explores a hybrid model:

=over 4

=item * Explicit symbolic search

=item * LLM-guided operator selection

=item * Bounded internal recursion (correction stage)

=item * Deterministic invariants

=back

The design intentionally avoids letting the LLM control topology.
All structural evolution must occur through explicit, measurable mechanisms.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

AI tools were used to accelerate drafting and refactoring. No changes were merged without human review; the maintainer remains the sole accountable party for correctness, security, and licensing compliance.

=cut
