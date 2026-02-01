use strict;
use warnings;
use Test::More;

use_ok('const');

# Test that c() with literals should be compile-time optimized
# We can't easily test that it's optimized, but we can test it works

{
    # These should all work (potentially constant-folded at compile time)
    my $int = const::c(42);
    my $float = const::c(3.14159);
    my $str = const::c("constant string");
    my $sq = const::c('single quoted');
    
    is($int, 42, 'integer constant works');
    is($float, 3.14159, 'float constant works');
    is($str, "constant string", 'double-quoted string works');
    is($sq, "single quoted", 'single-quoted string works');
}

# Test with reference - this IS readonly
{
    my $ref = const::c({ key => "value" });
    is($ref->{key}, "value", 'c() ref works');
    
    eval { $ref->{key} = "changed" };
    like($@, qr/read-only/, 'c() ref contents are readonly');
}

# We can use B to check if it's really constant-folded
SKIP: {
    eval { require B };
    skip "B module not available", 1 if $@;
    
    # This is a basic sanity check - a fully optimized c() with literal
    # should become just a const op, not a full entersub
    my $code = sub { const::c(42) };
    my $cv = B::svref_2object($code);
    my $root = $cv->ROOT;
    
    # Just verify the code compiles and runs
    my $result = $code->();
    is($result, 42, 'c() in sub returns correct value');
}

done_testing;
