package Logic::Relational::Atom;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::Atom - Represents a symbolic constant (atom) in the logic engine.

=head1 SYNOPSIS

    use Logic::Relational::Atom;
    my $atom = Logic::Relational::Atom->new('gold');
    say $atom->value; # gold

=head1 DESCRIPTION

C<Logic::Relational::Atom> represents a symbolic constant/atom in the relational
logic engine. These are immutable constants and are used in structural unification.

=head1 METHODS

=head2 new

Constructor. Takes a single scalar value.

=head2 value

Returns the raw scalar value.

=head2 as_string

Returns the string representation of the atom.

=head2 freshen

Returns the atom itself (since constants do not contain variables).

=cut

sub new ( $class, $value ) {
    return bless { value => $value }, $class;
}

sub value ($self) {
    return $self->{value};
}

sub as_string ($self) {
    return $self->{value};
}

sub freshen ( $self, $var_map ) {
    return $self;
}

1;
