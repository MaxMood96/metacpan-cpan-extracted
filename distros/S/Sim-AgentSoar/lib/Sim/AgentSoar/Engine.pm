package Sim::AgentSoar::Engine;

use strict;
use warnings;

our $VERSION = '0.06';

our @ALLOWED_OPERATORS = qw(
    add_1
    sub_1
    add_3
    sub_3
    mul_2
    div_2_if_even
);

our $MIN_VALUE = -100;
our $MAX_VALUE = 100;

sub allowed_operators 
{
    return @ALLOWED_OPERATORS;
}

sub apply_operator 
{
    my ($class, $value, $op) = @_;

    return $value + 1 if $op eq 'add_1';
    return $value - 1 if $op eq 'sub_1';
    return $value + 3 if $op eq 'add_3';
    return $value - 3 if $op eq 'sub_3';
    return $value * 2 if $op eq 'mul_2';

    if ($op eq 'div_2_if_even') 
    {
        return undef unless $value % 2 == 0;
        return int($value / 2);
    }

    return undef;
}

sub valid_value 
{
    my ($class, $value) = @_;

    return defined($value)
        && $value >= $MIN_VALUE
        && $value <= $MAX_VALUE;
}

sub metric 
{
    my ($class, $value, $target) = @_;
    return abs($value - $target);
}

1;


=pod

=head1 NAME

Sim::AgentSoar::Engine - Deterministic calibration environment for heuristic AgentSoar

=head1 DESCRIPTION

Sim::AgentSoar::Engine defines a minimal deterministic environment used to
calibrate and evaluate the Sim::AgentSoar architecture.

The domain consists of integer reachability under a fixed set of operators.
Although simple, it is intentionally chosen to expose core AgentSoar dynamics:

=over 4

=item * Local vs. global improvement tension

=item * Reversible and irreversible operations

=item * Potential regression

=item * Cycles and repetition

=item * Heuristic bias evaluation

=back

This module contains no probabilistic logic and no LLM interaction.
All state transitions and evaluations are deterministic.

=head2 Domain Definition

State:

  value => integer

Operators:

  add_1
  sub_1
  add_3
  sub_3
  mul_2
  div_2_if_even

Evaluation metric:

  abs(value - target)

Domain bounds:

  -100 <= value <= 100

=head2 Purpose

The integer domain serves as:

=over 4

=item * A calibration environment for testing heuristic quality

=item * A controlled benchmark for branching and correction logic

=item * A deterministic substrate for measuring LLM efficiency

=item * A regression testing environment for architectural changes

=back

Because the environment is fully observable and inexpensive to evaluate,
it allows clear separation between structural AgentSoar performance and
heuristic proposal behavior.

=head2 ReAgentSoar Role

In the broader reAgentSoar program, this module acts as:

=over 4

=item * A wind-tunnel model for cognitive architecture experiments

=item * A baseline for comparing deterministic and LLM-guided AgentSoar

=item * A controlled testbed for future memory-layer extensions

=back

The simplicity of the domain is intentional: it isolates architectural
effects from domain complexity.

=head1 METHODS

=head2 allowed_operators

Returns the list of valid operators.

=head2 apply_operator

Applies an operator to a state value.

=head2 valid_value

Ensures state remains within domain bounds.

=head2 metric

Computes distance to target.

=head1 AUTHOR

Gian Luca Brunetti (2026), gianluca.brunetti@gmail.com

=cut

