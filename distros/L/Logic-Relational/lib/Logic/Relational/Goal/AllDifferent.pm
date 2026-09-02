package Logic::Relational::Goal::AllDifferent;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';
use Carp qw(croak);

=head1 NAME

Logic::Relational::Goal::AllDifferent - Constraint goal that all variables must have distinct values.

=cut

sub new ( $class, $vars ) {
    return bless { vars => $vars }, $class;
}

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    my @vars = @{ $self->{vars} };

    my $propagator = sub ($curr_subst) {
        my %bound_vals;
        my %unbound_vars;

        # 1. Collect bound values and unbound constraint variables
        for my $var (@vars) {
            my $val = $curr_subst->walk($var);
            if ( ref($val) eq 'Logic::Relational::Variable' ) {
                $unbound_vars{ $val->id } = $val;
            }
            elsif ( ref($val) eq 'Logic::Relational::Domain' ) {
                croak "Walk returned raw domain object in propagator";
            }
            else {
                if ( exists $bound_vals{$val} ) {
                    return;    # Conflict! Same value bound to two variables
                }
                $bound_vals{$val} = 1;
            }
        }

        # 2. Prune bound values from unbound variables' domains
        for my $id ( keys %unbound_vars ) {
            my $val = $unbound_vars{$id};
            my $d   = $curr_subst->{bindings}{$id};
            if ( ref($d) eq 'Logic::Relational::Domain' ) {
                my %remaining_vals;
                for my $v ( $d->values ) {
                    if ( !exists $bound_vals{$v} ) {
                        $remaining_vals{$v} = 1;
                    }
                }

                my $new_size = scalar keys %remaining_vals;
                return if $new_size == 0;    # Conflict: domain is empty

                if ( $new_size < $d->size ) {
                    require Logic::Relational::Domain;
                    my $d_new =
                      Logic::Relational::Domain->new( \%remaining_vals );
                    if ( $d_new->is_bound ) {
                        $curr_subst =
                          $curr_subst->bind( $id, $d_new->bound_value );
                    }
                    else {
                        $curr_subst = $curr_subst->bind( $id, $d_new );
                    }
                }
            }
        }

        return $curr_subst;
    };

    my $new_subst = $propagator->($subst);
    if ($new_subst) {
        my $new_state = $state->add_propagator($propagator);
        my $succ      = $new_state->derive(
            substitution => $new_subst,
            goals        => $remaining,
        );
        return $succ // ();
    }

    return ();
}

sub freshen ( $self, $var_map ) {
    require Logic::Relational::DSL;
    my @fresh_vars = map { $_->freshen($var_map) } @{ $self->{vars} };
    return ref($self)->new( \@fresh_vars );
}

sub is_ground ( $self, $subst ) {
    for my $var ( @{ $self->{vars} } ) {
        return 0 unless $self->term_is_ground( $var, $subst );
    }
    return 1;
}

1;
