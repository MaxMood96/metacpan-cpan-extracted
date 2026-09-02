package Logic::Relational::Goal::All;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';

=head1 NAME

Logic::Relational::Goal::All - Conjunction of goals (AND).

=cut

sub new ( $class, $goals ) {
    return bless { goals => $goals }, $class;
}

sub goals ($self) { return $self->{goals}; }

sub expand ( $self, %args ) {
    my $state     = $args{state};
    my $remaining = $args{remaining};
    my $succ = $state->derive( goals => [ @{ $self->{goals} }, @$remaining ], );
    return $succ // ();
}

sub freshen ( $self, $var_map ) {
    my @fresh_goals = map { $_->freshen($var_map) } @{ $self->{goals} };
    return ref($self)->new( \@fresh_goals );
}

sub is_ground ( $self, $subst ) {
    for my $goal ( @{ $self->{goals} } ) {
        return 0 unless $goal->is_ground($subst);
    }
    return 1;
}

1;
