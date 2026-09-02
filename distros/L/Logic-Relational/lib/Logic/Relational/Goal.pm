package Logic::Relational::Goal;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::Goal - Base class for relational logic goals.

=head1 SYNOPSIS

    package Logic::Relational::Goal::MyGoal;
    use parent 'Logic::Relational::Goal';

=head1 DESCRIPTION

C<Logic::Relational::Goal> defines the interface for all logic goals in the engine.
Every goal must implement C<expand> and C<freshen>.

=head1 METHODS

=head2 expand

Abstract method. Evaluates the goal and returns a list of successor C<Logic::Relational::State> objects.

=head2 freshen

Abstract method. Takes a variable mapping and returns a freshened copy of the goal.

=head2 is_ground

Abstract method. Checks if the goal is ground (contains no unbound variables)
under the current substitution.

=head2 term_is_ground

Helper method to check if a term is ground under a substitution.

=cut

use Carp qw(croak);

sub expand ( $self, %args ) {
    croak "expand method must be implemented by subclass";
}

sub freshen ( $self, $var_map ) {
    croak "freshen method must be implemented by subclass";
}

sub is_ground ( $self, $subst ) {
    croak "is_ground method must be implemented by subclass";
}

sub term_is_ground ( $self, $term, $subst ) {
    $term = $subst->walk($term);
    if ( ref($term) eq 'Logic::Relational::Variable' ) {    ## no critic (ProhibitCascadingIfElse)
        return 0;
    }
    elsif ( ref($term) eq 'Logic::Relational::Term' ) {
        for my $arg ( @{ $term->args } ) {
            return 0 unless $self->term_is_ground( $arg, $subst );
        }
    }
    elsif ( ref($term) eq 'ARRAY' ) {
        for my $arg (@$term) {
            return 0 unless $self->term_is_ground( $arg, $subst );
        }
    }
    elsif ( ref($term) eq 'Logic::Relational::ArrayRest' ) {
        return $self->term_is_ground( $term->term, $subst );
    }
    elsif ( ref($term) eq 'HASH' ) {
        for my $val ( values %$term ) {
            return 0 unless $self->term_is_ground( $val, $subst );
        }
    }
    return 1;
}

sub as_string ($self) {
    if ( $self->can('as_term') ) {
        return $self->as_term->as_string;
    }
    my $pkg = ref($self);
    $pkg =~ s/^Logic::Relational::Goal:://x;
    return $pkg;
}

1;
