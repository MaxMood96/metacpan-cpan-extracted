package
    doubly;

use strict;
use warnings;

our $VERSION = '0.10';

require XSLoader;
XSLoader::load('doubly', $VERSION);

1;

__END__

=head1 NAME

doubly - doubly linked list

=head1 SYNOPSIS

    use doubly;

    my $list = doubly->new(1);
    $list->add(2)->add(3);

    # Navigation
    $list = $list->start;    # Go to head
    $list = $list->end;      # Go to tail
    $list = $list->next;     # Move to next node
    $list = $list->prev;     # Move to previous node

    # Data access
    my $data = $list->data;       # Get current node's data
    $list->data("new value");     # Set current node's data

    # Insertion
    my $new = $list->insert_before("value");
    my $new = $list->insert_after("value");
    $list->insert_at_start("first");
    $list->insert_at_end("last");

    # Removal
    my $removed = $list->remove;
    my $removed = $list->remove_from_start;
    my $removed = $list->remove_from_end;

    # Utility
    my $length = $list->length;
    my $is_start = $list->is_start;
    my $is_end = $list->is_end;

    # Search
    my $found = $list->find(sub { $_[0] eq "target" });

=head1 DESCRIPTION

My fastest doubly linked list implementation without JIT or building via a class/schema. 
This module provides full API compatibility with the Doubly module but
runs approximately 3x faster.

This implementation is not thread-safe, the lists cannot be shared across threads.

=head2 Architecture

=over 4

=item * Dynamic SV-based node storage (no serialization overhead)

=item * Index-based linking with global registry

=item * Reference counting for automatic garbage collection

=back

=head1 METHODS

=head2 new

    my $list = doubly->new();
    my $list = doubly->new($initial_data);

Create a new doubly linked list, optionally with initial data.

=head2 length

    my $len = $list->length;

Returns the number of nodes in the list.

=head2 data

    my $data = $list->data;       # getter
    $list->data($new_value);      # setter

Get or set the data of the current node.

=head2 start

    my $start = $list->start;

Returns a new list object pointing to the head of the list.

=head2 end

    my $end = $list->end;

Returns a new list object pointing to the tail of the list.

=head2 next

    my $next = $list->next;

Returns a new list object pointing to the next node, or undef if at end.

=head2 prev

    my $prev = $list->prev;

Returns a new list object pointing to the previous node, or undef if at start.

=head2 is_start

    if ($list->is_start) { ... }

Returns true if the current node is the head of the list.

=head2 is_end

    if ($list->is_end) { ... }

Returns true if the current node is the tail of the list.

=head2 add

    $list->add($data);

Adds a new node with the given data at the end of the list.
Returns $self for chaining.

=head2 bulk_add

    $list->bulk_add(@items);

Adds multiple items to the end of the list.
Returns $self for chaining.

=head2 insert_before

    my $new = $list->insert_before($data);

Inserts a new node before the current node.
Returns a new list object pointing to the inserted node.

=head2 insert_after

    my $new = $list->insert_after($data);

Inserts a new node after the current node.
Returns a new list object pointing to the inserted node.

=head2 insert_at_start

    my $new = $list->insert_at_start($data);

Inserts a new node at the beginning of the list.
Returns a new list object pointing to the inserted node.

=head2 insert_at_end

    my $new = $list->insert_at_end($data);

Inserts a new node at the end of the list.
Returns a new list object pointing to the inserted node.

=head2 insert_at_pos

    my $new = $list->insert_at_pos($pos, $data);

Inserts a new node at the specified position.
Returns a new list object pointing to the inserted node.

=head2 remove

    my $data = $list->remove;

Removes the current node and returns its data.
The list object is updated to point to the next (or previous) node.

=head2 remove_from_start

    my $data = $list->remove_from_start;

Removes the head node and returns its data.

=head2 remove_from_end

    my $data = $list->remove_from_end;

Removes the tail node and returns its data.

=head2 remove_from_pos

    my $data = $list->remove_from_pos($pos);

Removes the node at the specified position and returns its data.

=head2 find

    my $found = $list->find(sub { $_[0] eq "target" });

Searches for a node matching the callback.
Returns a new list object pointing to the found node, or undef if not found.

=head2 insert

    $list->insert(sub { $_[0] > $value }, $data);

Inserts data before the first node where the callback returns true.
If no match is found, inserts at the end.
Returns $self.

=head2 destroy

    $list->destroy;

Explicitly destroys the list and frees all nodes.

=head1 THREADS

B<This module is NOT thread-safe.> Lists cannot be shared across threads.

When a new thread is created, any C<doubly> objects in scope will become
unblessed references in the child thread and cannot be used. Each thread
must create its own lists.

    use threads;
    use doubly;

    my $list = doubly->new();
    $list->add(42);

    my $t = threads->create(sub {
        # $list is an unblessed reference here - cannot use it!
        # Create a new list in this thread instead:
        my $thread_list = doubly->new();
        $thread_list->add(1);
        return $thread_list->length;
    });
    my $result = $t->join;

    # $list still works in parent thread
    print $list->data;  # Prints: 42

=head1 AUTHOR

LNATION

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
