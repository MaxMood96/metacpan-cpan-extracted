#!/usr/bin/env perl
# Integration test: doubly + heap + util for collection operations
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use doubly;
use heap;
use util;

subtest 'doubly list to sorted output' => sub {
    my $list = doubly->new();
    $list->insert_at_start(3);
    $list = $list->insert_at_end(1);
    $list->insert_after(4);
    $list = $list->insert_at_end(1);
    $list->insert_after(5);
    $list = $list->insert_at_end(9);
    
    my $min_heap = heap::new('min');
    $list = $list->start;
    while (defined $list && defined $list->data) {
        $min_heap->push($list->data);
        last if $list->is_end;
        $list = $list->next;
    }
    
    is($min_heap->size, 6, 'heap has all values');
    
    my @sorted;
    while (!$min_heap->is_empty) {
        push @sorted, $min_heap->pop;
    }
    
    is_deeply(\@sorted, [1, 1, 3, 4, 5, 9], 'min-heap extracts in sorted order');
};

subtest 'filter list with util predicates' => sub {
    my $list = doubly->new();
    for my $val (-5, -3, 0, 2, 4, 6, 8, 10) {
        $list = $list->insert_at_end($val);
    }
    $list = $list->start;
    
    my @positives;
    while (defined $list && defined $list->data) {
        push @positives, $list->data if util::is_positive($list->data);
        last if $list->is_end;
        $list = $list->next;
    }
    
    is_deeply(\@positives, [2, 4, 6, 8, 10], 'collected positive values');
    
    my $max_heap = heap::new('max');
    $max_heap->push($_) for @positives;
    
    is($max_heap->pop, 10, 'max-heap returns largest first');
    is($max_heap->pop, 8, 'then second largest');
};

subtest 'priority queue pattern' => sub {
    my $pq = heap::new('min');
    
    $pq->push(100);
    $pq->push(1);
    $pq->push(50);
    
    is($pq->peek, 1, 'highest priority (lowest number) at top');
    is($pq->size, 3, 'queue has 3 items');
    
    my @processed;
    while (!$pq->is_empty) {
        push @processed, $pq->pop;
    }
    
    is_deeply(\@processed, [1, 50, 100], 'processed in priority order');
};

subtest 'clamped values into heap' => sub {
    my @raw = (1, 100, 50, 200, 75, 300);
    
    my $heap = heap::new('min');
    for my $val (@raw) {
        $heap->push(util::clamp($val, 10, 100));
    }
    
    my @result;
    while (!$heap->is_empty) {
        push @result, $heap->pop;
    }
    
    is_deeply(\@result, [10, 50, 75, 100, 100, 100], 'clamped and sorted correctly');
};

done_testing();
