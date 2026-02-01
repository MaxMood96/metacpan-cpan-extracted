#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use object;

object::define('Animal', qw(name));
object::define('Dog', qw(name breed));

# Create prototype
my $proto = new Animal 'Generic';

# Create object with prototype
my $dog = new Dog 'Rex', 'German Shepherd';
object::set_prototype($dog, $proto);

# Test prototype access
my $p = object::prototype($dog);
isa_ok($p, 'Animal', 'prototype returns Animal');
is($p->name, 'Generic', 'prototype name accessible');

# Test lock
object::lock($dog);
ok(object::is_locked($dog), 'is_locked returns true after lock');

# Test unlock
object::unlock($dog);
ok(!object::is_locked($dog), 'is_locked returns false after unlock');

# Test freeze
object::freeze($dog);
ok(object::is_frozen($dog), 'is_frozen returns true after freeze');
ok(object::is_locked($dog), 'frozen object is also locked');

# Cannot unlock frozen
eval { object::unlock($dog) };
like($@, qr/Cannot unlock frozen/, 'cannot unlock frozen object');

# Cannot modify frozen
eval { $dog->name('NewName') };
like($@, qr/Cannot modify frozen/, 'cannot modify frozen object');

done_testing;
