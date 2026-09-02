package Logic::Relational::Goal::Fail;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';

=head1 NAME

Logic::Relational::Goal::Fail - Goal that always fails.

=cut

sub new ($class) {
    return bless {}, $class;
}

sub expand ( $self, %args ) {
    return ();
}

sub freshen ( $self, $var_map ) {
    return $self;
}

sub is_ground ( $self, $subst ) {
    return 1;
}

1;
