package Logic::Relational::ArrayRest;

use v5.38;
use experimental 'signatures';
use Carp qw(croak);

=head1 NAME

Logic::Relational::ArrayRest - Represents a rest/slurp wrapper for array unification.

=head1 SYNOPSIS

    use Logic::Relational::ArrayRest;
    my $rest = Logic::Relational::ArrayRest->new($variable);

=head1 DESCRIPTION

C<Logic::Relational::ArrayRest> wraps a term to represent the rest of an array
in unification. It is constructed using the C<rest> or C<slurp> DSL helpers.

=head1 METHODS

=head2 new

Constructor. Takes a single term (usually a variable).

=head2 term

Returns the wrapped term.

=head2 as_string

Returns the string representation of the wrapper.

=head2 freshen

Freshens the inner term, returning a new C<Logic::Relational::ArrayRest> object.

=cut

sub new ( $class, $term ) {
    return bless { term => $term }, $class;
}

sub term ($self) {
    return $self->{term};
}

use builtin 'blessed';
no warnings 'experimental::builtin';

sub as_string ($self) {
    my $term = $self->{term};
    my $term_str =
      blessed($term) && $term->can('as_string') ? $term->as_string : "$term";
    return "rest($term_str)";
}

sub freshen ( $self, $var_map ) {
    my $term = $self->{term};
    my $fresh_term =
      blessed($term) && $term->can('freshen') ? $term->freshen($var_map) : $term;
    return ref($self)->new($fresh_term);
}

1;
