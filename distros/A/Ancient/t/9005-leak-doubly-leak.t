#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Skip if ps command not available (Windows, minimal docker containers, etc.)
my $ps_available = eval { my $r = `ps -o rss= -p $$ 2>/dev/null`; defined $r && $r =~ /\d/ };
plan skip_all => 'ps command not available' unless $ps_available;

# Skip if doubly is not built (it's optional)
eval { require doubly };
if ($@) {
    plan skip_all => 'doubly not built';
}

plan tests => 10;

# Helper to get current RSS memory in KB
sub get_rss {
    my $rss = `ps -o rss= -p $$`;
    chomp $rss;
    return $rss + 0;
}

# Test for memory leaks
# Run code many times and check memory doesn't grow significantly
sub test_no_leak {
    my ($name, $code, $iterations, $threshold_kb) = @_;
    $iterations //= 100_000;
    $threshold_kb //= 10_000;  # 10MB default threshold
    
    # Warmup
    $code->() for 1..1000;
    
    my $before = get_rss();
    
    $code->() for 1..$iterations;
    
    my $after = get_rss();
    my $diff = $after - $before;
    
    my $passed = $diff < $threshold_kb;
    ok($passed, "$name - memory growth: ${diff}KB (threshold: ${threshold_kb}KB)");
    
    if (!$passed) {
        diag("Memory before: ${before}KB");
        diag("Memory after: ${after}KB");
        diag("Growth: ${diff}KB");
    }
    
    return $passed;
}

# Test 1: new() and immediate destruction
test_no_leak('doubly->new destruction', sub {
    my $list = doubly->new("test");
    # $list goes out of scope
}, 50_000);

# Test 2: add() multiple items
test_no_leak('doubly->add', sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);
}, 20_000);

# Test 3: insert_before/after
test_no_leak('doubly insert_before/after', sub {
    my $list = doubly->new("middle");
    $list->insert_before("before");
    $list->insert_after("after");
}, 20_000);

# Test 4: insert_at_start/end
test_no_leak('doubly insert_at_start/end', sub {
    my $list = doubly->new("middle");
    $list->insert_at_start("first");
    $list->insert_at_end("last");
}, 20_000);

# Test 5: Navigation (start, end, next, prev)
test_no_leak('doubly navigation', sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $node = $list->start;
    $node = $node->next;
    $node = $node->end;
    $node = $node->prev;
    $node = $node->start;
}, 20_000);

# Test 6: data() get/set
test_no_leak('doubly data get/set', sub {
    my $list = doubly->new("original");
    my $data = $list->data;
    $list->data("updated");
    $data = $list->data;
}, 50_000);

# Test 7: remove operations
test_no_leak('doubly remove', sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);
    $list->remove_from_start;
    $list->remove_from_end;
    my $node = $list->start;
    $node->remove;
}, 10_000);

# Test 8: length and predicates
test_no_leak('doubly length/is_start/is_end', sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);
    my $len = $list->length;
    my $at_start = $list->start->is_start;
    my $at_end = $list->end->is_end;
}, 20_000);

# Test 9: find with callback
test_no_leak('doubly find', sub {
    my $list = doubly->new("apple");
    $list->add("banana")->add("cherry");
    my $found = $list->find(sub { $_[0] eq "banana" });
}, 10_000);

# Test 10: Complex operations - build and tear down
test_no_leak('doubly complex build/destroy', sub {
    my $list = doubly->new(0);
    # Build up
    for my $i (1..10) {
        $list->add($i);
    }
    # Navigate
    my $node = $list->start;
    while (!$node->is_end) {
        my $data = $node->data;
        $node = $node->next;
    }
    # Tear down
    while ($list->length > 0) {
        $list->remove_from_start;
    }
}, 5_000);

done_testing();
