use strict;
use warnings;
use Test::More;
use const;

ok(1, 'use const');

# Test const() with scalar
{
    const::const(my $x => 42);
    is($x, 42, 'const() sets scalar value');
    
    eval { $x = 99 };
    like($@, qr/read-only/, 'const() scalar is readonly');
}

# Test const() with array
{
    const::const(my @arr => qw/a b c/);
    is_deeply(\@arr, [qw/a b c/], 'const() sets array value');
    
    eval { $arr[0] = 'x' };
    like($@, qr/read-only/, 'const() array is readonly');
    
    eval { push @arr, 'd' };
    like($@, qr/read-only/, 'const() array cannot be modified');
}

# Test const() with hash
{
    const::const(my %h => (one => 1, two => 2));
    is($h{one}, 1, 'const() sets hash value');
    is($h{two}, 2, 'const() sets hash value');
    
    eval { $h{one} = 99 };
    like($@, qr/read-only/, 'const() hash is readonly');
    
    eval { $h{three} = 3 };
    like($@, qr/read-only|disallowed key|restricted hash/, 'const() hash cannot add keys');
}

# Test const() with nested structures
{
    const::const(my %config => (
        debug => 1,
        nested => { a => 1, b => [2, 3] },
    ));
    
    is($config{nested}{a}, 1, 'const() nested access works');
    
    eval { $config{nested}{a} = 99 };
    like($@, qr/read-only/, 'const() nested hash is readonly');
    
    eval { $config{nested}{b}[0] = 99 };
    like($@, qr/read-only/, 'const() deeply nested is readonly');
}

done_testing;
