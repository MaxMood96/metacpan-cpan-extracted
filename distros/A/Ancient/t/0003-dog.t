#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch', 't/lib';

use_ok('Animal');
use_ok('Dog');

# Test Dog inherits from Animal
my $dog = Dog->new(name => 'Buddy', age => 3, breed => 'Labrador');
isa_ok($dog, 'Dog');
isa_ok($dog, 'Animal');

# Test inherited slots (accessed via Animal namespace since that's where they're imported)
is(Animal::name(), 'Buddy', 'inherited name slot works');
is(Animal::age(), 3, 'inherited age slot works');
is(Animal::species(), 'dog', 'species set by Dog constructor');

# Test Dog-specific slots
is(Dog::breed(), 'Labrador', 'Dog breed slot works');
is(Dog::is_good_boy(), 1, 'is_good_boy defaults to true');

# Test describe with inheritance
like($dog->describe(), qr/Buddy is a 3 year old dog.*Labrador/, 'Dog describe includes breed');

# Test modifying Dog-specific slot
Dog::breed('Golden Retriever');
is(Dog::breed(), 'Golden Retriever', 'modifying Dog slot works');

done_testing();
