package Counter;
use strict;
use warnings;
use slot qw(count);

sub new {
    my $class = shift;
    count(0);
    return bless {}, $class;
}

sub increment {
    my $c = count();
    count($c + 1);
    return count();
}

sub decrement {
    my $c = count();
    count($c - 1);
    return count();
}

sub reset {
    count(0);
    return count();
}

1;
