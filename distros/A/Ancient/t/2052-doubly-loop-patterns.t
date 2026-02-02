#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use doubly;

# Test doubly linked list with various loop variable patterns
# Note: doubly uses cursor pattern - add() returns cursor to new node

subtest 'for with $item' => sub {
    my $list = doubly->new(1);  # doubly requires initial data
    for my $item (2, 3, 4, 5) {
        $list = $list->add($item);
    }
    is($list->length(), 5, 'doubly add with $item');
};

subtest 'for with $val' => sub {
    my $list = doubly->new('a');
    my @vals = ('b', 'c');
    for my $val (@vals) {
        $list = $list->add($val);
    }

    my @result;
    my $node = $list->start();
    while ($node) {
        push @result, $node->data();
        last if $node->is_end();
        $node = $node->next();
    }
    is_deeply(\@result, ['a', 'b', 'c'], 'doubly with $val');
};

subtest 'for with $n numeric' => sub {
    my $list = doubly->new(10);
    for my $n (20, 30) {
        $list = $list->add($n);
    }

    my $sum = 0;
    my $node = $list->start();
    while ($node) {
        $sum += $node->data();
        last if $node->is_end();
        $node = $node->next();
    }
    is($sum, 60, 'doubly sum with $n');
};

subtest 'for with $data hashref' => sub {
    my @data = (
        { id => 1, name => 'first' },
        { id => 2, name => 'second' },
    );

    my $list = doubly->new($data[0]);
    for my $data (@data[1..$#data]) {
        $list = $list->add($data);
    }

    my $node = $list->start();
    is($node->data()->{id}, 1, 'hashref id 1');
    $node = $node->next();
    is($node->data()->{name}, 'second', 'hashref name');
};

subtest 'while with $node' => sub {
    my $list = doubly->new(1);
    for my $v (2..5) {
        $list = $list->add($v);
    }

    my @forward;
    my $node = $list->start();
    while ($node) {
        push @forward, $node->data();
        last if $node->is_end();
        $node = $node->next();
    }
    is_deeply(\@forward, [1, 2, 3, 4, 5], 'traverse with $node');
};

subtest 'while with $current' => sub {
    my $list = doubly->new(1);
    for my $v (2, 3) {
        $list = $list->add($v);
    }

    my @backward;
    my $current = $list->end();
    while ($current) {
        push @backward, $current->data();
        last if $current->is_start();
        $current = $current->prev();
    }
    is_deeply(\@backward, [3, 2, 1], 'reverse traverse with $current');
};

subtest 'nested loops $outer/$inner' => sub {
    my @lists;
    for my $outer (1..2) {
        my $list = doubly->new($outer * 10 + 1);
        for my $inner (2..3) {
            $list = $list->add($outer * 10 + $inner);
        }
        push @lists, $list;
    }

    is($lists[0]->length(), 3, 'outer 1 has 3 items');
    is($lists[1]->length(), 3, 'outer 2 has 3 items');
};

subtest 'for with $i index' => sub {
    my $list = doubly->new("item0");
    for my $i (1..4) {
        $list = $list->add("item$i");
    }

    my $node = $list->start();
    for my $i (0..2) {
        is($node->data(), "item$i", "item at index $i");
        $node = $node->next();
    }
};

subtest 'grep-like with $_ on data' => sub {
    my $list = doubly->new(1);
    for my $v (2..10) {
        $list = $list->add($v);
    }

    my @evens;
    my $node = $list->start();
    while ($node) {
        local $_ = $node->data();
        push @evens, $_ if $_ % 2 == 0;
        last if $node->is_end();
        $node = $node->next();
    }
    is_deeply(\@evens, [2, 4, 6, 8, 10], 'filter evens with $_');
};

done_testing();
