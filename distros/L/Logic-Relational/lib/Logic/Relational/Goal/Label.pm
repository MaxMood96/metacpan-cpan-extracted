package Logic::Relational::Goal::Label;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';

=head1 NAME

Logic::Relational::Goal::Label - Backtracking labeling goal for domain variables.

=cut

sub new ( $class, $vars ) {
    return bless { vars => $vars }, $class;
}

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    my @vars = @{ $self->{vars} };

    # Find the unbound domain variable with the smallest domain (First-Fail heuristic)
    my $selected_var;
    my $selected_domain;
    my $min_size;

    for my $var (@vars) {
        my $val = $subst->walk($var);
        if ( ref($val) eq 'Logic::Relational::Variable' ) {
            my $d = $subst->{bindings}{ $val->id };
            if ( ref($d) eq 'Logic::Relational::Domain' ) {
                my $size = $d->size;
                if ( !defined $min_size || $size < $min_size ) {
                    $min_size        = $size;
                    $selected_var    = $val;
                    $selected_domain = $d;
                }
            }
        }
    }

    # If all domain variables are bound, we succeed
    if ( !$selected_var ) {
        my $succ = $state->derive( goals => $remaining, );
        return $succ // ();
    }

    # Backtrack over each value in the selected domain
    my @successors;
    require Logic::Relational::Unifier;

    for my $val ( $selected_domain->values ) {
        my $new_subst =
          Logic::Relational::Unifier::unify( $selected_var, $val, $subst );
        if ($new_subst) {
            my $succ = $state->derive(
                substitution => $new_subst,
                goals        => [ $self, @$remaining ],
            );
            push @successors, $succ if $succ;
        }
    }

    return @successors;
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
