package Logic::Relational::ChangeEvent;

use v5.38;
use experimental 'signatures';
use Carp qw(croak);

=head1 NAME

Logic::Relational::ChangeEvent - Event dispatched when logic program changes.

=head1 SYNOPSIS

    my $event = Logic::Relational::ChangeEvent->new(
        operation => 'assert',
        clause    => $clause
    );

=cut

sub new ( $class, %args ) {
    my $operation = $args{operation} // croak "operation is required";
    my $clause    = $args{clause}    // croak "clause is required";

    return bless {
        operation => $operation,
        clause    => $clause
    }, $class;
}

sub operation ($self) {
    return $self->{operation};
}

sub clause ($self) {
    return $self->{clause};
}

1;
