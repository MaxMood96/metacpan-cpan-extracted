#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Thread tests for doubly
# NOTE: doubly objects are NOT cloned to threads (CLONE_SKIP => 1)
# Each thread must create its own lists.

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

# Test 1: Basic operations work
subtest 'Basic doubly operations' => sub {
    plan tests => 10;
    
    my $list = doubly->new();
    ok($list, 'List created');
    is($list->length, 0, 'Empty list has length 0');
    
    $list->add(1);
    $list->add(2);
    $list->add(3);
    is($list->length, 3, 'Length after adding 3 items');
    
    $list = $list->start;
    is($list->data, 1, 'start returns first item');
    ok($list->is_start, 'is_start true at start');
    
    $list = $list->end;
    is($list->data, 3, 'end returns last item');
    ok($list->is_end, 'is_end true at end');
    
    $list = $list->prev;
    is($list->data, 2, 'prev moves backward');
    
    $list = $list->next;
    is($list->data, 3, 'next moves forward');
    
    $list->destroy;
    ok(1, 'destroy completed');
};

# Test 2: Thread-local lists (each thread creates its own)
subtest 'Thread-local lists' => sub {
    plan tests => 1;
    
    my @threads;
    my @results :shared;
    
    for my $i (1..4) {
        push @threads, threads->create(sub {
            my $list = doubly->new();
            for my $j (1..100) {
                $list->add($j);
            }
            return $list->length;
        });
    }
    
    for my $t (@threads) {
        push @results, $t->join;
    }
    
    is_deeply(\@results, [100, 100, 100, 100], 'each thread got 100 items');
};

# Test 3: Parent list not usable in thread (CLONE_SKIP)
subtest 'Parent list not usable in thread' => sub {
    plan tests => 3;
    
    my $list = doubly->new();
    for my $i (1..100) {
        $list->add($i);
    }
    is($list->length, 100, 'parent has 100 items');
    
    my $t = threads->create(sub {
        # $list is unblessed in thread due to CLONE_SKIP
        return ref($list) eq 'doubly' ? 'blessed' : 'unblessed';
    });
    
    my $result = $t->join;
    is($result, 'unblessed', 'list is unblessed in child thread (CLONE_SKIP)');
    is($list->length, 100, 'parent list still works after thread');
};

# Test 4: Rapid create and destroy in threads
subtest 'Rapid create and destroy in threads' => sub {
    plan tests => 1;
    
    my @threads;
    for my $i (1..4) {
        push @threads, threads->create(sub {
            for my $j (1..50) {
                my $list = doubly->new();
                $list->add(1);
                $list->add(2);
                $list->destroy;
            }
            return 1;
        });
    }
    
    my $ok = 1;
    for my $t (@threads) {
        $ok = 0 unless $t->join;
    }
    
    ok($ok, 'rapid create/destroy completed');
};

# Test 5: Complex operations in threads
subtest 'Complex operations in threads' => sub {
    plan tests => 1;
    
    my @threads;
    for my $i (1..4) {
        push @threads, threads->create(sub {
            my $list = doubly->new();
            for my $j (1..100) {
                $list->add($j);
                if ($j % 3 == 0) {
                    $list->remove_from_start;
                }
            }
            return 1;
        });
    }
    
    my $ok = 1;
    for my $t (@threads) {
        $ok = 0 unless $t->join;
    }
    
    ok($ok, 'complex operations completed without errors');
};

# Test 6: Navigation operations in threads
subtest 'Navigation in threads' => sub {
    plan tests => 1;
    
    my @threads;
    for my $i (1..4) {
        push @threads, threads->create(sub {
            my $list = doubly->new();
            for my $j (1..50) {
                $list->add($j);
            }
            
            my $moves = 0;
            for my $k (1..20) {
                $list->start;
                $list->next;
                $list->next;
                $list->end;
                $list->prev;
                $moves++;
            }
            return $moves;
        });
    }
    
    my $ok = 1;
    for my $t (@threads) {
        my $res = $t->join;
        $ok = 0 unless $res == 20;
    }
    
    ok($ok, 'navigation in threads completed');
};

done_testing();
