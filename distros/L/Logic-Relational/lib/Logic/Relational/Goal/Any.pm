package Logic::Relational::Goal::Any;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';

=head1 NAME

Logic::Relational::Goal::Any - Disjunction of goals (OR).

=cut

sub new ( $class, $goals ) {
    return bless { goals => $goals }, $class;
}

sub goals ($self) { return $self->{goals}; }

sub expand ( $self, %args ) {
    my $state     = $args{state};
    my $remaining = $args{remaining};
    my @successors;
    for my $goal ( @{ $self->{goals} } ) {
        my $succ = $state->derive( goals => [ $goal, @$remaining ], );
        push @successors, $succ if $succ;
    }
    return @successors;
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
