package Logic::Relational::Variable;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::Variable - Represents a logical variable in the logic engine.

=head1 SYNOPSIS

    use Logic::Relational::Variable;
    my $var = Logic::Relational::Variable->new(name => 'X');
    say $var->id;   # unique integer ID
    say $var->name; # X

=head1 DESCRIPTION

C<Logic::Relational::Variable> represents a logical variable. Each variable
has a unique internal ID to distinguish it from other variables, even if they share
the same display name.

=head1 METHODS

=head2 new

Constructor. Takes C<name> (optional) and C<id> (optional). If C<id> is omitted,
a unique integer ID is allocated from a global counter.

=head2 id

Returns the unique integer ID.

=head2 name

Returns the display name of the variable.

=head2 as_string

Returns a string representation of the variable, formatting it with its name and ID.

=head2 freshen

Takes a variable mapping hash reference. If this variable's ID is not present
in the mapping, a new variable with the same name and a fresh ID is created
and stored in the mapping. Returns the mapped variable.

=cut

our $NEXT_ID = 1;

sub new ( $class, %args ) {
    my $id   = $args{id}   // $NEXT_ID++;
    my $name = $args{name} // "var_$id";
    return bless { id => $id, name => $name }, $class;
}

sub id ($self) {
    return $self->{id};
}

sub name ($self) {
    return $self->{name};
}

sub as_string ($self) {
    return "_" . $self->{name} . "_" . $self->{id};
}

sub freshen ( $self, $var_map ) {
    my $id = $self->{id};
    if ( !exists $var_map->{$id} ) {
        $var_map->{$id} = ref($self)->new( name => $self->{name} );
    }
    return $var_map->{$id};
}

1;
