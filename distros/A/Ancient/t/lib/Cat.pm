package Cat;
use strict;
use warnings;
use parent 'Animal';
use slot qw(indoor lives_remaining);

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args, species => 'cat');
    indoor($args{indoor} // 1);
    lives_remaining($args{lives_remaining} // 9);
    return $self;
}

sub meow {
    return "Meow! I am " . main::name();
}

sub lose_life {
    my $remaining = lives_remaining();
    if ($remaining > 0) {
        lives_remaining($remaining - 1);
        return lives_remaining();
    }
    return 0;
}

1;
