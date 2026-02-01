#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Test slot module functions work correctly in map/grep/for context
# Ensures call checkers properly handle $_ usage

use slot qw(test_slot1 test_slot2 test_slot3);

# Initialize slots
test_slot1(100);
test_slot2(200);
test_slot3(300);

# ============================================
# Slot access in map
# ============================================
subtest 'slot getters in map' => sub {
    # Create slots with different values
    my @slot_names = qw(test_slot1 test_slot2 test_slot3);
    
    # Get values - need to call by name
    my @values = (test_slot1(), test_slot2(), test_slot3());
    is_deeply(\@values, [100, 200, 300], 'slot getters return correct values');
};

# ============================================
# Slot setters in for loop
# ============================================
subtest 'slot setters in for loop' => sub {
    my @new_values = (10, 20, 30);
    
    test_slot1($new_values[0]);
    test_slot2($new_values[1]);
    test_slot3($new_values[2]);
    
    is(test_slot1(), 10, 'slot1 updated');
    is(test_slot2(), 20, 'slot2 updated');
    is(test_slot3(), 30, 'slot3 updated');
};

# ============================================
# Slots with map transformation
# ============================================
subtest 'slots with map transformation' => sub {
    test_slot1(5);
    test_slot2(10);
    test_slot3(15);
    
    my @slots_doubled = map { $_ * 2 } (test_slot1(), test_slot2(), test_slot3());
    is_deeply(\@slots_doubled, [10, 20, 30], 'slot values doubled in map');
};

# ============================================
# Slots with grep filter
# ============================================
subtest 'slots with grep filter' => sub {
    test_slot1(5);
    test_slot2(10);
    test_slot3(15);
    
    my @big_values = grep { $_ > 8 } (test_slot1(), test_slot2(), test_slot3());
    is_deeply(\@big_values, [10, 15], 'grep filters slot values');
};

# ============================================
# Slot in conditional
# ============================================
subtest 'slots in conditional' => sub {
    test_slot1(0);
    test_slot2(42);
    
    my $result = test_slot1() ? 'truthy' : 'falsy';
    is($result, 'falsy', 'falsy slot value');
    
    $result = test_slot2() ? 'truthy' : 'falsy';
    is($result, 'truthy', 'truthy slot value');
};

# ============================================
# Nested slot operations
# ============================================
subtest 'nested slot operations' => sub {
    test_slot1(100);
    
    # Set slot2 based on slot1
    test_slot2(test_slot1() + 50);
    is(test_slot2(), 150, 'slot2 computed from slot1');
    
    # Set slot3 based on both
    test_slot3(test_slot1() + test_slot2());
    is(test_slot3(), 250, 'slot3 computed from both');
};

done_testing();
