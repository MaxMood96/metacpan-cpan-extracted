#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use doubly;

# Warmup
for (1..10) {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $d = $list->data;
    my $l = $list->length;
    my $n = $list->next;
}

# ============================================
# Custom op: data (get/set)
# ============================================

subtest 'data get op no leak' => sub {
    my $list = doubly->new(42);
    no_leaks_ok {
        for (1..500) {
            my $d = $list->data;
        }
    } 'data get op does not leak';
};

subtest 'data set op no leak' => sub {
    my $list = doubly->new(0);
    no_leaks_ok {
        for (1..500) {
            $list->data($_);
        }
    } 'data set op does not leak';
};

subtest 'data get/set cycle no leak' => sub {
    my $list = doubly->new(0);
    no_leaks_ok {
        for (1..300) {
            $list->data($_);
            my $d = $list->data;
        }
    } 'data get/set cycle does not leak';
};

# ============================================
# Custom op: length
# ============================================

subtest 'length op no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);
    no_leaks_ok {
        for (1..500) {
            my $len = $list->length;
        }
    } 'length op does not leak';
};

# ============================================
# Custom op: next/prev
# ============================================

subtest 'next op no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $node = $list->start;
    no_leaks_ok {
        for (1..500) {
            my $n = $node->next;
        }
    } 'next op does not leak';
};

subtest 'prev op no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $node = $list->end;
    no_leaks_ok {
        for (1..500) {
            my $p = $node->prev;
        }
    } 'prev op does not leak';
};

subtest 'next/prev navigation no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);
    no_leaks_ok {
        for (1..200) {
            my $node = $list->start;
            while (my $n = $node->next) {
                $node = $n;
            }
        }
    } 'next/prev navigation does not leak';
};

# ============================================
# Custom op: start/end
# ============================================

subtest 'start op no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $node = $list->end;
    no_leaks_ok {
        for (1..500) {
            my $s = $node->start;
        }
    } 'start op does not leak';
};

subtest 'end op no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $node = $list->start;
    no_leaks_ok {
        for (1..500) {
            my $e = $node->end;
        }
    } 'end op does not leak';
};

# ============================================
# Custom op: is_start/is_end
# ============================================

subtest 'is_start op no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $node = $list->start;
    no_leaks_ok {
        for (1..500) {
            my $is = $node->is_start;
        }
    } 'is_start op does not leak';
};

subtest 'is_end op no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $node = $list->end;
    no_leaks_ok {
        for (1..500) {
            my $is = $node->is_end;
        }
    } 'is_end op does not leak';
};

# ============================================
# Combined ops usage
# ============================================

subtest 'chained ops no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);
    no_leaks_ok {
        for (1..200) {
            my $d = $list->start->next->next->data;
            my $l = $list->length;
            my $e = $list->end->prev->data;
        }
    } 'chained ops does not leak';
};

subtest 'bulk_add no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $list = doubly->new(0);
            $list->bulk_add(1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
        }
    } 'bulk_add does not leak';
};

done_testing();
