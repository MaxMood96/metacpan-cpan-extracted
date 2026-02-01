#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use slot;

# Test slot::slots() returns all defined slots
my @slots_before = slot::slots();

# Import some slots
package TestPkg1;
use slot qw(foo bar);

package TestPkg2;
use slot qw(baz foo);  # foo already exists, should reuse

package main;

my @slots_after = slot::slots();
my %slot_hash = map { $_ => 1 } @slots_after;

ok(exists $slot_hash{foo}, 'foo slot exists');
ok(exists $slot_hash{bar}, 'bar slot exists');
ok(exists $slot_hash{baz}, 'baz slot exists');

# Test slot::get and slot::set
TestPkg1::foo(42);
is(slot::get('foo'), 42, 'slot::get works');

slot::set('foo', 100);
is(TestPkg1::foo(), 100, 'slot::set works');
is(TestPkg2::foo(), 100, 'same slot shared between packages');

done_testing();
