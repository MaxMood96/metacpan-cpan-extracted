package Logic::Relational::Unifier;

use v5.38;
use experimental 'signatures';

use Carp qw(croak);
use builtin 'blessed';
no warnings 'experimental::builtin';

=head1 NAME

Logic::Relational::Unifier - Performs structural unification of logic terms.

=head1 SYNOPSIS

    use Logic::Relational::Unifier qw(unify);
    my $new_subst = unify($term1, $term2, $subst);

=head1 DESCRIPTION

C<Logic::Relational::Unifier> provides structural unification. It implements
the standard unification algorithm with an occurs check to prevent infinite terms.

=head1 FUNCTIONS

=head2 unify

Performs unification of two terms under a given C<Logic::Relational::Substitution>.
Returns the updated substitution if unification succeeds, or C<undef> if it fails.
Raises an exception if the occurs check fails.

=head2 bind_variable

Binds a variable to a term, checking that the variable does not occur inside
the term (occurs check).

=head2 occurs_in

Helper function. Returns true if the variable ID occurs inside the dereferenced term.

=cut

our @EXPORT_OK = qw(unify);
use parent 'Exporter';

sub unify ( $left, $right, $subst ) {
    $left  = $subst->walk($left);
    $right = $subst->walk($right);

    if ( ref($left) eq 'Logic::Relational::Variable' ) {
        return bind_variable( $left, $right, $subst );
    }

    if ( ref($right) eq 'Logic::Relational::Variable' ) {
        return bind_variable( $right, $left, $subst );
    }

    # Constants
    my $is_const_l = !ref($left)  || ref($left) eq 'Logic::Relational::Atom';
    my $is_const_r = !ref($right) || ref($right) eq 'Logic::Relational::Atom';

    if ( $is_const_l && $is_const_r ) {
        my $val_l = ref($left) ? $left->value : $left;
        my $val_r = ref($right) ? $right->value : $right;
        return $val_l eq $val_r ? $subst : undef;
    }

    # Compound terms
    if (   ref($left) eq 'Logic::Relational::Term'
        && ref($right) eq 'Logic::Relational::Term' )
    {
        return undef
          unless $left->functor eq $right->functor
          && $left->arity == $right->arity;

        for my $i ( 0 .. $left->arity - 1 ) {
            $subst = unify( $left->arg($i), $right->arg($i), $subst );
            return undef unless $subst;
        }
        return $subst;
    }

    if ( ref($left) eq 'ARRAY' && ref($right) eq 'ARRAY' ) {
        return unify_arrays( $left, $right, $subst );
    }

    if ( ref($left) eq 'HASH' && ref($right) eq 'HASH' ) {
        return unify_hashes( $left, $right, $subst );
    }

    return undef;
}

sub unify_hashes ( $left, $right, $subst ) {    ## no critic (ProhibitExcessComplexity)
    my @slurp_keys_l =
      grep { ref( $left->{$_} ) eq 'Logic::Relational::ArrayRest' }
      keys %$left;
    my @slurp_keys_r =
      grep { ref( $right->{$_} ) eq 'Logic::Relational::ArrayRest' }
      keys %$right;

    if ( scalar @slurp_keys_l > 1 || scalar @slurp_keys_r > 1 ) {
        croak
          "Only one slurp/rest value is allowed in a hash reference pattern";
    }

    my $slurp_k_l = $slurp_keys_l[0];
    my $slurp_k_r = $slurp_keys_r[0];

    if ( defined $slurp_k_l && defined $slurp_k_r ) {
        my %std_keys_l = map { $_ => 1 } grep { $_ ne $slurp_k_l } keys %$left;
        my %std_keys_r = map { $_ => 1 } grep { $_ ne $slurp_k_r } keys %$right;

        for my $k ( keys %std_keys_l ) {
            return undef unless exists $right->{$k};
            $subst = unify( $left->{$k}, $right->{$k}, $subst );
            return undef unless $subst;
        }
        for my $k ( keys %std_keys_r ) {
            return undef unless exists $left->{$k};
        }

        return unify( $left->{$slurp_k_l}->term, $right->{$slurp_k_r}->term,
            $subst );
    }
    elsif ( defined $slurp_k_l ) {
        my %std_keys_l = map { $_ => 1 } grep { $_ ne $slurp_k_l } keys %$left;

        for my $k ( keys %std_keys_l ) {
            return undef unless exists $right->{$k};
            $subst = unify( $left->{$k}, $right->{$k}, $subst );
            return undef unless $subst;
        }

        my %remainder =
          map { $_ => $right->{$_} }
          grep { !exists $std_keys_l{$_} } keys %$right;
        return unify( $left->{$slurp_k_l}->term, \%remainder, $subst );
    }
    elsif ( defined $slurp_k_r ) {
        my %std_keys_r = map { $_ => 1 } grep { $_ ne $slurp_k_r } keys %$right;

        for my $k ( keys %std_keys_r ) {
            return undef unless exists $left->{$k};
            $subst = unify( $left->{$k}, $right->{$k}, $subst );
            return undef unless $subst;
        }

        my %remainder =
          map { $_ => $left->{$_} }
          grep { !exists $std_keys_r{$_} } keys %$left;
        return unify( \%remainder, $right->{$slurp_k_r}->term, $subst );
    }
    else {
        return undef unless scalar keys %$left == scalar keys %$right;
        for my $k ( keys %$left ) {
            return undef unless exists $right->{$k};
            $subst = unify( $left->{$k}, $right->{$k}, $subst );
            return undef unless $subst;
        }
        return $subst;
    }
}

sub unify_arrays ( $left, $right, $subst ) {
    my $M = scalar @$left;
    my $N = scalar @$right;

    my $i = 0;
    while ( $i < $M || $i < $N ) {
        my $has_rest_l =
          ( $i < $M && ref( $left->[$i] ) eq 'Logic::Relational::ArrayRest' );
        my $has_rest_r =
          ( $i < $N && ref( $right->[$i] ) eq 'Logic::Relational::ArrayRest' );

        if ( $has_rest_l && $has_rest_r ) {
            croak "rest/slurp must be the last element of an array"
              unless $i == $M - 1 && $i == $N - 1;
            return unify( $left->[$i]->term, $right->[$i]->term, $subst );
        }
        elsif ($has_rest_l) {
            croak "rest/slurp must be the last element of an array"
              unless $i == $M - 1;
            my $remainder = [ @{$right}[ $i .. $#$right ] ];
            return unify( $left->[$i]->term, $remainder, $subst );
        }
        elsif ($has_rest_r) {
            croak "rest/slurp must be the last element of an array"
              unless $i == $N - 1;
            my $remainder = [ @{$left}[ $i .. $#$left ] ];
            return unify( $remainder, $right->[$i]->term, $subst );
        }

        if ( $i >= $M || $i >= $N ) {
            return undef;
        }

        $subst = unify( $left->[$i], $right->[$i], $subst );
        return undef unless $subst;
        $i++;
    }
    return $subst;
}

sub bind_variable ( $var, $val, $subst ) {    ## no critic (ProhibitExcessComplexity)
    if ( ref($val) eq 'Logic::Relational::Variable' && $var->id == $val->id ) {
        return $subst;
    }

    if ( occurs_in( $var->id, $val, $subst ) ) {
        my $var_str = $var->as_string;
        my $val_str = blessed($val)
          && $val->can('as_string') ? $val->as_string : "$val";
        croak "Occurs check failed: cannot bind $var_str to $val_str\n";
    }

    my $d_var     = $subst->{bindings}{ $var->id };
    my $has_d_var = ( ref($d_var) eq 'Logic::Relational::Domain' );

    if ( ref($val) eq 'Logic::Relational::Variable' ) {
        my $d_val     = $subst->{bindings}{ $val->id };
        my $has_d_val = ( ref($d_val) eq 'Logic::Relational::Domain' );

        if ( $has_d_var && $has_d_val ) {
            my $d_new = $d_var->intersect($d_val);
            return unless $d_new;
            if ( $d_new->is_bound ) {
                my $v = $d_new->bound_value;
                return $subst->bind( $var->id, $v )->bind( $val->id, $v );
            }
            return $subst->bind( $var->id, $val )->bind( $val->id, $d_new );
        }
        elsif ($has_d_var) {
            return $subst->bind( $val->id, $var );
        }
        elsif ($has_d_val) {
            return $subst->bind( $var->id, $val );
        }
        else {
            return $subst->bind( $var->id, $val );
        }
    }
    elsif ( ref($val) eq 'Logic::Relational::Domain' ) {
        if ($has_d_var) {
            my $d_new = $d_var->intersect($val);
            return unless $d_new;
            if ( $d_new->is_bound ) {
                return $subst->bind( $var->id, $d_new->bound_value );
            }
            return $subst->bind( $var->id, $d_new );
        }
        else {
            if ( $val->is_bound ) {
                return $subst->bind( $var->id, $val->bound_value );
            }
            return $subst->bind( $var->id, $val );
        }
    }
    else {
        if ($has_d_var) {
            return unless $val =~ /^-?\d+$/x;
            return unless $d_var->contains($val);
            return $subst->bind( $var->id, $val );
        }
        else {
            return $subst->bind( $var->id, $val );
        }
    }
}

sub occurs_in ( $var_id, $term, $subst ) {
    $term = $subst->walk($term);
    if ( ref($term) eq 'Logic::Relational::Variable' ) {    ## no critic (ProhibitCascadingIfElse)
        return $term->id == $var_id;
    }
    elsif ( ref($term) eq 'Logic::Relational::Term' ) {
        for my $arg ( @{ $term->args } ) {
            return 1 if occurs_in( $var_id, $arg, $subst );
        }
    }
    elsif ( ref($term) eq 'ARRAY' ) {
        for my $arg (@$term) {
            return 1 if occurs_in( $var_id, $arg, $subst );
        }
    }
    elsif ( ref($term) eq 'Logic::Relational::ArrayRest' ) {
        return occurs_in( $var_id, $term->term, $subst );
    }
    elsif ( ref($term) eq 'HASH' ) {
        for my $val ( values %$term ) {
            return 1 if occurs_in( $var_id, $val, $subst );
        }
    }
    return 0;
}

1;
