use strict;
use warnings;
use Test::More;
use const;

ok(1, 'use const');

# c() returns a readonly value - useful for refs and direct use
# Note: my $x = c(42) copies the value, so $x itself isn't readonly
# Use const() for making scalar variables readonly

# Test c() with reference (this is where c() shines)
{
    my $ref = const::c({ a => 1, b => [2, 3] });
    is($ref->{a}, 1, 'c() works with hashrefs');
    is($ref->{b}[0], 2, 'c() works with nested refs');
    
    eval { $ref->{a} = 99 };
    like($@, qr/read-only/, 'c() hashref is deeply readonly');
    
    eval { $ref->{b}[0] = 99 };
    like($@, qr/read-only/, 'c() nested array is readonly');
}

# Test c() with arrayref
{
    my $arr = const::c([1, 2, { x => 3 }]);
    is($arr->[0], 1, 'c() array element accessible');
    is($arr->[2]{x}, 3, 'c() nested hash accessible');
    
    eval { $arr->[0] = 99 };
    like($@, qr/read-only/, 'c() arrayref is readonly');
    
    eval { $arr->[2]{x} = 99 };
    like($@, qr/read-only/, 'c() nested hash in array is readonly');
}

# For scalars, use const() which takes a reference via prototype
{
    const::const(my $x => 42);
    is($x, 42, 'const() sets scalar value');
    
    eval { $x = 99 };
    like($@, qr/read-only/, 'const() scalar IS readonly');
}

done_testing;
