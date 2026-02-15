######################################################################
#
# t/004_grouping.t - Grouping and aggregation tests
#
######################################################################

BEGIN {
    unshift @INC, 'lib';
    $| = 1;
    print "1..8\n";
}

use LTSV::LINQ;

my $testno = 1;

sub ok {
    my($test, $name) = @_;
    printf "%s %d - %s\n", ($test ? 'ok' : 'not ok'), $testno++, $name || '';
    return $test;
}

# Test data
my @data = (
    {category => 'A', value => 10},
    {category => 'B', value => 20},
    {category => 'A', value => 30},
    {category => 'B', value => 40},
    {category => 'C', value => 50},
);

# Test 1: GroupBy creates groups
my @groups = LTSV::LINQ->From(\@data)
    ->GroupBy(sub { $_[0]{category} })
    ->ToArray();
ok(@groups == 3, 'GroupBy creates correct number of groups');

# Test 2: Group keys are correct
my %keys = map { $_->{Key} => 1 } @groups;
ok($keys{A} && $keys{B} && $keys{C}, 'GroupBy creates correct keys');

# Test 3: Group elements are correct
my($group_a) = grep { $_->{Key} eq 'A' } @groups;
ok(scalar(@{$group_a->{Elements}}) == 2, 'GroupBy groups elements correctly');

# Test 4: Aggregation with grouping
my @stats = LTSV::LINQ->From(\@data)
    ->GroupBy(sub { $_[0]{category} })
    ->Select(sub {
        my $g = shift;
        my $sum = 0;
        $sum += $_->{value} for @{$g->{Elements}};
        return {
            Category => $g->{Key},
            Total => $sum,
        };
    })
    ->ToArray();

my($stat_a) = grep { $_->{Category} eq 'A' } @stats;
ok($stat_a->{Total} == 40, 'Aggregation with grouping works');

# Test 5: Distinct
my @values = LTSV::LINQ->From([1, 2, 2, 3, 3, 3, 4])->Distinct()->ToArray();
ok(@values == 4, 'Distinct removes duplicates');

# Test 6: Distinct with comparer
my @data2 = (
    {id => 1, name => 'A'},
    {id => 2, name => 'B'},
    {id => 1, name => 'C'},
);
my @distinct = LTSV::LINQ->From(\@data2)
    ->Distinct(sub { $_[0]{id} })
    ->ToArray();
ok(@distinct == 2, 'Distinct with comparer works');

# Test 7: TakeWhile
my @taken = LTSV::LINQ->From([1, 2, 3, 4, 5])
    ->TakeWhile(sub { $_[0] < 4 })
    ->ToArray();
ok(@taken == 3 && $taken[2] == 3, 'TakeWhile works correctly');

# Test 8: Reverse
my @reversed = LTSV::LINQ->From([1, 2, 3])->Reverse()->ToArray();
ok($reversed[0] == 3 && $reversed[2] == 1, 'Reverse works correctly');
