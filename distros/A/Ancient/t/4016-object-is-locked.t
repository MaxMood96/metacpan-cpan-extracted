#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';
use object;

# Test object::is_locked predicate function
subtest 'is_locked initially false' => sub {
    object::define('LockTest1', qw(value));
    my $obj = new LockTest1 value => 42;
    
    ok(!object::is_locked($obj), 'new object is not locked');
};

subtest 'is_locked after lock' => sub {
    object::define('LockTest2', qw(name));
    my $obj = new LockTest2 name => 'test';
    
    ok(!object::is_locked($obj), 'initially not locked');
    object::lock($obj);
    ok(object::is_locked($obj), 'is_locked returns true after lock');
};

subtest 'is_locked after unlock' => sub {
    object::define('LockTest3', qw(data));
    my $obj = new LockTest3 data => 'test';
    
    object::lock($obj);
    ok(object::is_locked($obj), 'locked');
    object::unlock($obj);
    ok(!object::is_locked($obj), 'is_locked returns false after unlock');
};

subtest 'is_locked with prototype chain' => sub {
    object::define('LockParent', qw(parent_val));
    object::define('LockChild', qw(child_val), 'LockParent');
    
    my $child = new LockChild child_val => 1, parent_val => 2;
    
    ok(!object::is_locked($child), 'child initially not locked');
    object::lock($child);
    ok(object::is_locked($child), 'child is_locked after lock');
};

subtest 'is_locked is per-object' => sub {
    object::define('LockMulti', qw(val));
    my $obj1 = new LockMulti val => 1;
    my $obj2 = new LockMulti val => 2;
    
    object::lock($obj1);
    
    ok(object::is_locked($obj1), 'obj1 is locked');
    ok(!object::is_locked($obj2), 'obj2 is not locked (independent)');
};

done_testing;
