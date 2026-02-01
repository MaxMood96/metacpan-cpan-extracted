#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

# Import heap with functional ops
use heap 'import';

# ============================================
# Functional ops: heap_push, heap_pop, heap_peek, heap_size
# These are installed via import and use custom ops
# ============================================

subtest 'heap_push and heap_pop' => sub {
    my $h = heap::new('min');

    heap_push($h, 5);
    heap_push($h, 3);
    heap_push($h, 7);
    heap_push($h, 1);

    is(heap_size($h), 4, 'heap_size after pushes');
    is(heap_peek($h), 1, 'heap_peek returns min');

    is(heap_pop($h), 1, 'heap_pop returns 1');
    is(heap_pop($h), 3, 'heap_pop returns 3');
    is(heap_pop($h), 5, 'heap_pop returns 5');
    is(heap_pop($h), 7, 'heap_pop returns 7');

    is(heap_size($h), 0, 'heap_size after all pops');
};

subtest 'heap_push with max heap' => sub {
    my $h = heap::new('max');

    heap_push($h, 5);
    heap_push($h, 3);
    heap_push($h, 7);
    heap_push($h, 1);

    is(heap_peek($h), 7, 'heap_peek returns max');
    is(heap_pop($h), 7, 'heap_pop returns max first');
};

subtest 'heap_size on empty' => sub {
    my $h = heap::new('min');
    is(heap_size($h), 0, 'heap_size on empty heap');
};

subtest 'heap_peek on empty' => sub {
    my $h = heap::new('min');
    is(heap_peek($h), undef, 'heap_peek on empty returns undef');
};

subtest 'heap_pop on empty' => sub {
    my $h = heap::new('min');
    is(heap_pop($h), undef, 'heap_pop on empty returns undef');
};

subtest 'mixed functional and method calls' => sub {
    my $h = heap::new('min');

    # Use both styles interchangeably
    heap_push($h, 10);
    $h->push(5);
    heap_push($h, 15);
    $h->push(1);

    is(heap_size($h), 4, 'size with mixed calls');
    is($h->peek, 1, 'method peek after functional push');
    is(heap_pop($h), 1, 'functional pop');
    is($h->pop, 5, 'method pop');
    is(heap_peek($h), 10, 'functional peek');
};

subtest 'functional ops with complex values' => sub {
    my $h = heap::new('min', sub { $_[0]->{priority} <=> $_[1]->{priority} });

    heap_push($h, { name => 'low', priority => 10 });
    heap_push($h, { name => 'high', priority => 1 });
    heap_push($h, { name => 'med', priority => 5 });

    is(heap_size($h), 3, 'size with complex values');

    my $first = heap_pop($h);
    is($first->{name}, 'high', 'highest priority first');

    my $second = heap_pop($h);
    is($second->{name}, 'med', 'medium priority second');
};

done_testing;
