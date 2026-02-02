#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

# Test slot edge cases

use slot qw(edge1 edge2 edge3);

# ============================================
# slot::index behavior
# ============================================

subtest 'slot::index for existing slot' => sub {
    my $idx = slot::index('edge1');
    ok(defined $idx, 'index is defined');
    ok($idx >= 0, 'index is non-negative');
};

subtest 'slot::index returns same index on multiple calls' => sub {
    my $idx1 = slot::index('edge1');
    my $idx2 = slot::index('edge1');
    is($idx1, $idx2, 'same index returned');
};

subtest 'different slots have different indices' => sub {
    my $idx1 = slot::index('edge1');
    my $idx2 = slot::index('edge2');
    my $idx3 = slot::index('edge3');
    
    ok($idx1 != $idx2, 'edge1 != edge2');
    ok($idx2 != $idx3, 'edge2 != edge3');
    ok($idx1 != $idx3, 'edge1 != edge3');
};

# ============================================
# Unset vs undef
# ============================================

subtest 'unset slot returns undef' => sub {
    # edge1 has never been set
    my $val = edge1();
    ok(!defined $val, 'unset slot returns undef');
};

subtest 'slot set to undef' => sub {
    edge2("initial");
    is(edge2(), "initial", 'has initial value');
    
    edge2(undef);
    ok(!defined edge2(), 'can set to undef');
};

# ============================================
# slot::get for unset slot
# ============================================

subtest 'slot::get unset returns undef' => sub {
    my $val = slot::get('edge3');
    ok(!defined $val, 'get on unset slot returns undef');
};

# ============================================
# Index stability
# ============================================

subtest 'index stability when adding slots' => sub {
    my $idx_before = slot::index('edge1');
    
    # Add new slot at runtime
    slot::add('new_runtime_slot');
    
    my $idx_after = slot::index('edge1');
    is($idx_before, $idx_after, 'existing slot index unchanged after add');
};

# ============================================
# slot::add idempotency
# ============================================

subtest 'slot::add returns same index for existing' => sub {
    my $idx1 = slot::add('edge1');
    my $idx2 = slot::add('edge1');
    is($idx1, $idx2, 'add returns same index for existing slot');
};

subtest 'slot::add does not reset value' => sub {
    edge1("preserved value");
    slot::add('edge1');  # Re-add existing
    is(edge1(), "preserved value", 'value preserved after re-add');
};

# ============================================
# Numeric slot names
# ============================================

subtest 'numeric string slot name' => sub {
    slot::add('123');
    slot::set('123', 'numeric name');
    is(slot::get('123'), 'numeric name', 'numeric string name works');
};

# ============================================
# Value types
# ============================================

subtest 'slot stores various value types correctly' => sub {
    # Integer
    edge1(42);
    is(edge1(), 42, 'stores integer');
    
    # Float
    edge1(3.14159);
    is(edge1(), 3.14159, 'stores float');
    
    # String
    edge1("hello world");
    is(edge1(), "hello world", 'stores string');
    
    # Empty string
    edge1("");
    is(edge1(), "", 'stores empty string');
    ok(defined edge1(), 'empty string is defined');
    
    # Zero
    edge1(0);
    is(edge1(), 0, 'stores zero');
    ok(defined edge1(), 'zero is defined');
    
    # Reference
    my $ref = { key => [1, 2, 3] };
    edge1($ref);
    is_deeply(edge1(), $ref, 'stores reference');
};

# ============================================
# slot::slots returns all slots
# ============================================

subtest 'slot::slots includes defined slots' => sub {
    my @slots = slot::slots();
    ok(scalar @slots >= 3, 'at least 3 slots defined');
    
    my %slot_set = map { $_ => 1 } @slots;
    ok($slot_set{edge1}, 'edge1 in slots list');
    ok($slot_set{edge2}, 'edge2 in slots list');
    ok($slot_set{edge3}, 'edge3 in slots list');
};

done_testing;
