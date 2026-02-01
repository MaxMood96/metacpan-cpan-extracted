package DoubleCounter;
use strict;
use warnings;
use parent 'Counter';
use slot qw(multiplier);

sub new {
    my ($class, $mult) = @_;
    my $self = $class->SUPER::new();
    multiplier($mult // 2);
    return $self;
}

sub increment {
    my $self = shift;
    my $mult = multiplier();
    for (1..$mult) {
        $self->SUPER::increment();
    }
    return Counter::count();
}

1;
