#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Cross-thread tests for doubly
# NOTE: doubly objects are NOT cloned to threads (CLONE_SKIP => 1)
# This test verifies that behavior is correct.

BEGIN {
    eval {
        require threads;
        require threads::shared;
    };
    if ($@) {
        plan skip_all => 'threads not available';
    }
}

use threads;
use threads::shared;
use_ok('doubly');

# Test 1: Verify CLONE_SKIP behavior - list is unblessed in child thread
subtest 'list becomes unblessed in child thread' => sub {
    plan tests => 3;

    my $list = doubly->new();
    $list->add(42);
    is($list->data, 42, 'list has data in parent');

    my $t = threads->create(sub {
        # $list should be unblessed due to CLONE_SKIP
        return ref($list) eq 'doubly' ? 'blessed' : 'unblessed';
    });
    my $result = $t->join;

    is($result, 'unblessed', 'list is unblessed in child thread');
    is($list->data, 42, 'list still works in parent after thread');
};

# Test 2: Thread can create its own list
subtest 'thread creates own list' => sub {
    plan tests => 2;

    my $t = threads->create(sub {
        my $list = doubly->new();
        $list->add(1);
        $list->add(2);
        $list->add(3);
        return $list->length;
    });
    my $len = $t->join;

    is($len, 3, 'thread created list with 3 items');
    ok(1, 'thread exited cleanly');
};

# Test 3: Parent list survives child thread lifecycle
subtest 'parent list survives child thread' => sub {
    plan tests => 4;

    my $list = doubly->new();
    $list->add('before');
    is($list->length, 1, 'list has 1 item before thread');

    my $t = threads->create(sub {
        # Do some work
        my $local_list = doubly->new();
        $local_list->add(1);
        return 1;
    });
    $t->join;

    is($list->length, 1, 'list still has 1 item after thread');
    is($list->data, 'before', 'list data unchanged');
    
    $list->add('after');
    is($list->length, 2, 'can still add to list');
};

# Test 4: Multiple threads each with their own lists
subtest 'multiple threads with own lists' => sub {
    plan tests => 1;

    my @results :shared;
    my @threads;
    
    for my $i (1..4) {
        push @threads, threads->create(sub {
            my $list = doubly->new();
            for my $j (1..10) {
                $list->add($j);
            }
            return $list->length;
        });
    }
    
    for my $t (@threads) {
        push @results, $t->join;
    }
    
    is_deeply(\@results, [10, 10, 10, 10], 'each thread had its own list');
};

# Test 5: Simple scalars can be passed via shared variables
subtest 'use shared variables for cross-thread communication' => sub {
    plan tests => 2;

    my $result :shared;
    
    my $list = doubly->new();
    $list->add(42);
    my $val = $list->data;  # Get the value before thread
    
    my $t = threads->create(sub {
        # Can't access $list, but can access shared $result
        $result = $val * 2;  # Use value captured before thread
        return 1;
    });
    $t->join;

    is($result, 84, 'shared variable updated by thread');
    is($list->data, 42, 'original list unchanged');
};

done_testing();
