#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use heap 'import';  # Get functional ops
use heap 'raw';     # Get raw array ops

# Warmup
for (1..10) {
    my $h = heap::new_nv('min');
    $h->push($_) for 1..5;
    $h->pop for 1..5;
}

# ============================================
# Numeric heap (new_nv)
# ============================================

subtest 'new_nv push/pop cycle no leak' => sub {
    my $h = heap::new_nv('min');
    no_leaks_ok {
        for (1..500) {
            $h->push(42.5);
            my $v = $h->pop;
        }
    } 'new_nv push/pop cycle does not leak';
};

subtest 'new_nv push_all no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $h = heap::new_nv('max');
            $h->push_all(1.1, 2.2, 3.3, 4.4, 5.5);
            while (!$h->is_empty) { $h->pop; }
        }
    } 'new_nv push_all does not leak';
};

subtest 'new_nv peek/size no leak' => sub {
    my $h = heap::new_nv('min');
    $h->push($_) for 1..10;
    no_leaks_ok {
        for (1..500) {
            my $p = $h->peek;
            my $s = $h->size;
        }
    } 'new_nv peek/size does not leak';
};

subtest 'new_nv clear no leak' => sub {
    my $h = heap::new_nv('min');
    no_leaks_ok {
        for (1..100) {
            $h->push($_) for 1..10;
            $h->clear;
        }
    } 'new_nv clear does not leak';
};

# ============================================
# Functional ops (heap_push, heap_pop, etc.)
# ============================================

subtest 'heap_push/heap_pop no leak' => sub {
    my $h = heap::new('min');
    no_leaks_ok {
        for (1..500) {
            heap_push($h, 42);
            my $v = heap_pop($h);
        }
    } 'heap_push/heap_pop does not leak';
};

subtest 'heap_peek no leak' => sub {
    my $h = heap::new('min');
    $h->push($_) for 1..10;
    no_leaks_ok {
        for (1..500) {
            my $v = heap_peek($h);
        }
    } 'heap_peek does not leak';
};

subtest 'heap_size no leak' => sub {
    my $h = heap::new('min');
    $h->push($_) for 1..10;
    no_leaks_ok {
        for (1..500) {
            my $s = heap_size($h);
        }
    } 'heap_size does not leak';
};

# ============================================
# Raw array API
# ============================================

subtest 'make_heap_min no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my @arr = (5, 3, 7, 1, 4, 6, 2);
            heap::make_heap_min(\@arr);
        }
    } 'make_heap_min does not leak';
};

subtest 'make_heap_max no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my @arr = (5, 3, 7, 1, 4, 6, 2);
            heap::make_heap_max(\@arr);
        }
    } 'make_heap_max does not leak';
};

subtest 'push_heap_min/pop_heap_min no leak' => sub {
    my @arr;
    no_leaks_ok {
        for (1..200) {
            heap::push_heap_min(\@arr, 42);
            my $v = heap::pop_heap_min(\@arr);
        }
    } 'push_heap_min/pop_heap_min does not leak';
};

subtest 'push_heap_max/pop_heap_max no leak' => sub {
    my @arr;
    no_leaks_ok {
        for (1..200) {
            heap::push_heap_max(\@arr, 42);
            my $v = heap::pop_heap_max(\@arr);
        }
    } 'push_heap_max/pop_heap_max does not leak';
};

subtest 'raw heap full cycle no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my @arr;
            for my $i (1..20) {
                heap::push_heap_min(\@arr, $i);
            }
            while (@arr) {
                heap::pop_heap_min(\@arr);
            }
        }
    } 'raw heap full cycle does not leak';
};

# ============================================
# Custom comparator
# ============================================

subtest 'heap with custom comparator no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $h = heap::new('min', sub { $_[0]->{p} <=> $_[1]->{p} });
            $h->push({ p => $_ }) for 1..10;
            while (!$h->is_empty) { $h->pop; }
        }
    } 'heap with custom comparator does not leak';
};

done_testing();
