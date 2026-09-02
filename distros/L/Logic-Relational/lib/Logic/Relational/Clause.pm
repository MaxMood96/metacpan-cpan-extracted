package Logic::Relational::Clause;

use v5.38;
use experimental 'signatures';

=head1 NAME

Logic::Relational::Clause - Represents a logic clause (fact or rule).

=head1 SYNOPSIS

    use Logic::Relational::Clause;
    my $clause = Logic::Relational::Clause->new(
        head => $head_term,
        body => $body_goal,
    );

=head1 DESCRIPTION

C<Logic::Relational::Clause> represents a logical clause. A fact is a clause
with no body goals (or rather, the body defaults to C<True>). A rule contains
a body C<Goal> that must be satisfied for the clause head to hold.

=head1 METHODS

=head2 new

Constructor. Takes C<head> (Term), C<body> (Goal, optional), C<id> (string, optional),
and C<metadata> (hashref, optional).

=head2 id

Returns the unique ID of the clause (e.g. C<clause-1>).

=head2 head

Returns the head term of the clause.

=head2 body

Returns the body goal of the clause.

=head2 metadata

Returns the metadata associated with the clause.

=head2 freshen

Returns a fresh copy of the clause where all its logical variables are mapped
to newly generated variables, preserving variable sharing within the clause.

=cut

use Carp qw(croak);

sub new ( $class, %args ) {
    my $head = $args{head} // croak "head term is required";

# We will import True goal dynamically or assume it is loaded to avoid circular dependency
    my $body = $args{body};
    if ( !$body ) {
        require Logic::Relational::Goal::True;
        $body = Logic::Relational::Goal::True->new;
    }
    my $self = {
        id       => $args{id},
        head     => $head,
        body     => $body,
        metadata => $args{metadata} // {},
    };
    return bless $self, $class;
}

sub id ($self) {
    return $self->{id};
}

sub head ($self) {
    return $self->{head};
}

sub body ($self) {
    return $self->{body};
}

sub metadata ($self) {
    return $self->{metadata};
}

sub freshen ($self) {
    my $var_map    = {};
    my $fresh_head = $self->{head}->freshen($var_map);
    my $fresh_body = $self->{body}->freshen($var_map);
    return ref($self)->new(
        id       => $self->{id},
        head     => $fresh_head,
        body     => $fresh_body,
        metadata => $self->{metadata},
    );
}

1;
