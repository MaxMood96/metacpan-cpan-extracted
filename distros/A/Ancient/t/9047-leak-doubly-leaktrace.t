#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;

    eval { require doubly };
    plan skip_all => 'doubly not built' if $@;
}
use Test::LeakTrace;

# Warmup
for (1..10) {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    $list->start;
    $list->end;
}

# ============================================
# Basic list operations
# ============================================

subtest 'new and destroy no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $list = doubly->new("test");
        }
    } 'new and destroy does not leak';
};

subtest 'add operations no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $list = doubly->new(0);
            for my $i (1..10) {
                $list->add($i);
            }
            # $list goes out of scope and is cleaned up
        }
    } 'add operations does not leak';
};

# ============================================
# Navigation operations
# ============================================

subtest 'start/end navigation no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);
    no_leaks_ok {
        for (1..500) {
            my $s = $list->start;
            my $e = $list->end;
        }
    } 'start/end navigation does not leak';
};

subtest 'next/prev navigation no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);
    my $node = $list->start;
    no_leaks_ok {
        for (1..500) {
            $node = $node->next unless $node->is_end;
            $node = $node->prev unless $node->is_start;
        }
    } 'next/prev navigation does not leak';
};

# ============================================
# Data access
# ============================================

subtest 'data get no leak' => sub {
    my $list = doubly->new("value");
    no_leaks_ok {
        for (1..500) {
            my $d = $list->data;
        }
    } 'data get does not leak';
};

subtest 'data set no leak' => sub {
    my $list = doubly->new("initial");
    no_leaks_ok {
        for (1..500) {
            $list->data("updated_$_");
        }
    } 'data set does not leak';
};

# ============================================
# Predicates
# ============================================

subtest 'is_start/is_end no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $start = $list->start;
    my $end = $list->end;
    no_leaks_ok {
        for (1..500) {
            my $s = $start->is_start;
            my $e = $end->is_end;
            my $ns = $start->is_end;
            my $ne = $end->is_start;
        }
    } 'is_start/is_end does not leak';
};

subtest 'length no leak' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);
    no_leaks_ok {
        for (1..500) {
            my $len = $list->length;
        }
    } 'length does not leak';
};

# ============================================
# Insert operations
# ============================================

subtest 'insert_before/after no leak' => sub {
    no_leaks_ok {
        for (1..25) {
            my $list = doubly->new("middle");
            for my $i (1..5) {
                $list->insert_before("before_$i");
                $list->insert_after("after_$i");
            }
        }
    } 'insert_before/after does not leak';
};

subtest 'insert_at_start/end no leak' => sub {
    no_leaks_ok {
        for (1..25) {
            my $list = doubly->new("middle");
            for my $i (1..5) {
                $list->insert_at_start("start_$i");
                $list->insert_at_end("end_$i");
            }
        }
    } 'insert_at_start/end does not leak';
};

# ============================================
# Remove operations
# ============================================

subtest 'remove_from_start/end no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $list = doubly->new(0);
            $list->add($_) for 1..10;
            for (1..5) {
                $list->remove_from_start;
                $list->remove_from_end if $list->length > 0;
            }
        }
    } 'remove_from_start/end does not leak';
};

# ============================================
# Find operations
# ============================================

subtest 'find no leak' => sub {
    my $list = doubly->new("apple");
    $list->add("banana")->add("cherry")->add("date");
    no_leaks_ok {
        for (1..100) {
            my $found = $list->find(sub { $_[0] eq "cherry" });
            my $notfound = $list->find(sub { $_[0] eq "nonexistent" });
        }
    } 'find does not leak';
};

# ============================================
# Complex value storage
# ============================================

subtest 'hashref storage no leak' => sub {
    no_leaks_ok {
        for (1..25) {
            my $list = doubly->new({ id => 1, name => "first" });
            for my $i (1..10) {
                $list->add({ id => $i, name => "item_$i" });
            }
        }
    } 'hashref storage does not leak';
};

subtest 'arrayref storage no leak' => sub {
    no_leaks_ok {
        for (1..25) {
            my $list = doubly->new([1, 2, 3]);
            for my $i (1..10) {
                $list->add([$i, $i + 1, $i + 2]);
            }
        }
    } 'arrayref storage does not leak';
};

done_testing();
