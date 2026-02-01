#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch', 't/lib';

use_ok('Animal');
use_ok('Cat');

# Test Cat inherits from Animal
my $cat = Cat->new(name => 'Whiskers', age => 7);
isa_ok($cat, 'Cat');
isa_ok($cat, 'Animal');

# Test inherited slots
is(Animal::name(), 'Whiskers', 'inherited name slot works');
is(Animal::age(), 7, 'inherited age slot works');
is(Animal::species(), 'cat', 'species set by Cat constructor');

# Test Cat-specific slots
is(Cat::indoor(), 1, 'indoor defaults to true');
is(Cat::lives_remaining(), 9, 'lives_remaining defaults to 9');

# Test lose_life method with lvalue
$cat->lose_life();
is(Cat::lives_remaining(), 8, 'lose_life decrements lives');

$cat->lose_life();
$cat->lose_life();
is(Cat::lives_remaining(), 6, 'multiple lose_life calls work');

done_testing();
