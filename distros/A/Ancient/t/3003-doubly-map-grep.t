#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Test doubly (linked list) module functions work correctly in map/grep context
# This ensures call checkers properly handle $_ usage

use doubly;

# ============================================
# doubly->length in map
# ============================================
subtest 'doubly->length in map' => sub {
    my $l1 = doubly->new;
    my $l2 = doubly->new;
    my $l3 = doubly->new;
    
    $l1->add($_) for 1..3;
    $l2->add($_) for 1..5;
    $l3->add($_) for 1..2;
    
    my @lists = ($l1, $l2, $l3);
    my @lengths = map { $_->length } @lists;
    is_deeply(\@lengths, [3, 5, 2], 'length returns correct values in map');
};

# ============================================
# doubly->start in map
# ============================================
subtest 'doubly->start in map' => sub {
    my $l1 = doubly->new; $l1->add(10); $l1->add(20);
    my $l2 = doubly->new; $l2->add(30); $l2->add(40);
    my $l3 = doubly->new; $l3->add(50); $l3->add(60);
    
    my @lists = ($l1, $l2, $l3);
    my @first_nodes = map { $_->start } @lists;
    
    is(scalar(@first_nodes), 3, 'start returns 3 nodes in map');
    is($first_nodes[0]->data, 10, 'first list starts with 10');
    is($first_nodes[1]->data, 30, 'second list starts with 30');
    is($first_nodes[2]->data, 50, 'third list starts with 50');
};

# ============================================
# doubly->end in map
# ============================================
subtest 'doubly->end in map' => sub {
    my $l1 = doubly->new; $l1->add(10); $l1->add(20);
    my $l2 = doubly->new; $l2->add(30); $l2->add(40);
    
    my @lists = ($l1, $l2);
    my @last_nodes = map { $_->end } @lists;
    
    is($last_nodes[0]->data, 20, 'first list ends with 20');
    is($last_nodes[1]->data, 40, 'second list ends with 40');
};

# ============================================
# Filter lists by length in grep
# ============================================
subtest 'filter by length in grep' => sub {
    my @lists;
    for my $size (1, 5, 3, 7, 2) {
        my $l = doubly->new;
        $l->add($_) for 1..$size;
        push @lists, $l;
    }
    
    my @long_lists = grep { $_->length >= 5 } @lists;
    is(scalar(@long_lists), 2, 'grep finds 2 lists with length >= 5');
};

# ============================================
# node->data in map
# ============================================
subtest 'node->data in map' => sub {
    my $list = doubly->new;
    $list->add($_) for (100, 200, 300);
    
    # Collect all nodes
    my @nodes;
    my $node = $list->start;
    while ($node) {
        push @nodes, $node;
        $node = $node->next;
    }
    
    my @values = map { $_->data } @nodes;
    is_deeply(\@values, [100, 200, 300], 'node->data works in map');
};

# ============================================
# Nested map with doubly
# ============================================
subtest 'nested map with doubly' => sub {
    my @all_lists;
    for my $group_size (2, 3) {
        my @group;
        for my $i (1..$group_size) {
            my $l = doubly->new;
            $l->add($i * 10);
            push @group, $l;
        }
        push @all_lists, \@group;
    }
    
    my @lengths = map {
        my $group = $_;
        [ map { $_->length } @$group ]
    } @all_lists;
    
    is_deeply($lengths[0], [1, 1], 'first group all length 1');
    is_deeply($lengths[1], [1, 1, 1], 'second group all length 1');
};

done_testing();
