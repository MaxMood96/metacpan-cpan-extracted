package Logic::Relational::Goal::Is;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';
use Carp qw(croak);
require Logic::Relational::Unifier;

=head1 NAME

Logic::Relational::Goal::Is - Evaluates arithmetic expressions and unifies results.

=cut

sub new ( $class, $target_var, $vars, $code ) {
    return bless {
        target_var => $target_var,
        vars       => $vars,
        code       => $code,
    }, $class;
}

sub target_var ($self) { return $self->{target_var}; }
sub vars       ($self) { return $self->{vars}; }
sub code       ($self) { return $self->{code}; }

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    # Verify all referenced input variables are ground
    for my $var ( @{ $self->{vars} } ) {
        my $walked = $subst->walk($var);
        if ( ref($walked) eq 'Logic::Relational::Variable' ) {
            croak
"Arithmetic evaluation 'is' attempted to read unbound logical variable \$"
              . $var->name . "\n";
        }
    }

    # Reify input values
    my @vals = map { $subst->reify($_) } @{ $self->{vars} };

    # Evaluate arithmetic closure
    my $result_val = $self->{code}->(@vals);

    # Unify target variable with calculated result
    my $new_subst =
      Logic::Relational::Unifier::unify( $self->{target_var}, $result_val,
        $subst );

    if ($new_subst) {
        my $succ = $state->derive(
            substitution => $new_subst,
            goals        => $remaining,
        );
        return $succ // ();
    }
    return ();
}

sub freshen ( $self, $var_map ) {
    my $fresh_target =
      ref( $self->{target_var} )
      && $self->{target_var}->can('freshen')
      ? $self->{target_var}->freshen($var_map)
      : $self->{target_var};

    my @fresh_vars =
      map { ref($_) && $_->can('freshen') ? $_->freshen($var_map) : $_ }
      @{ $self->{vars} };

    return ref($self)->new( $fresh_target, \@fresh_vars, $self->{code} );
}

sub is_ground ( $self, $subst ) {
    return 0 unless $self->term_is_ground( $self->{target_var}, $subst );
    for my $var ( @{ $self->{vars} } ) {
        return 0 unless $self->term_is_ground( $var, $subst );
    }
    return 1;
}

1;
