#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use slot qw(leak_slot1 leak_slot2 leak_slot3 leak_watch_slot);

# Warmup
leak_slot1(1);
leak_slot2(2);
for (1..10) {
    my $v = leak_slot1();
    leak_slot1($_);
}

# ============================================
# slot::slots - list all slots
# ============================================

subtest 'slot::slots no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            my @names = slot::slots();
        }
    } 'slot::slots does not leak';
};

# ============================================
# slot::add - bulk add
# ============================================

subtest 'slot::add bulk no leak' => sub {
    no_leaks_ok {
        for my $i (1..100) {
            slot::add("bulk_slot_$i");
        }
    } 'slot::add bulk does not leak';
};

# ============================================
# clear operations
# ============================================

subtest 'slot::clear no leak' => sub {
    slot::add('clear_test');
    no_leaks_ok {
        for (1..200) {
            slot::set('clear_test', 'value');
            slot::clear('clear_test');
        }
    } 'slot::clear does not leak';
};

subtest 'slot::clear_by_idx no leak' => sub {
    slot::add('clear_idx_test');
    my $idx = slot::index('clear_idx_test');
    no_leaks_ok {
        for (1..200) {
            slot::set_by_idx($idx, 'value');
            slot::clear_by_idx($idx);
        }
    } 'slot::clear_by_idx does not leak';
};

# ============================================
# Multiple watchers
# ============================================

subtest 'multiple watchers no leak' => sub {
    my $count1 = 0;
    my $count2 = 0;
    slot::watch('leak_watch_slot', sub { $count1++ });
    slot::watch('leak_watch_slot', sub { $count2++ });

    no_leaks_ok {
        for (1..100) {
            leak_watch_slot($_);
        }
    } 'multiple watchers do not leak';

    slot::unwatch('leak_watch_slot');
};

subtest 'specific watcher removal no leak' => sub {
    my $cb1 = sub { };
    my $cb2 = sub { };

    no_leaks_ok {
        for (1..100) {
            slot::watch('leak_watch_slot', $cb1);
            slot::watch('leak_watch_slot', $cb2);
            slot::unwatch('leak_watch_slot', $cb1);
            slot::unwatch('leak_watch_slot', $cb2);
        }
    } 'specific watcher removal does not leak';
};

# ============================================
# Complex values
# ============================================

subtest 'arrayref value no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            leak_slot1([1, 2, 3, 4, 5]);
            my $v = leak_slot1();
        }
    } 'arrayref value does not leak';
};

subtest 'hashref value no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            leak_slot2({ a => 1, b => 2, c => 3 });
            my $v = leak_slot2();
        }
    } 'hashref value does not leak';
};

subtest 'nested ref value no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            leak_slot3({ arr => [1, { x => 2 }], hash => { y => [3, 4] } });
            my $v = leak_slot3();
        }
    } 'nested ref value does not leak';
};

# ============================================
# Index-based operations with variable index
# ============================================

subtest 'variable index get/set no leak' => sub {
    slot::add('var_idx_slot');
    my $idx = slot::index('var_idx_slot');
    no_leaks_ok {
        for (1..500) {
            slot::set_by_idx($idx, 42);
            my $v = slot::get_by_idx($idx);
        }
    } 'variable index get/set does not leak';
};

# ============================================
# Watcher with closure
# ============================================

subtest 'watcher with closure no leak' => sub {
    my $count = 0;
    no_leaks_ok {
        for (1..50) {
            slot::watch('leak_watch_slot', sub {
                my ($name, $val) = @_;
                $count++;  # Just count, don't accumulate
            });
            leak_watch_slot($_);
            slot::unwatch('leak_watch_slot');
        }
    } 'watcher with closure does not leak';
};

# ============================================
# High-frequency access patterns
# ============================================

subtest 'rapid get/set cycle no leak' => sub {
    no_leaks_ok {
        for (1..1000) {
            leak_slot1($_);
            my $v = leak_slot1();
        }
    } 'rapid get/set cycle does not leak';
};

subtest 'alternating slots no leak' => sub {
    no_leaks_ok {
        for (1..500) {
            leak_slot1($_);
            leak_slot2($_ * 2);
            my $v1 = leak_slot1();
            my $v2 = leak_slot2();
        }
    } 'alternating slots does not leak';
};

# ============================================
# slot::get and slot::set with variable names
# ============================================

subtest 'slot::get with variable name no leak' => sub {
    leak_slot1(42);
    my $name = 'leak_slot1';
    no_leaks_ok {
        for (1..500) {
            my $v = slot::get($name);
        }
    } 'slot::get with variable does not leak';
};

subtest 'slot::set with variable name no leak' => sub {
    my $name = 'leak_slot1';
    no_leaks_ok {
        for (1..500) {
            slot::set($name, 42);
        }
    } 'slot::set with variable does not leak';
};

done_testing();
