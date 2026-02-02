#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use slot;

# Test slot::exists function

subtest 'exists returns false for undefined slot' => sub {
    ok(!slot::exists('undefined_slot_xyz'), 'undefined slot does not exist');
};

subtest 'exists returns true after add' => sub {
    slot::add('exists_test1');
    ok(slot::exists('exists_test1'), 'slot exists after add');
};

subtest 'exists returns true for imported slot' => sub {
    package ExistsTestPkg;
    use slot 'imported_slot';
    package main;
    ok(slot::exists('imported_slot'), 'imported slot exists');
};

subtest 'exists with value set' => sub {
    slot::add('exists_test2');
    slot::set('exists_test2', 'value');
    ok(slot::exists('exists_test2'), 'slot with value exists');
};

subtest 'exists after clear' => sub {
    slot::add('exists_test3');
    slot::set('exists_test3', 'data');
    slot::clear('exists_test3');
    ok(slot::exists('exists_test3'), 'slot still exists after clear (only value cleared)');
};

subtest 'exists with undef value' => sub {
    slot::add('exists_test4');
    slot::set('exists_test4', undef);
    ok(slot::exists('exists_test4'), 'slot with undef value still exists');
};

subtest 'multiple exists checks' => sub {
    slot::add('multi1');
    slot::add('multi2');
    slot::add('multi3');
    
    ok(slot::exists('multi1'), 'multi1 exists');
    ok(slot::exists('multi2'), 'multi2 exists');
    ok(slot::exists('multi3'), 'multi3 exists');
    ok(!slot::exists('multi4'), 'multi4 does not exist');
};

subtest 'exists with numeric string name' => sub {
    slot::add('123');
    ok(slot::exists('123'), 'numeric string slot exists');
};

done_testing;
