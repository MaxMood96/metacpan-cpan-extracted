package FastAnimal;
use strict;
use warnings;
use object;

# Define class at compile time
BEGIN {
    object::define('FastAnimal', qw(name age species));
}

sub speak { 
    my $self = shift; 
    return "I am " . $self->name; 
}

1;
