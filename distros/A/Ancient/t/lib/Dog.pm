package Dog;
use strict;
use warnings;
use parent 'Animal';
use slot qw(breed is_good_boy);

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args, species => 'dog');
    breed($args{breed}) if exists $args{breed};
    is_good_boy($args{is_good_boy} // 1);  # All dogs are good boys by default
    return $self;
}

sub bark {
    return "Woof! My name is " . main::name();
}

sub describe {
    my $self = shift;
    my $base = $self->SUPER::describe();
    return $base . " (" . (breed() // 'mixed') . " breed)";
}

1;
