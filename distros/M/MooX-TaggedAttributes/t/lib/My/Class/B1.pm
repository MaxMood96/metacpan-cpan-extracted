package My::Class::B1;

use Moo;

use namespace::clean;

use My::Class::T1;

has b1_1 => (
    is      => 'rw',
    default => 'b1_1.v',
    T1_1    => 'b1_1.t1_1',
);

1;
