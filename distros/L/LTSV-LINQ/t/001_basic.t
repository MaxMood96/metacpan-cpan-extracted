######################################################################
#
# t/001_basic.t - Basic functionality tests
#
######################################################################

BEGIN {
    unshift @INC, 'lib';
    $| = 1;
    print "1..15\n";
}

use LTSV::LINQ;

my $testno = 1;

sub ok {
    my($test, $name) = @_;
    printf "%s %d - %s\n", ($test ? 'ok' : 'not ok'), $testno++, $name || '';
    return $test;
}

# Test 1: Module loading
ok(1, 'LTSV::LINQ module loaded');

# Test 2: From array
my $q1 = LTSV::LINQ->From([1, 2, 3, 4, 5]);
ok(defined($q1), 'From creates query object');

# Test 3: ToArray
my @arr1 = $q1->ToArray();
ok(@arr1 == 5, 'ToArray returns correct count');

# Test 4: Range
my @range = LTSV::LINQ->Range(1, 5)->ToArray();
ok($range[0] == 1 && $range[4] == 5, 'Range generates correct sequence');

# Test 5: Where with code reference
my @filtered = LTSV::LINQ->From([1, 2, 3, 4, 5])
    ->Where(sub { $_[0] > 2 })
    ->ToArray();
ok(@filtered == 3 && $filtered[0] == 3, 'Where filters correctly');

# Test 6: Select
my @doubled = LTSV::LINQ->From([1, 2, 3])
    ->Select(sub { $_[0] * 2 })
    ->ToArray();
ok($doubled[0] == 2 && $doubled[2] == 6, 'Select transforms correctly');

# Test 7: Take
my @taken = LTSV::LINQ->From([1, 2, 3, 4, 5])
    ->Take(3)
    ->ToArray();
ok(@taken == 3, 'Take limits correctly');

# Test 8: Skip
my @skipped = LTSV::LINQ->From([1, 2, 3, 4, 5])
    ->Skip(2)
    ->ToArray();
ok(@skipped == 3 && $skipped[0] == 3, 'Skip works correctly');

# Test 9: OrderBy
my @sorted = LTSV::LINQ->From([3, 1, 4, 1, 5])
    ->OrderBy(sub { $_[0] })
    ->ToArray();
ok($sorted[0] == 1 && $sorted[4] == 5, 'OrderBy sorts correctly');

# Test 10: OrderByDescending
my @desc = LTSV::LINQ->From([3, 1, 4])
    ->OrderByDescending(sub { $_[0] })
    ->ToArray();
ok($desc[0] == 4 && $desc[2] == 1, 'OrderByDescending sorts correctly');

# Test 11: Count
my $count = LTSV::LINQ->From([1, 2, 3, 4, 5])->Count();
ok($count == 5, 'Count returns correct value');

# Test 12: Sum
my $sum = LTSV::LINQ->From([1, 2, 3, 4, 5])->Sum();
ok($sum == 15, 'Sum calculates correctly');

# Test 13: Min
my $min = LTSV::LINQ->From([3, 1, 4, 1, 5])->Min();
ok($min == 1, 'Min finds minimum');

# Test 14: Max
my $max = LTSV::LINQ->From([3, 1, 4, 1, 5])->Max();
ok($max == 5, 'Max finds maximum');

# Test 15: Average
my $avg = LTSV::LINQ->From([2, 4, 6])->Average();
ok($avg == 4, 'Average calculates correctly');
