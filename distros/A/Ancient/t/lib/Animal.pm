package Animal;
use strict;
use warnings;
use slot qw(name age species);

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    name($args{name}) if exists $args{name};
    age($args{age}) if exists $args{age};
    species($args{species}) if exists $args{species};
    return $self;
}

sub describe {
    my $self = shift;
    return sprintf("%s is a %d year old %s", name() // 'Unknown', age() // 0, species() // 'animal');
}

1;
