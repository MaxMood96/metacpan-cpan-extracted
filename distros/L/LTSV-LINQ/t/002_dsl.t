######################################################################
#
# t/002_dsl.t - DSL syntax tests
#
######################################################################

BEGIN {
    unshift @INC, 'lib';
    $| = 1;
    print "1..6\n";
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
    {status => 200, url => '/home'},
    {status => 404, url => '/missing'},
    {status => 200, url => '/about'},
    {status => 500, url => '/error'},
);

# Test 1: Single condition DSL
my @res1 = LTSV::LINQ->From(\@data)
    ->Where(status => 200)
    ->ToArray();
ok(@res1 == 2, 'DSL single condition works');

# Test 2: Multiple conditions DSL
my @res2 = LTSV::LINQ->From(\@data)
    ->Where(status => 200, url => '/home')
    ->ToArray();
ok(@res2 == 1 && $res2[0]{url} eq '/home', 'DSL multiple conditions work');

# Test 3: Code reference still works
my @res3 = LTSV::LINQ->From(\@data)
    ->Where(sub { $_[0]{status} == 200 })
    ->ToArray();
ok(@res3 == 2, 'Code reference still works with DSL');

# Test 4: DSL with chaining
my @res4 = LTSV::LINQ->From(\@data)
    ->Where(status => 200)
    ->Select(sub { $_[0]{url} })
    ->ToArray();
ok(@res4 == 2 && $res4[0] eq '/home', 'DSL chains correctly');

# Test 5: DSL finds nothing
my @res5 = LTSV::LINQ->From(\@data)
    ->Where(status => 999)
    ->ToArray();
ok(@res5 == 0, 'DSL returns empty when no match');

# Test 6: DSL with string values
my @res6 = LTSV::LINQ->From(\@data)
    ->Where(url => '/about')
    ->ToArray();
ok(@res6 == 1 && $res6[0]{status} == 200, 'DSL works with string values');
