package My::Class::C8;

use Moo;
extends 'My::Class::B3';

with 'My::Class::R1';
with 'My::Class::R2';

use namespace::clean;

has c8_1 => (
    is      => 'ro',
    default => 'c8_1.v',
    T1_1    => 'should not stick',
    T2_1    => 'should not stick',
);

1;
