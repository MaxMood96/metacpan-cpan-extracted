#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(:all);
use lib 'blib/lib', 'blib/arch';

use heap 'import';  # Import function-style API
use Array::Heap qw(make_heap push_heap pop_heap);

# Import raw array functions
*push_heap_min = \&heap::push_heap_min;
*pop_heap_min = \&heap::pop_heap_min;
*make_heap_min = \&heap::make_heap_min;

print "=" x 60, "\n";
print "Heap Benchmark: heap (XS) vs Array::Heap (XS) vs Pure Perl\n";
print "=" x 60, "\n\n";

# Pure Perl min-heap implementation for comparison
package PureHeap {
    sub new {
        my $class = shift;
        return bless { data => [] }, $class;
    }

    sub push {
        my ($self, $val) = @_;
        push @{$self->{data}}, $val;
        $self->_sift_up($#{$self->{data}});
        return $self;
    }

    sub pop {
        my $self = shift;
        return undef unless @{$self->{data}};
        my $top = $self->{data}[0];
        my $last = pop @{$self->{data}};
        if (@{$self->{data}}) {
            $self->{data}[0] = $last;
            $self->_sift_down(0);
        }
        return $top;
    }

    sub peek { $_[0]->{data}[0] }
    sub size { scalar @{$_[0]->{data}} }

    sub _sift_up {
        my ($self, $idx) = @_;
        while ($idx > 0) {
            my $parent = int(($idx - 1) / 2);
            last if $self->{data}[$parent] <= $self->{data}[$idx];
            @{$self->{data}}[$parent, $idx] = @{$self->{data}}[$idx, $parent];
            $idx = $parent;
        }
    }

    sub _sift_down {
        my ($self, $idx) = @_;
        my $size = @{$self->{data}};
        while (1) {
            my $left = 2 * $idx + 1;
            my $right = 2 * $idx + 2;
            my $smallest = $idx;
            $smallest = $left if $left < $size && $self->{data}[$left] < $self->{data}[$smallest];
            $smallest = $right if $right < $size && $self->{data}[$right] < $self->{data}[$smallest];
            last if $smallest == $idx;
            @{$self->{data}}[$idx, $smallest] = @{$self->{data}}[$smallest, $idx];
            $idx = $smallest;
        }
    }
}

package main;

my @test_data = map { int(rand(10000)) } 1..1000;

print "Test: Push 1000 random integers\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'heap (XS OO)' => sub {
        my $h = heap::new('min');
        $h->push($_) for @test_data;
    },
    'heap (XS func)' => sub {
        my $h = heap::new('min');
        heap_push($h, $_) for @test_data;
    },
    'Array::Heap' => sub {
        my @heap;
        push_heap(@heap, $_) for @test_data;
    },
    'Pure Perl' => sub {
        my $h = PureHeap->new;
        $h->push($_) for @test_data;
    },
});

print "\n\nTest: Push 1000 then pop all (full heap sort)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'heap (XS OO)' => sub {
        my $h = heap::new('min');
        $h->push($_) for @test_data;
        $h->pop while $h->size;
    },
    'heap (XS func)' => sub {
        my $h = heap::new('min');
        heap_push($h, $_) for @test_data;
        heap_pop($h) while heap_size($h);
    },
    'Array::Heap' => sub {
        my @heap;
        push_heap(@heap, $_) for @test_data;
        pop_heap(@heap) while @heap;
    },
    'Pure Perl' => sub {
        my $h = PureHeap->new;
        $h->push($_) for @test_data;
        $h->pop while $h->size;
    },
});

print "\n\nTest: push_all (bulk insert 1000 items)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'heap (XS)' => sub {
        my $h = heap::new('min');
        $h->push_all(@test_data);
    },
    'Array::Heap' => sub {
        my @heap = @test_data;
        make_heap(@heap);
    },
    'Pure Perl' => sub {
        my $h = PureHeap->new;
        $h->push($_) for @test_data;
    },
});

print "\n\nTest: Peek (10000 peeks on heap of 1000)\n";
print "-" x 40, "\n";

my $heap_xs = heap::new('min');
$heap_xs->push_all(@test_data);

my @array_heap = @test_data;
make_heap(@array_heap);

my $pure_heap = PureHeap->new;
$pure_heap->push($_) for @test_data;

cmpthese(-2, {
    'heap (XS OO)' => sub {
        $heap_xs->peek for 1..10000;
    },
    'heap (XS func)' => sub {
        heap_peek($heap_xs) for 1..10000;
    },
    'Array::Heap' => sub {
        my $x = $array_heap[0] for 1..10000;
    },
    'Pure Perl' => sub {
        $pure_heap->peek for 1..10000;
    },
});

print "\n\nTest: Mixed push/pop (simulating priority queue usage)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'heap (XS OO)' => sub {
        my $h = heap::new('min');
        for my $i (0..499) {
            $h->push($test_data[$i]);
            $h->push($test_data[$i + 500]);
            $h->pop;
        }
    },
    'heap (XS func)' => sub {
        my $h = heap::new('min');
        for my $i (0..499) {
            heap_push($h, $test_data[$i]);
            heap_push($h, $test_data[$i + 500]);
            heap_pop($h);
        }
    },
    'Array::Heap' => sub {
        my @heap;
        for my $i (0..499) {
            push_heap(@heap, $test_data[$i]);
            push_heap(@heap, $test_data[$i + 500]);
            pop_heap(@heap);
        }
    },
    'Pure Perl' => sub {
        my $h = PureHeap->new;
        for my $i (0..499) {
            $h->push($test_data[$i]);
            $h->push($test_data[$i + 500]);
            $h->pop;
        }
    },
});

print "\n\nTest: Raw array push (1000 items) - head-to-head with Array::Heap\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Array::Heap' => sub {
        my @heap;
        push_heap(@heap, $_) for @test_data;
    },
    'heap raw min' => sub {
        my @heap;
        push_heap_min(\@heap, $_) for @test_data;
    },
});

print "\n\nTest: Raw array push+pop (heapsort pattern)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Array::Heap' => sub {
        my @heap;
        push_heap(@heap, $_) for @test_data;
        pop_heap(@heap) while @heap;
    },
    'heap raw min' => sub {
        my @heap;
        push_heap_min(\@heap, $_) for @test_data;
        pop_heap_min(\@heap) while @heap;
    },
});

print "\n\nTest: Raw array make_heap (O(n) Floyd's heapify)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Array::Heap' => sub {
        my @heap = @test_data;
        make_heap(@heap);
    },
    'heap raw min' => sub {
        my @heap = @test_data;
        make_heap_min(\@heap);
    },
});

print "\n\nTest: Numeric heap push (1000 items)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Array::Heap' => sub {
        my @heap;
        push_heap(@heap, $_) for @test_data;
    },
    'heap NV' => sub {
        my $h = heap::new_nv('min');
        heap::nv::push($h, $_) for @test_data;
    },
    'heap (XS func)' => sub {
        my $h = heap::new('min');
        heap_push($h, $_) for @test_data;
    },
});

print "\n\nTest: Numeric heap push+pop (heapsort pattern)\n";
print "-" x 40, "\n";

cmpthese(-2, {
    'Array::Heap' => sub {
        my @heap;
        push_heap(@heap, $_) for @test_data;
        pop_heap(@heap) while @heap;
    },
    'heap NV' => sub {
        my $h = heap::new_nv('min');
        heap::nv::push($h, $_) for @test_data;
        heap::nv::pop($h) while heap::nv::size($h);
    },
    'heap (XS func)' => sub {
        my $h = heap::new('min');
        heap_push($h, $_) for @test_data;
        heap_pop($h) while heap_size($h);
    },
});

print "\n", "=" x 60, "\n";
print "Summary:\n";
print "- heap (XS OO): OO interface with call checker optimization\n";
print "- heap (XS func): Function-style with custom ops\n";
print "- heap raw min: Raw array API (Array::Heap-compatible)\n";
print "- heap NV: Numeric heap (stores NV directly, no SV overhead)\n";
print "- Array::Heap: Popular XS module (functional interface)\n";
print "- Pure Perl: Reference implementation for baseline\n";
print "=" x 60, "\n";
