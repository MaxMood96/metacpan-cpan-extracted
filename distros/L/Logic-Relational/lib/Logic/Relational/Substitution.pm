package Logic::Relational::Substitution;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::Substitution - Represents an immutable variable substitution mapping.

=head1 SYNOPSIS

    use Logic::Relational::Substitution;
    my $subst = Logic::Relational::Substitution->new;
    my $new_subst = $subst->bind($var_id => $val);

=head1 DESCRIPTION

C<Logic::Relational::Substitution> stores logical variable bindings. It is
immutable (copy-on-write) to make depth-first backtracking search simple and
robust without needing manual rollbacks of variables.

=head1 METHODS

=head2 new

Constructor. Optionally takes a hash reference of initial bindings.

=head2 bind

Takes a variable ID and a value, returning a new C<Logic::Relational::Substitution>
object containing the new binding.

=head2 walk

Dereferences a term through the substitution. If the term is a variable and is bound,
recursively dereferences until it hits an unbound variable or a non-variable term.

=head2 reify

Recursively walks a term, replacing all bound variables within compound terms
with their bound values. Unbound variables remain unchanged.

=cut

sub new ( $class, $bindings = {} ) {
    return bless { bindings => $bindings }, $class;
}

sub bind ( $self, $var_id, $val ) {
    my $new_bindings = { %{ $self->{bindings} }, $var_id => $val };
    return ref($self)->new($new_bindings);
}

sub walk ( $self, $term ) {
    while ( ref($term) eq 'Logic::Relational::Variable' ) {
        my $id = $term->id;
        if ( exists $self->{bindings}{$id} ) {
            my $bound = $self->{bindings}{$id};
            if ( ref($bound) eq 'Logic::Relational::Domain' ) {
                last;
            }
            $term = $bound;
        }
        else {
            last;
        }
    }
    return $term;
}

sub reify ( $self, $term ) {
    $term = $self->walk($term);
    if ( ref($term) eq 'Logic::Relational::Variable' ) {    ## no critic (ProhibitCascadingIfElse)
        return $term;
    }
    elsif ( ref($term) eq 'Logic::Relational::Term' ) {
        my @reified_args = map { $self->reify($_) } @{ $term->args };
        return ref($term)->new(
            functor => $term->functor,
            args    => \@reified_args,
        );
    }
    elsif ( ref($term) eq 'ARRAY' ) {
        my @flat;
        for my $elem (@$term) {
            my $r_elem = $self->reify($elem);
            if ( ref($r_elem) eq 'Logic::Relational::ArrayRest' ) {
                my $inner = $r_elem->term;
                if ( ref($inner) eq 'ARRAY' ) {
                    push @flat, @$inner;
                }
                else {
                    push @flat, $r_elem;
                }
            }
            else {
                push @flat, $r_elem;
            }
        }
        return \@flat;
    }
    elsif ( ref($term) eq 'Logic::Relational::ArrayRest' ) {
        return ref($term)->new( $self->reify( $term->term ) );
    }
    elsif ( ref($term) eq 'HASH' ) {
        my %flat;
        for my $k ( keys %$term ) {
            my $r_val = $self->reify( $term->{$k} );
            if ( ref($r_val) eq 'Logic::Relational::ArrayRest' ) {
                my $inner = $r_val->term;
                if ( ref($inner) eq 'HASH' ) {
                    for my $sub_k ( keys %$inner ) {
                        $flat{$sub_k} = $inner->{$sub_k};
                    }
                }
                else {
                    $flat{$k} = $r_val;
                }
            }
            else {
                $flat{$k} = $r_val;
            }
        }
        return \%flat;
    }
    else {
        return $term;
    }
}

1;
