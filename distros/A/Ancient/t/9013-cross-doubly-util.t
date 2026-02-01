use strict;
use warnings;
use Test::More tests => 10;

use doubly;
use util qw(is_ref first any all);

# Test doubly linked list with util functions

my $list = doubly->new(10);
$list->add(20)->add(30)->add(40)->add(50);

# Test with is_ref
ok(ref($list), 'doubly list is a reference');

# Convert list to array for util functions
sub list_to_array {
    my $l = shift;
    my @arr;
    $l = $l->start;
    while ($l) {
        push @arr, $l->data;
        $l = $l->next;
    }
    return @arr;
}

my @values = list_to_array($list);
is_deeply(\@values, [10, 20, 30, 40, 50], 'list converted to array');

# Test first on list values
my $first_gt_25 = first(sub { $_ > 25 }, @values);
is($first_gt_25, 30, 'first value > 25');

# Test any/all on list values
ok(any(sub { $_ == 30 }, @values) ? 1 : 0, 'any finds 30');
ok(all(sub { $_ >= 10 }, @values) ? 1 : 0, 'all >= 10');
ok(!all(sub { $_ > 20 }, @values), 'not all > 20');

# Store util results in list
my $results = doubly->new();
$results->add(first(sub { $_ > 15 }, @values));
$results->add(first(sub { $_ > 35 }, @values));

$results = $results->start;
is($results->data, 20, 'first result stored');
$results = $results->next;
is($results->data, 40, 'second result stored');

# Test list find with util-style callback pattern
my $found = $list->find(sub { $_[0] > 25 });
ok(defined $found, 'find returns a node');
is($found->data, 30, 'found correct value');
