#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use doubly;

# ============================================
# Custom OP tests for doubly module
# Tests the optimized ops: data, length, next, prev,
# start, end, is_start, is_end
# ============================================

subtest 'length op' => sub {
    my $list = doubly->new();
    is($list->length, 0, 'empty list length is 0');

    $list->add(1);
    is($list->length, 1, 'length after add');

    $list->add(2)->add(3);
    is($list->length, 3, 'length after chained adds');

    $list->remove_from_end;
    is($list->length, 2, 'length after remove');

    # Multiple length calls (test op caching)
    my $len1 = $list->length;
    my $len2 = $list->length;
    is($len1, $len2, 'consistent length');
};

subtest 'data get op' => sub {
    my $list = doubly->new(42);
    is($list->data, 42, 'get scalar data');

    $list = doubly->new({ key => 'value' });
    is_deeply($list->data, { key => 'value' }, 'get hash data');

    $list = doubly->new([1, 2, 3]);
    is_deeply($list->data, [1, 2, 3], 'get array data');

    # Multiple get calls
    my $d1 = $list->data;
    my $d2 = $list->data;
    is_deeply($d1, $d2, 'consistent data get');
};

subtest 'data set op' => sub {
    my $list = doubly->new();

    $list->data(100);
    is($list->data, 100, 'set and get scalar');

    $list->data({ a => 1 });
    is_deeply($list->data, { a => 1 }, 'set and get hash');

    $list->data([4, 5, 6]);
    is_deeply($list->data, [4, 5, 6], 'set and get array');

    # Overwrite
    $list->data('string');
    is($list->data, 'string', 'overwrite data');
};

subtest 'next op' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4);

    my $cursor = $list->start;
    is($cursor->data, 1, 'start at first');

    $cursor = $cursor->next;
    is($cursor->data, 2, 'next to second');

    $cursor = $cursor->next;
    is($cursor->data, 3, 'next to third');

    $cursor = $cursor->next;
    is($cursor->data, 4, 'next to fourth');

    $cursor = $cursor->next;
    is($cursor, undef, 'next at end returns undef');
};

subtest 'prev op' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4);

    my $cursor = $list->end;
    is($cursor->data, 4, 'end at last');

    $cursor = $cursor->prev;
    is($cursor->data, 3, 'prev to third');

    $cursor = $cursor->prev;
    is($cursor->data, 2, 'prev to second');

    $cursor = $cursor->prev;
    is($cursor->data, 1, 'prev to first');

    $cursor = $cursor->prev;
    is($cursor, undef, 'prev at start returns undef');
};

subtest 'start op' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);

    # Navigate away then back
    my $cursor = $list->end;
    is($cursor->data, 3, 'at end');

    $cursor = $cursor->start;
    is($cursor->data, 1, 'back to start');

    # Multiple start calls
    my $s1 = $list->start;
    my $s2 = $list->start;
    is($s1->data, $s2->data, 'consistent start');
};

subtest 'end op' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);

    my $cursor = $list->start;
    is($cursor->data, 1, 'at start');

    $cursor = $cursor->end;
    is($cursor->data, 3, 'to end');

    # Multiple end calls
    my $e1 = $list->end;
    my $e2 = $list->end;
    is($e1->data, $e2->data, 'consistent end');
};

subtest 'is_start op' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);

    my $cursor = $list->start;
    ok($cursor->is_start, 'is_start at head');
    ok(!$cursor->is_end, 'not is_end at head');

    $cursor = $cursor->next;
    ok(!$cursor->is_start, 'not is_start in middle');
    ok(!$cursor->is_end, 'not is_end in middle');

    $cursor = $list->end;
    ok(!$cursor->is_start, 'not is_start at tail');
    ok($cursor->is_end, 'is_end at tail');
};

subtest 'is_end op' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);

    my $cursor = $list->end;
    ok($cursor->is_end, 'is_end at tail');
    ok(!$cursor->is_start, 'not is_start at tail');

    $cursor = $cursor->prev;
    ok(!$cursor->is_end, 'not is_end in middle');
    ok(!$cursor->is_start, 'not is_start in middle');
};

subtest 'single element list' => sub {
    my $list = doubly->new('only');

    is($list->length, 1, 'single element length');
    is($list->data, 'only', 'single element data');
    ok($list->is_start, 'single element is_start');
    ok($list->is_end, 'single element is_end');
    is($list->next, undef, 'single element next is undef');
    is($list->prev, undef, 'single element prev is undef');
    is($list->start->data, 'only', 'single element start');
    is($list->end->data, 'only', 'single element end');
};

subtest 'chained op calls' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3)->add(4)->add(5);

    # Chain navigation
    is($list->start->next->next->data, 3, 'chained next');
    is($list->end->prev->prev->data, 3, 'chained prev');
    is($list->start->next->next->prev->data, 2, 'mixed chain');

    # Start from anywhere
    my $mid = $list->start->next->next;
    is($mid->start->data, 1, 'start from middle');
    is($mid->end->data, 5, 'end from middle');
};

subtest 'ops after modifications' => sub {
    my $list = doubly->new(1);
    $list->add(2)->add(3);

    is($list->length, 3, 'initial length');

    $list->add(4);
    is($list->length, 4, 'length after add');
    is($list->end->data, 4, 'end after add');

    $list->remove_from_end;
    is($list->length, 3, 'length after remove');
    is($list->end->data, 3, 'end after remove');

    $list->insert_at_start(0);
    is($list->length, 4, 'length after insert');
    is($list->start->data, 0, 'start after insert');
};

done_testing;
