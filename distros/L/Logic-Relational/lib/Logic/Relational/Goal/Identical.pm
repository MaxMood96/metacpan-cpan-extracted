package Logic::Relational::Goal::Identical;

use v5.38;
## no critic (Subroutines::ProhibitExcessComplexity)
use experimental 'signatures';
use parent 'Logic::Relational::Goal';
use builtin 'blessed';
no warnings 'experimental::builtin';

=head1 NAME

Logic::Relational::Goal::Identical - Evaluates strict term identity without variable binding.

=cut

sub new ( $class, $left, $right ) {
    return bless {
        left  => $left,
        right => $right,
    }, $class;
}

sub left  ($self) { return $self->{left}; }
sub right ($self) { return $self->{right}; }

sub _are_identical ( $t1, $t2 ) {
    return 1 if !defined($t1) && !defined($t2);
    return 0 if !defined($t1) || !defined($t2);

    # Variables: compare ID
    if ( blessed($t1) && $t1->isa('Logic::Relational::Variable') ) {
        return ( blessed($t2)
              && $t2->isa('Logic::Relational::Variable')
              && $t1->id eq $t2->id ) ? 1 : 0;
    }
    if ( blessed($t2) && $t2->isa('Logic::Relational::Variable') ) {
        return 0;
    }

    # Atoms: compare name
    if ( blessed($t1) && $t1->isa('Logic::Relational::Atom') ) {
        return ( blessed($t2)
              && $t2->isa('Logic::Relational::Atom')
              && $t1->name eq $t2->name ) ? 1 : 0;
    }
    if ( blessed($t2) && $t2->isa('Logic::Relational::Atom') ) {
        return 0;
    }

    # Terms: compare functor and args
    if ( blessed($t1) && $t1->isa('Logic::Relational::Term') ) {
        return 0
          unless blessed($t2)
          && $t2->isa('Logic::Relational::Term')
          && $t1->functor eq $t2->functor
          && @{ $t1->args } == @{ $t2->args };

        for my $i ( 0 .. $#{ $t1->args } ) {
            return 0
              unless _are_identical( $t1->args->[$i], $t2->args->[$i] );
        }
        return 1;
    }
    if ( blessed($t2) && $t2->isa('Logic::Relational::Term') ) {
        return 0;
    }

    # Arrays
    if ( ref($t1) eq 'ARRAY' ) {
        return 0 unless ref($t2) eq 'ARRAY' && @$t1 == @$t2;
        for my $i ( 0 .. $#$t1 ) {
            return 0 unless _are_identical( $t1->[$i], $t2->[$i] );
        }
        return 1;
    }

    # Hashes
    if ( ref($t1) eq 'HASH' ) {
        return 0 unless ref($t2) eq 'HASH';
        my @k1 = sort keys %$t1;
        my @k2 = sort keys %$t2;
        return 0 unless @k1 == @k2;
        for my $i ( 0 .. $#k1 ) {
            return 0 unless $k1[$i] eq $k2[$i];
            return 0
              unless _are_identical( $t1->{ $k1[$i] }, $t2->{ $k2[$i] } );
        }
        return 1;
    }

    # Plain scalar comparison
    return $t1 eq $t2 ? 1 : 0;
}

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    my $walked_left  = $subst->walk( $self->{left} );
    my $walked_right = $subst->walk( $self->{right} );

    if ( _are_identical( $walked_left, $walked_right ) ) {
        my $succ = $state->derive( goals => $remaining, );
        return $succ // ();
    }
    return ();
}

sub freshen ( $self, $var_map ) {
    my $fresh_left =
      blessed( $self->{left} )
      && $self->{left}->can('freshen')
      ? $self->{left}->freshen($var_map)
      : $self->{left};

    my $fresh_right =
      blessed( $self->{right} )
      && $self->{right}->can('freshen')
      ? $self->{right}->freshen($var_map)
      : $self->{right};

    return ref($self)->new( $fresh_left, $fresh_right );
}

sub is_ground ( $self, $subst ) {
    return $self->term_is_ground( $self->{left}, $subst )
      && $self->term_is_ground( $self->{right}, $subst );
}

1;
