package Logic::Relational::Solution;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::Solution - Represents a single solution from a logic query.

=head1 SYNOPSIS

    my $solution = $query->next;
    if ($solution) {
        say $solution->value($wanted_var);
    }

=head1 DESCRIPTION

C<Logic::Relational::Solution> provides access to the variable bindings of a
successful query execution.

=head1 METHODS

=head2 new

Constructor. Takes C<substitution>.

=head2 substitution

Returns the substitution object for this solution.

=head2 value

Takes a variable and returns its reified (fully instantiated) value in this solution.

=cut

use Carp qw(croak);

sub new ( $class, %args ) {
    my $subst = $args{substitution} // croak "substitution is required";
    return bless { substitution => $subst }, $class;
}

sub substitution ($self) {
    return $self->{substitution};
}

sub value ( $self, $var ) {
    return $self->{substitution}->reify($var);
}

1;
