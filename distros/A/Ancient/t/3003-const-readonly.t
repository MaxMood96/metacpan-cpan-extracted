use strict;
use warnings;
use Test::More;

use_ok('const');

# Test make_readonly
{
    my $x = "original";
    ok(!const::is_readonly(\$x), 'variable starts writable');
    
    const::make_readonly(\$x);
    ok(const::is_readonly(\$x), 'make_readonly makes it readonly');
    
    eval { $x = "changed" };
    like($@, qr/read-only/, 'cannot modify readonly variable');
}

# Test make_readonly on array
{
    my @arr = (1, 2, 3);
    const::make_readonly(\@arr);
    ok(const::is_readonly(\@arr), 'array is readonly');
    
    eval { $arr[0] = 99 };
    like($@, qr/read-only/, 'cannot modify readonly array');
}

# Test make_readonly on hash
{
    my %hash = (a => 1);
    const::make_readonly(\%hash);
    ok(const::is_readonly(\%hash), 'hash is readonly');
    
    eval { $hash{a} = 99 };
    like($@, qr/read-only/, 'cannot modify readonly hash');
}

# Test unmake_readonly
{
    my $y = "frozen";
    const::make_readonly(\$y);
    ok(const::is_readonly(\$y), 'y is readonly');
    
    const::unmake_readonly(\$y);
    ok(!const::is_readonly(\$y), 'y is writable again');
    
    $y = "thawed";
    is($y, "thawed", 'can modify after unmake_readonly');
}

# Test make_readonly_ref
{
    my $ref = const::make_readonly_ref({ key => "value" });
    is($ref->{key}, "value", 'make_readonly_ref returns ref');
    
    eval { $ref->{key} = "new" };
    like($@, qr/read-only/, 'ref contents are readonly');
    
    # But the variable holding the ref can be changed
    $ref = { other => "thing" };
    is($ref->{other}, "thing", 'variable itself can be reassigned');
}

done_testing;
