package Logic::Relational::Goal::Domain;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';
use Carp qw(croak);
use Logic::Relational::Domain;
use Logic::Relational::Unifier qw(unify);

=head1 NAME

Logic::Relational::Goal::Domain - Goal to constrain a variable to a range.

=cut

sub new ( $class, $var, @spec ) {
    if ( @spec == 1 && ref( $spec[0] ) eq 'ARRAY' ) {
        return bless { var => $var, values => $spec[0] }, $class;
    }
    elsif ( @spec == 2 ) {
        return bless { var => $var, min => $spec[0], max => $spec[1] }, $class;
    }
    croak "Invalid Goal::Domain specification";
}

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    my $val = $subst->walk( $self->{var} );

    my $domain_spec =
      exists $self->{values}
      ? { values => $self->{values} }
      : { min    => $self->{min}, max => $self->{max} };

    if ( ref($val) eq 'Logic::Relational::Variable' ) {
        my $domain    = Logic::Relational::Domain->new($domain_spec);
        my $new_subst = unify( $val, $domain, $subst );
        if ($new_subst) {
            my $succ = $state->derive(
                substitution => $new_subst,
                goals        => $remaining,
            );
            return $succ // ();
        }
    }
    else {
        my $domain = Logic::Relational::Domain->new($domain_spec);
        if ( $val =~ /^-?\d+$/x && $domain->contains($val) ) {
            my $succ = $state->derive( goals => $remaining, );
            return $succ // ();
        }
    }

    return ();
}

sub freshen ( $self, $var_map ) {
    require Logic::Relational::DSL;
    my $fresh_var =
      Logic::Relational::DSL::freshen_val( $self->{var}, $var_map );
    return
      exists $self->{values}
      ? ref($self)->new( $fresh_var, $self->{values} )
      : ref($self)->new( $fresh_var, $self->{min}, $self->{max} );
}

sub is_ground ( $self, $subst ) {
    return $self->term_is_ground( $self->{var}, $subst );
}

1;
