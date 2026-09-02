package Logic::Relational::Goal::GeneratorStep;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';
use Carp qw(croak);

=head1 NAME

Logic::Relational::Goal::GeneratorStep - Represents a lazy step in a generator.

=cut

sub new ( $class, %args ) {
    my $iterator  = $args{iterator}  // croak "iterator is required";
    my $call_args = $args{call_args} // croak "call_args is required";
    my $key       = $args{key}       // croak "key is required";
    my $arity     = $args{arity}     // croak "arity is required";

    return bless {
        iterator  => $iterator,
        call_args => $call_args,
        key       => $key,
        arity     => $arity,
    }, $class;
}

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};

    my $iterator  = $self->{iterator};
    my $call_args = $self->{call_args};
    my $key       = $self->{key};
    my $arity     = $self->{arity};

    require Logic::Relational::Unifier;
    require Logic::Relational::State;

    while ( my $candidate = $iterator->() ) {
        croak "Iterator for $key must yield an array reference of values"
          unless ref($candidate) eq 'ARRAY';
        croak sprintf( "Iterator for %s yielded %d values, but arity is %d",
            $key, scalar(@$candidate), $arity )
          unless scalar(@$candidate) == $arity;

        my $new_subst = $subst;
        my $ok        = 1;
        for my $i ( 0 .. $arity - 1 ) {
            $new_subst =
              Logic::Relational::Unifier::unify( $call_args->[$i],
                $candidate->[$i], $new_subst );
            if ( !$new_subst ) {
                $ok = 0;
                last;
            }
        }

        if ($ok) {
            require Logic::Relational::Goal::True;
            my $succ = $args{state}->derive(
                substitution => $new_subst,
                goals => [ Logic::Relational::Goal::True->new, @$remaining ],
            );

            my $backtrack = $args{state}->derive(
                substitution => $subst,
                goals        => [ $self, @$remaining ],
            );

            my @res;
            push @res, $succ      if $succ;
            push @res, $backtrack if $backtrack;
            return @res;
        }
    }

    return ();
}

sub freshen ( $self, $var_map ) {
    return $self;
}

sub is_ground ( $self, $subst ) {
    for my $arg ( @{ $self->{call_args} } ) {
        return 0 unless $self->term_is_ground( $arg, $subst );
    }
    return 1;
}

sub as_string ($self) {
    return "generator_step(" . $self->{key} . ")";
}

1;
