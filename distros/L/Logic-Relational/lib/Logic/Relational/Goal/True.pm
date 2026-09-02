package Logic::Relational::Goal::True;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';

=head1 NAME

Logic::Relational::Goal::True - Goal that always succeeds.

=cut

sub new ($class) {
    return bless {}, $class;
}

sub expand ( $self, %args ) {
    my $state     = $args{state};
    my $remaining = $args{remaining};
    my $succ      = $state->derive( goals => $remaining, );
    return $succ // ();
}

sub freshen ( $self, $var_map ) {
    return $self;
}

sub is_ground ( $self, $subst ) {
    return 1;
}

1;
