#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch', 't/lib';

use_ok('Animal');

# Test Animal class
my $animal = Animal->new(name => 'Generic', age => 5, species => 'mammal');
isa_ok($animal, 'Animal');

is(Animal::name(), 'Generic', 'Animal name slot works');
is(Animal::age(), 5, 'Animal age slot works');
is(Animal::species(), 'mammal', 'Animal species slot works');

like($animal->describe(), qr/Generic is a 5 year old mammal/, 'describe method works');

# Test modifying slots
Animal::name('Changed');
is(Animal::name(), 'Changed', 'modifying slot works');

done_testing();
