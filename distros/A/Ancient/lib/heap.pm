package
    heap;
use strict;
use warnings;
our $VERSION = '0.14';
require XSLoader;
XSLoader::load('heap', $VERSION);
1;

__END__

=head1 NAME

heap - Binary heap (priority queue) with O(log n) operations

=head1 SYNOPSIS

    use heap;

    # Create a min-heap (smallest element at top)
    my $min_heap = heap::new('min');

    # Create a max-heap (largest element at top)
    my $max_heap = heap::new('max');

    # Push values - O(log n)
    $min_heap->push(5);
    $min_heap->push(3);
    $min_heap->push(7);
    $min_heap->push(1);

    # Pop returns smallest (for min-heap) - O(log n)
    print $min_heap->pop;   # 1
    print $min_heap->pop;   # 3
    print $min_heap->pop;   # 5
    print $min_heap->pop;   # 7

    # Peek without removing - O(1)
    $min_heap->push(10);
    print $min_heap->peek;  # 10

    # Bulk operations
    $min_heap->push_all(4, 2, 8, 6);

    # Utility methods - O(1)
    my $size = $min_heap->size;
    my $empty = $min_heap->is_empty;
    my $type = $min_heap->type;  # 'min' or 'max'
    $min_heap->clear;

    # Custom comparator for complex objects
    my $heap = heap::new('min', sub {
        my ($a, $b) = @_;
        return $a->{priority} <=> $b->{priority};
    });

    $heap->push({ name => 'low',    priority => 10 });
    $heap->push({ name => 'high',   priority => 1  });
    $heap->push({ name => 'medium', priority => 5  });

    print $heap->pop->{name};  # 'high'

=head1 DESCRIPTION

C<heap> provides a  binary heap implementation in C. A heap is a
tree-based data structure that satisfies the heap property: in a min-heap,
the parent is always smaller than its children; in a max-heap, the parent
is always larger.

This makes heaps ideal for priority queues where you need efficient access
to the minimum or maximum element.

=head2 Performance

=over 4

=item * B<push>: O(log n)

=item * B<pop>: O(log n)

=item * B<peek>: O(1)

=item * B<size/is_empty>: O(1)

=back

=head1 METHODS

=head2 heap::new($type, [$comparator])

Create a new heap.

    my $min_heap = heap::new('min');              # Min-heap
    my $max_heap = heap::new('max');              # Max-heap
    my $custom   = heap::new('min', sub { ... }); # With comparator

Parameters:

=over 4

=item * C<$type> - Either C<'min'> or C<'max'>. Determines whether the
smallest or largest element is at the top.

=item * C<$comparator> - Optional. A code reference that takes two values
and returns -1, 0, or 1 (like C<< <=> >>). When provided, this is used
instead of numeric comparison.

=back

=head2 $heap->push($value)

Add an element to the heap. Returns the heap for method chaining.

    $heap->push(42);
    $heap->push($obj)->push($another);  # Chaining

=head2 $heap->push_all(@values)

Add multiple elements to the heap. Returns the heap for method chaining.

    $heap->push_all(1, 2, 3, 4, 5);

=head2 $heap->pop

Remove and return the top element (minimum for min-heap, maximum for
max-heap). Returns C<undef> if the heap is empty.

    my $min = $min_heap->pop;

=head2 $heap->peek

Return the top element without removing it. Returns C<undef> if empty.

    my $min = $min_heap->peek;

=head2 $heap->size

Returns the number of elements in the heap.

=head2 $heap->is_empty

Returns true if the heap has no elements.

=head2 $heap->clear

Remove all elements from the heap.

=head2 $heap->type

Returns the heap type as a string: C<'min'> or C<'max'>.

=head1 CUSTOM COMPARATORS

For objects or complex sorting, provide a comparator function:

    # Sort by 'score' field, highest first (max-heap behavior)
    my $leaderboard = heap::new('max', sub {
        my ($a, $b) = @_;
        return $a->{score} <=> $b->{score};
    });

    # Sort by string field
    my $alpha_heap = heap::new('min', sub {
        my ($a, $b) = @_;
        return $a->{name} cmp $b->{name};
    });

The comparator should return:

=over 4

=item * C<-1> if C<$a> should come before C<$b>

=item * C<0> if they are equal

=item * C<1> if C<$b> should come before C<$a>

=back

=head1 EXAMPLES

=head2 Simple Priority Queue

    use heap;

    my $pq = heap::new('min');
    $pq->push(5);
    $pq->push(1);
    $pq->push(3);

    while (!$pq->is_empty) {
        print $pq->pop, "\n";  # Prints: 1, 3, 5
    }

=head2 Task Scheduler

    use heap;

    my $tasks = heap::new('min', sub {
        $_[0]->{due} <=> $_[1]->{due}
    });

    $tasks->push({ name => 'Report',  due => 1706745600 });
    $tasks->push({ name => 'Meeting', due => 1706659200 });
    $tasks->push({ name => 'Review',  due => 1706832000 });

    # Process tasks in order of due date
    while (!$tasks->is_empty) {
        my $task = $tasks->pop;
        print "Do: $task->{name}\n";
    }

=head2 Finding K Largest Elements

    use heap;

    my @numbers = (3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5);
    my $k = 3;

    # Use min-heap of size k
    my $heap = heap::new('min');
    for my $n (@numbers) {
        $heap->push($n);
        if ($heap->size > $k) {
            $heap->pop;  # Remove smallest
        }
    }

    # Heap now contains k largest
    my @largest;
    while (!$heap->is_empty) {
        push @largest, $heap->pop;
    }
    print "@largest\n";  # 5 6 9

=head1 FUNCTIONAL INTERFACE

Import functional ops with C<use heap 'import'>:

    use heap 'import';

    my $h = heap::new('min');

    heap_push($h, 5);
    heap_push($h, 3);
    heap_push($h, 1);

    my $size = heap_size($h);   # 3
    my $top = heap_peek($h);    # 1
    my $val = heap_pop($h);     # 1

These functions use custom ops for compile-time optimization.

=head2 heap_push($heap, $value)

Push a value onto the heap. Same as C<< $heap->push($value) >>.

=head2 heap_pop($heap)

Pop and return the top value. Same as C<< $heap->pop >>.

=head2 heap_peek($heap)

Return the top value without removing. Same as C<< $heap->peek >>.

=head2 heap_size($heap)

Return the heap size. Same as C<< $heap->size >>.

=head1 NUMERIC HEAP

For numeric-only data, C<new_nv> creates a heap that stores native doubles
directly, avoiding SV overhead:

    my $h = heap::new_nv('min');

    $h->push(3.14);
    $h->push(2.71);
    $h->push(1.41);

    print $h->pop;  # 1.41
    print $h->pop;  # 2.71

Methods: C<push>, C<push_all>, C<pop>, C<peek>, C<size>, C<is_empty>, C<clear>.

=head1 RAW ARRAY API

For maximum performance, operate directly on Perl arrays. Import with
C<use heap 'raw'>:

    use heap 'raw';

    my @arr = (5, 3, 7, 1, 4);

    # Convert array to heap in O(n)
    heap::make_heap_min(\@arr);
    heap::make_heap_max(\@arr);

    # Push/pop operations
    heap::push_heap_min(\@arr, 2);
    my $min = heap::pop_heap_min(\@arr);

    heap::push_heap_max(\@arr, 8);
    my $max = heap::pop_heap_max(\@arr);

=head2 heap::make_heap_min(\@array)

Convert an array into a min-heap in O(n) time.

=head2 heap::make_heap_max(\@array)

Convert an array into a max-heap in O(n) time.

=head2 heap::push_heap_min(\@array, $value)

Push a value onto a min-heap array.

=head2 heap::pop_heap_min(\@array)

Pop and return the minimum from a min-heap array.

=head2 heap::push_heap_max(\@array, $value)

Push a value onto a max-heap array.

=head2 heap::pop_heap_max(\@array)

Pop and return the maximum from a max-heap array.

=head1 AUTHOR

LNATION E<email@lnation.org>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
