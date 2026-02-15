######################################################################
#
# t/005_complex.t - Complex query tests
#
######################################################################

BEGIN {
    unshift @INC, 'lib';
    $| = 1;
    print "1..10\n";
}

use LTSV::LINQ;

my $testno = 1;

sub ok {
    my($test, $name) = @_;
    printf "%s %d - %s\n", ($test ? 'ok' : 'not ok'), $testno++, $name || '';
    return $test;
}

# Test 1: Method chaining
my @result1 = LTSV::LINQ->Range(1, 20)
    ->Where(sub { $_[0] % 2 == 0 })
    ->Select(sub { $_[0] * 2 })
    ->OrderByDescending(sub { $_[0] })
    ->Take(5)
    ->ToArray();
ok(@result1 == 5 && $result1[0] == 40, 'Complex method chaining works');

# Test 2: All quantifier
my $all_even = LTSV::LINQ->From([2, 4, 6, 8])
    ->All(sub { $_[0] % 2 == 0 });
ok($all_even == 1, 'All returns true when all match');

# Test 3: All returns false
my $not_all = LTSV::LINQ->From([1, 2, 3])
    ->All(sub { $_[0] % 2 == 0 });
ok($not_all == 0, 'All returns false when not all match');

# Test 4: Any quantifier
my $has_even = LTSV::LINQ->From([1, 2, 3])
    ->Any(sub { $_[0] % 2 == 0 });
ok($has_even == 1, 'Any returns true when match exists');

# Test 5: Any without predicate
my $is_not_empty = LTSV::LINQ->From([1])->Any();
ok($is_not_empty == 1, 'Any without predicate checks non-empty');

# Test 6: First with predicate
my $first_big = LTSV::LINQ->From([1, 2, 5, 3, 8])
    ->First(sub { $_[0] > 4 });
ok($first_big == 5, 'First with predicate works');

# Test 7: FirstOrDefault when found
my $found = LTSV::LINQ->From([1, 2, 3])
    ->FirstOrDefault(sub { $_[0] > 2 }, 0);
ok($found == 3, 'FirstOrDefault returns found value');

# Test 8: FirstOrDefault with default
my $not_found = LTSV::LINQ->From([1, 2, 3])
    ->FirstOrDefault(sub { $_[0] > 10 }, 99);
ok($not_found == 99, 'FirstOrDefault returns default when not found');

# Test 9: Last
my $last = LTSV::LINQ->From([1, 2, 3, 4, 5])->Last();
ok($last == 5, 'Last returns last element');

# Test 10: SelectMany
my @flattened = LTSV::LINQ->From([
    [1, 2],
    [3, 4],
    [5]
])->SelectMany(sub { $_[0] })->ToArray();
ok(@flattened == 5 && $flattened[0] == 1 && $flattened[4] == 5,
   'SelectMany flattens correctly');
