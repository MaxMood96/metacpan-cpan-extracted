package Logic::Relational::Query;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::Query - Manages the execution and backtracking search of a query.

=head1 SYNOPSIS

    use Logic::Relational::Query;
    my $query = Logic::Relational::Query->new(
        program    => $program,
        goals      => [$goal],
        predicates => $predicates_snapshot,
    );
    while (my $solution = $query->next) {
        ...
    }

=head1 DESCRIPTION

C<Logic::Relational::Query> executes the logical goals using a depth-first search
and an explicit agenda of execution states. This design avoids deep recursion or
complex mutable call stacks.

=head1 METHODS

=head2 new

Constructor. Takes C<program> (Program), C<goals> (arrayref), and C<predicates>
(snapshot of the predicates hash).

=head2 next

Performs the search step. Returns the next C<Logic::Relational::Solution> object,
or C<undef> if all solutions have been exhausted.

=head2 reify_solution

Constructs a C<Logic::Relational::Solution> object from a successful execution state.

=cut

use Carp qw(croak);

sub new ( $class, %args ) {
    my $program    = $args{program} // croak "program is required";
    my $goals      = $args{goals}   // croak "goals is required";
    my $predicates = $args{predicates}
      // croak "predicates snapshot is required";

    require Logic::Relational::Substitution;
    require Logic::Relational::State;
    my $initial_subst = $args{substitution}
      // Logic::Relational::Substitution->new;
    my $initial_state = Logic::Relational::State->new(
        substitution => $initial_subst,
        goals        => $goals,
    );

    my $self = {
        program         => $program,
        predicates      => $predicates,
        generators      => $args{generators} // {},
        agenda          => [$initial_state],
        trace_cb        => undef,
        is_backtracking => 0,
    };
    return bless $self, $class;
}

sub trace ( $self, $callback = undef ) {
    if ( defined $callback ) {
        $self->{trace_cb} = $callback;
    }
    return $self->{trace_cb};
}

sub next ($self) {
    my $trace_cb = $self->{trace_cb};

    while ( my $state = pop @{ $self->{agenda} } ) {
        if ( $self->{is_backtracking} && $trace_cb ) {
            require Logic::Relational::TraceEvent;
            $trace_cb->(
                Logic::Relational::TraceEvent->new(
                    type         => 'backtrack',
                    goal         => $state->goals->[0],
                    substitution => $state->substitution
                )
            );
            $self->{is_backtracking} = 0;
        }

        if ( !$state->has_goals ) {
            if ($trace_cb) {
                require Logic::Relational::TraceEvent;
                $trace_cb->(
                    Logic::Relational::TraceEvent->new(
                        type         => 'solution',
                        goal         => undef,
                        substitution => $state->substitution
                    )
                );
            }
            $self->{is_backtracking} = 1;
            return $self->reify_solution($state);
        }

        my ( $goal, @remaining ) = $state->split_first_goal;

        if ($trace_cb) {
            require Logic::Relational::TraceEvent;
            $trace_cb->(
                Logic::Relational::TraceEvent->new(
                    type         => 'call',
                    goal         => $goal,
                    substitution => $state->substitution
                )
            );
        }

        my @successors = $goal->expand(
            state        => $state,
            program      => $self->{program},
            predicates   => $self->{predicates},
            generators   => $self->{generators},
            substitution => $state->substitution,
            remaining    => \@remaining,
        );

        if ( scalar @successors > 0 ) {
            $self->{is_backtracking} = 0;
            if ($trace_cb) {
                require Logic::Relational::TraceEvent;
                $trace_cb->(
                    Logic::Relational::TraceEvent->new(
                        type         => 'success',
                        goal         => $goal,
                        substitution => $state->substitution
                    )
                );
                if ( scalar @successors > 1 ) {
                    $trace_cb->(
                        Logic::Relational::TraceEvent->new(
                            type         => 'choice',
                            goal         => $goal,
                            substitution => $state->substitution
                        )
                    );
                }
            }
        }
        else {
            $self->{is_backtracking} = 1;
            if ($trace_cb) {
                require Logic::Relational::TraceEvent;
                $trace_cb->(
                    Logic::Relational::TraceEvent->new(
                        type         => 'fail',
                        goal         => $goal,
                        substitution => $state->substitution
                    )
                );
            }
        }

        push @{ $self->{agenda} }, reverse @successors;
    }
    return undef;
}

sub reify_solution ( $self, $state ) {
    require Logic::Relational::Solution;
    return Logic::Relational::Solution->new(
        substitution => $state->substitution, );
}

use overload
  bool     => sub ( $self, $, $ ) { $self->is_true },
  fallback => 1;

sub is_true ($self) {
    return $self->next ? 1 : 0;
}

sub is_success ($self) {
    return $self->is_true;
}

sub all ( $self, %options ) {
    my $limit = exists $options{limit} ? $options{limit} : 10_000;
    my @solutions;

    while ( my $sol = $self->next ) {
        push @solutions, $sol;
        if ( defined $limit && scalar(@solutions) >= $limit ) {
            last;
        }
    }

    return wantarray ? @solutions : \@solutions;
}

sub all_values ( $self, $var, %options ) {
    my @sols   = $self->all(%options);
    my @values = map { $_->value($var) } @sols;
    return wantarray ? @values : \@values;
}

sub first_value ( $self, $var ) {
    my $sol = $self->next // return undef;
    return $sol->value($var);
}

sub value ( $self, $var ) {
    return $self->first_value($var);
}

1;
