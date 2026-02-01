#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use object;

# Define test classes once
object::define('LeakCreate', 'val:Str');
object::define('LeakKeys', 'a:Str', 'b:Int', 'c:Num');
object::define('LeakSeal', 'x:Int');
object::define('LeakMethod', 'count:Int:default(0)');
object::define('LeakChain', 'data:Any');

# Add methods to test class
package LeakMethod;
sub increment { my $self = shift; $self->count($self->count + 1); }
package main;

# Warmup - create objects for tests
my $keys_obj = new LeakKeys 'str', 42, 3.14;
my $seal_obj = new LeakSeal x => 1;
my $method_obj = new LeakMethod;
my $chain_obj = new LeakChain data => 'test';
my $proto_parent = new LeakChain data => 'proto';
my $proto_child = new LeakChain data => 'child';
object::set_prototype($proto_child, $proto_parent);

for (1..10) {
    $keys_obj->a;
    $method_obj->count;
}

# ============================================
# Object creation
# ============================================

subtest 'positional constructor no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $obj = new LeakKeys 'str', 42, 3.14;
        }
    } 'positional constructor does not leak';
};

subtest 'named constructor no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $obj = new LeakKeys a => 'str', b => 42, c => 3.14;
        }
    } 'named constructor does not leak';
};

# ============================================
# Accessor operations (should not leak)
# ============================================

subtest 'accessor get repeated no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            my $a = $keys_obj->a;
            my $b = $keys_obj->b;
            my $c = $keys_obj->c;
        }
    } 'accessor get repeated does not leak';
};

subtest 'accessor set repeated no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            $keys_obj->a('updated');
            $keys_obj->b(99);
            $keys_obj->c(2.71);
        }
    } 'accessor set repeated does not leak';
};

# ============================================
# Lock operations
# ============================================

subtest 'is_locked no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            my $l = object::is_locked($seal_obj);
        }
    } 'is_locked does not leak';
};

# ============================================
# Method calls
# ============================================

subtest 'custom method call no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            $method_obj->increment;
        }
    } 'custom method does not leak';
};

# ============================================
# Prototype chain operations
# ============================================

subtest 'prototype get no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            my $p = object::prototype($proto_child);
        }
    } 'prototype get does not leak';
};

subtest 'prototype chain access no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            my $d = $proto_child->data;
        }
    } 'prototype chain access does not leak';
};

# ============================================
# Lock/unlock operations
# ============================================

subtest 'lock/unlock cycle no leak' => sub {
    my $obj = new LeakSeal x => 1;
    no_leaks_ok {
        for (1..200) {
            object::lock($obj);
            my $l = object::is_locked($obj);
            object::unlock($obj);
        }
    } 'lock/unlock cycle does not leak';
};

# ============================================
# Type registration
# ============================================

subtest 'has_type no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            my $h1 = object::has_type('Str');
            my $h2 = object::has_type('NonExistent');
        }
    } 'has_type does not leak';
};

subtest 'list_types no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $types = object::list_types();
        }
    } 'list_types does not leak';
};

# ============================================
# Freeze operations
# ============================================

subtest 'freeze and is_frozen no leak' => sub {
    my $obj = new LeakSeal x => 42;
    object::freeze($obj);
    no_leaks_ok {
        for (1..500) {
            my $f = object::is_frozen($obj);
            my $v = $obj->x;
        }
    } 'freeze and is_frozen no leak';
};

done_testing();
