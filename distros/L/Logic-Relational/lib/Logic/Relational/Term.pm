package Logic::Relational::Term;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::Term - Represents a compound term in the logic engine.

=head1 SYNOPSIS

    use Logic::Relational::Term;
    my $term = Logic::Relational::Term->new(
        functor => 'owns',
        args    => [$perp, $stuff]
    );

=head1 DESCRIPTION

C<Logic::Relational::Term> represents a compound term containing a functor name
and an array of arguments. Arguments can be other terms, variables, or constants.

=head1 METHODS

=head2 new

Constructor. Takes C<functor> and C<args> (arrayref).

=head2 functor

Returns the functor string.

=head2 args

Returns the arrayref of arguments.

=head2 arity

Returns the number of arguments.

=head2 arg

Returns the argument at the specified 0-based index.

=head2 as_string

Returns a formatted string representation of the compound term, e.g. C<owns(X, gold)>.

=head2 freshen

Recursively freshens all variables in its arguments using the provided variable
mapping, returning a new C<Logic::Relational::Term> object.

=cut

use Carp qw(croak);

sub new ( $class, %args ) {
    my $functor = $args{functor} // croak "functor is required";
    my $args    = $args{args}    // [];
    return bless { functor => $functor, args => $args }, $class;
}

sub functor ($self) {
    return $self->{functor};
}

sub args ($self) {
    return $self->{args};
}

sub arity ($self) {
    return scalar @{ $self->{args} };
}

sub arg ( $self, $i ) {
    return $self->{args}[$i];
}

sub as_string ($self) {
    my $functor = $self->{functor};
    my $arity   = $self->arity;
    return $functor if $arity == 0;

    my @arg_strs = map { _val_to_string($_) } @{ $self->{args} };

    return "$functor(" . join( ', ', @arg_strs ) . ")";
}

sub freshen ( $self, $var_map ) {
    my @fresh_args = map { _freshen_val( $_, $var_map ) } @{ $self->{args} };

    return ref($self)->new(
        functor => $self->{functor},
        args    => \@fresh_args,
    );
}

use builtin 'blessed';
no warnings 'experimental::builtin';

sub _val_to_string ($val) {
    if ( ref($val) eq 'ARRAY' ) {
        return "[" . join( ', ', map { _val_to_string($_) } @$val ) . "]";
    }
    elsif ( ref($val) eq 'HASH' ) {
        my @pairs = map { "$_ => " . _val_to_string($val->{$_}) } sort keys %$val;
        return "{" . join(', ', @pairs) . "}";
    }
    elsif ( blessed($val) && $val->can('as_string') ) {
        return $val->as_string;
    }
    return "$val";
}

sub _freshen_val ( $val, $var_map ) {
    if ( ref($val) eq 'ARRAY' ) {    ## no critic (ProhibitCascadingIfElse)
        return [ map { _freshen_val( $_, $var_map ) } @$val ];
    }
    elsif ( ref($val) eq 'HASH' ) {
        my %fresh_hash;
        for my $k ( keys %$val ) {
            $fresh_hash{$k} = _freshen_val( $val->{$k}, $var_map );
        }
        return \%fresh_hash;
    }
    elsif ( ref($val) eq 'Logic::Relational::ArrayRest' ) {
        return ref($val)->new( _freshen_val( $val->term, $var_map ) );
    }
    elsif ( blessed($val) && $val->can('freshen') ) {
        return $val->freshen($var_map);
    }
    return $val;
}

1;
