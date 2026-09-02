package Logic::Relational::Goal::Unify;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';

=head1 NAME

Logic::Relational::Goal::Unify - Goal that unifies two terms.

=cut

sub new ( $class, $left, $right ) {
    return bless { left => $left, right => $right }, $class;
}

sub left  ($self) { return $self->{left}; }
sub right ($self) { return $self->{right}; }

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    require Logic::Relational::Unifier;
    my $new_subst =
      Logic::Relational::Unifier::unify( $self->{left}, $self->{right},
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
    require Logic::Relational::DSL;
    my $fresh_l =
      Logic::Relational::DSL::freshen_val( $self->{left}, $var_map );
    my $fresh_r =
      Logic::Relational::DSL::freshen_val( $self->{right}, $var_map );
    return ref($self)->new( $fresh_l, $fresh_r );
}

sub is_ground ( $self, $subst ) {
    return $self->term_is_ground( $self->{left}, $subst )
      && $self->term_is_ground( $self->{right}, $subst );
}

1;
