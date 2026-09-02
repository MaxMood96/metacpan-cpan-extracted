package Logic::Relational::Goal::CellAt;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';
use Logic::Relational::Unifier qw(unify);

=head1 NAME

Logic::Relational::Goal::CellAt - Goal that binds the value of an array element at a ground index.

=cut

sub new ( $class, $board, $index, $value ) {
    return bless { board => $board, index => $index, value => $value }, $class;
}

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    my $board_val = $subst->walk( $self->{board} );
    my $idx_val   = $subst->walk( $self->{index} );

    # Ensure they are ground
    return () if ref($board_val) ne 'ARRAY' || ref($idx_val) ne '';

    my $cell      = $board_val->[$idx_val];
    my $new_subst = unify( $self->{value}, $cell, $subst );
    if ($new_subst) {
        my $succ = $state->derive(
            substitution => $new_subst,
            goals        => $remaining,
        );
        return $succ // ();
    }
    return ();
}

sub freshen ( $self, $var_map ) {
    require Logic::Relational::DSL;
    return ref($self)->new(
        Logic::Relational::DSL::freshen_val( $self->{board}, $var_map ),
        Logic::Relational::DSL::freshen_val( $self->{index}, $var_map ),
        Logic::Relational::DSL::freshen_val( $self->{value}, $var_map )
    );
}

sub is_ground ( $self, $subst ) {
    return
         $self->term_is_ground( $self->{board}, $subst )
      && $self->term_is_ground( $self->{index}, $subst )
      && $self->term_is_ground( $self->{value}, $subst );
}

1;
