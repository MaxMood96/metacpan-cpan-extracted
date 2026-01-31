package Data::Gimei::Random;

# Pseudo random number generator(PRNG)
# Park & Miller comp.lang.c FAQ list Question 13.15

use 5.010;
use strict;
use warnings;

use Class::Tiny qw (
  seed
);

#
# Class methods
#

sub BUILDARGS {
    my ( $class, @args ) = @_;

    # Handle single argument as seed
    if ( @args == 1 ) {
        return { seed => $args[0] };
    }

    my %args = @args;
    $args{'seed'} //= time();

    return \%args;
}

#
# Instance methods
#

sub set_seed {
    my ( $self, $seed ) = @_;
    $self->seed($seed);
}

sub next_int {
    my ( $self, $size ) = @_;

    my $rnum = ( 48_271 * $self->seed ) % ( 2 << 31 - 1 );
    $self->seed($rnum);

    return $rnum % $size;
}

sub sample {
    my ( $self, $aref ) = @_;

    my $index = $self->next_int( $#$aref + 1 );

    return $aref->[$index];
}
1;
