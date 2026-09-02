package Logic::Relational::Goal::Guard;

use v5.38;
use experimental 'signatures';
use parent 'Logic::Relational::Goal';

=head1 NAME

Logic::Relational::Goal::Guard - Evaluates a deterministic Perl test block.

=cut

sub new ( $class, $vars, $code ) {
    return bless { vars => $vars, code => $code }, $class;
}

sub vars ($self) { return $self->{vars}; }
sub code ($self) { return $self->{code}; }

sub expand ( $self, %args ) {
    my $subst     = $args{substitution};
    my $remaining = $args{remaining};
    my $state     = $args{state};

    # Verify all referenced variables are ground
    for my $var ( @{ $self->{vars} } ) {
        my $walked = $subst->walk($var);
        if ( ref($walked) eq 'Logic::Relational::Variable' ) {
            die "Guard attempted to read unbound logical variable \$"
              . $var->name . "\n";
        }
    }

    # Reify values
    my @vals = map { $subst->reify($_) } @{ $self->{vars} };

    # Run the user code block
    my $ok = $self->{code}->(@vals);

    if ($ok) {
        my $succ = $state->derive( goals => $remaining, );
        return $succ // ();
    }
    return ();
}

sub freshen ( $self, $var_map ) {
    my @fresh_vars = map { $_->freshen($var_map) } @{ $self->{vars} };
    return ref($self)->new( \@fresh_vars, $self->{code} );
}

sub is_ground ( $self, $subst ) {
    for my $var ( @{ $self->{vars} } ) {
        return 0 unless $self->term_is_ground( $var, $subst );
    }
    return 1;
}

1;
