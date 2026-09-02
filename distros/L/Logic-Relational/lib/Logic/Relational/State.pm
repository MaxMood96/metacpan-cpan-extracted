package Logic::Relational::State;

use v5.38;
use experimental 'signatures';
use Carp qw(croak);

=head1 NAME

Logic::Relational::State - Represents a frozen search state in the logic engine.

=cut

sub new ( $class, %args ) {
    my $subst = $args{substitution} // croak "substitution is required";
    my $goals = $args{goals}        // croak "goals list is required";
    my $props = $args{propagators}  // [];
    return bless {
        substitution => $subst,
        goals        => $goals,
        propagators  => $props
    }, $class;
}

sub substitution ($self) {
    return $self->{substitution};
}

sub goals ($self) {
    return $self->{goals};
}

sub propagators ($self) {
    return $self->{propagators};
}

sub has_goals ($self) {
    return scalar @{ $self->{goals} } > 0;
}

sub split_first_goal ($self) {
    my ( $first, @rest ) = @{ $self->{goals} };
    return ( $first, @rest );
}

sub add_propagator ( $self, $callback ) {
    my $new_props = [ @{ $self->{propagators} }, $callback ];
    return ref($self)->new(
        substitution => $self->{substitution},
        goals        => $self->{goals},
        propagators  => $new_props,
    );
}

sub propagate ( $self, $subst ) {
    my $changed       = 1;
    my $current_subst = $subst;

    while ($changed) {
        $changed = 0;
        for my $prop ( @{ $self->{propagators} } ) {
            my $new_subst = $prop->($current_subst);
            return unless $new_subst;

            # Scalar reference address comparison in Perl to detect changes
            if ( $new_subst != $current_subst ) {
                $current_subst = $new_subst;
                $changed       = 1;
            }
        }
    }
    return $current_subst;
}

sub derive ( $self, %args ) {
    my $new_subst = $args{substitution} // $self->{substitution};
    my $new_goals = $args{goals}        // $self->{goals};
    my $new_props = $args{propagators}  // $self->{propagators};

    my $temp_state = bless {
        substitution => $new_subst,
        goals        => $new_goals,
        propagators  => $new_props,
      },
      ref($self);

    my $propagated_subst = $temp_state->propagate($new_subst);
    return unless $propagated_subst;

    return ref($self)->new(
        substitution => $propagated_subst,
        goals        => $new_goals,
        propagators  => $new_props,
    );
}

1;
