use strict;
use warnings;
use Test::More tests => 10;

use slot qw(counter items);
use util qw(is_array is_num memo);

# Test slot with util predicates

# Initialize slots
counter(0);
items([]);

# Test slot values with predicates
ok(is_num(counter()) ? 1 : 0, 'slot counter is number');
ok(is_array(items()) ? 1 : 0, 'slot items is array');

# Update and verify
counter(42);
is(counter(), 42, 'counter updated');
ok(is_num(counter()) ? 1 : 0, 'still a number after update');

# Test memoized function that uses slots
my $call_count = 0;
my $get_double = memo(sub {
    my $n = shift;
    $call_count++;
    return $n * 2;
});

counter(5);
my $doubled = $get_double->(counter());
is($doubled, 10, 'memoized function works with slot value');
is($call_count, 1, 'function called once');

# Same value should use cache
my $doubled2 = $get_double->(counter());
is($doubled2, 10, 'same result');
is($call_count, 1, 'function not called again (memoized)');

# Different value calls function again
counter(7);
my $doubled3 = $get_double->(counter());
is($doubled3, 14, 'new value computed');
is($call_count, 2, 'function called for new value');
