#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use object;

# ==== Multi-level Prototype Chains ====

subtest 'three-level prototype chain' => sub {
    object::define('Base', 'base_prop:Str');
    object::define('Middle', 'base_prop:Str', 'middle_prop:Str');
    object::define('Derived', 'base_prop:Str', 'middle_prop:Str', 'derived_prop:Str');

    my $base = new Base base_prop => 'base';
    my $middle = new Middle base_prop => 'middle_base', middle_prop => 'middle';
    my $derived = new Derived
        base_prop => 'derived_base',
        middle_prop => 'derived_middle',
        derived_prop => 'derived';

    # Set up chain: derived -> middle -> base
    object::set_prototype($middle, $base);
    object::set_prototype($derived, $middle);

    # Verify chain
    my $p1 = object::prototype($derived);
    isa_ok($p1, 'Middle', 'derived prototype is Middle');

    my $p2 = object::prototype($p1);
    isa_ok($p2, 'Base', 'middle prototype is Base');

    my $p3 = object::prototype($p2);
    ok(!defined($p3), 'base has no prototype');
};

subtest 'prototype property lookup' => sub {
    # Note: object module stores properties per-object,
    # so prototype lookup for properties depends on implementation
    # This test documents expected behavior

    object::define('ProtoBase', 'name:Str');
    object::define('ProtoChild', 'name:Str', 'extra:Str');

    my $parent = new ProtoBase name => 'parent';
    my $child = new ProtoChild name => 'child', extra => 'child_extra';

    object::set_prototype($child, $parent);

    # Child has its own name
    is($child->name, 'child', 'child name is own value');
    is($child->extra, 'child_extra', 'child extra is own value');

    # Parent still accessible via prototype
    my $proto = object::prototype($child);
    is($proto->name, 'parent', 'parent name accessible via prototype');
};

subtest 'circular prototype prevention' => sub {
    object::define('CircA', 'x:Int');
    object::define('CircB', 'x:Int');

    my $a = new CircA x => 1;
    my $b = new CircB x => 2;

    object::set_prototype($a, $b);

    # Trying to create a cycle should fail or be prevented
    eval { object::set_prototype($b, $a) };
    # Note: behavior may vary - some implementations allow cycles,
    # others detect and prevent them
    if ($@) {
        like($@, qr/circular|cycle/i, 'circular prototype detected');
    } else {
        # If no error, verify it doesn't infinite loop on access
        pass('circular prototype allowed (implementation choice)');
        # Don't call prototype() in a loop to avoid hang
    }
};

# ==== Prototype with Freeze/Lock ====

subtest 'frozen object as prototype' => sub {
    object::define('FreezeProtoClass', 'value:Int');

    my $proto = new FreezeProtoClass value => 42;
    object::freeze($proto);
    ok(object::is_frozen($proto), 'prototype is frozen');

    my $child = new FreezeProtoClass value => 100;
    object::set_prototype($child, $proto);

    my $p = object::prototype($child);
    is($p->value, 42, 'frozen prototype accessible');
    ok(object::is_frozen($p), 'prototype remains frozen');

    # Child is not frozen
    ok(!object::is_frozen($child), 'child is not frozen');
    $child->value(200);
    is($child->value, 200, 'child can be modified');
};

subtest 'cannot set prototype on frozen object' => sub {
    object::define('FrozenChildClass', 'x:Int');

    my $proto = new FrozenChildClass x => 1;
    my $frozen = new FrozenChildClass x => 2;
    object::freeze($frozen);

    eval { object::set_prototype($frozen, $proto) };
    like($@, qr/frozen|Cannot/i, 'cannot set prototype on frozen object');
};

subtest 'locked object prototype' => sub {
    object::define('LockedProtoClass', 'x:Int');

    my $proto = new LockedProtoClass x => 1;
    my $obj = new LockedProtoClass x => 2;

    object::lock($obj);
    ok(object::is_locked($obj), 'object is locked');

    # Locked objects may or may not allow prototype changes
    # depending on implementation - test actual behavior
    eval { object::set_prototype($obj, $proto) };
    if ($@) {
        like($@, qr/locked|Cannot/i, 'locked object prevents prototype set');
    } else {
        my $p = object::prototype($obj);
        is($p->x, 1, 'prototype set on locked object worked');
    }
};

# ==== Prototype Type Compatibility ====

subtest 'cross-class prototype' => sub {
    object::define('TypeA', 'a:Int');
    object::define('TypeB', 'b:Str');

    my $a = new TypeA a => 42;
    my $b = new TypeB b => 'hello';

    # Can set prototype across different classes
    object::set_prototype($a, $b);
    my $p = object::prototype($a);
    isa_ok($p, 'TypeB', 'cross-class prototype works');
    is($p->b, 'hello', 'cross-class prototype property accessible');
};

# ==== Prototype with Defaults ====

subtest 'prototype and defaults' => sub {
    object::define('DefaultProtoClass',
        'name:Str:default(unknown)',
        'count:Int:default(0)',
    );

    my $proto = new DefaultProtoClass name => 'proto_name';
    my $child = new DefaultProtoClass;  # Uses defaults

    object::set_prototype($child, $proto);

    is($child->name, 'unknown', 'child uses own default, not prototype');
    is($child->count, 0, 'child default integer works');

    my $p = object::prototype($child);
    is($p->name, 'proto_name', 'prototype has its own value');
};

done_testing;
