#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 50;

use Stefo;

# =============================================================================
# Fallback Behavior for Unsupported Patterns
# =============================================================================

# Complex expressions that can't be optimized should still work via fallback
{
    # Using a variable (not $_) - should not be optimized but should work
    my $x = 10;
    my $sub = Stefo::compile(sub { $x > 5 });
    ok(defined $sub, "non-optimizable sub compiles");
    # The fallback should still execute the original sub correctly
}

# =============================================================================
# Boundary Values
# =============================================================================

# Maximum integer-like values
{
    my $big = Stefo::compile(sub { $_ > 1000000 });
    ok(Stefo::is_optimized($big), "large number comparison optimized");
    ok(Stefo::check($big, 1000001), "1000001 > 1000000 is true");
    ok(!Stefo::check($big, 1000000), "1000000 > 1000000 is false");
    ok(!Stefo::check($big, 999999), "999999 > 1000000 is false");
}

# Very small floating point
{
    my $tiny = Stefo::compile(sub { $_ < 0.0001 });
    ok(Stefo::is_optimized($tiny), "tiny float comparison optimized");
    ok(Stefo::check($tiny, 0.00001), "0.00001 < 0.0001 is true");
    ok(!Stefo::check($tiny, 0.0001), "0.0001 < 0.0001 is false");
    ok(!Stefo::check($tiny, 0.001), "0.001 < 0.0001 is false");
}

# =============================================================================
# String Edge Cases
# =============================================================================

# String with special characters
{
    my $special = Stefo::compile(sub { $_ eq 'hello world' });
    ok(Stefo::is_optimized($special), "string with space optimized");
    ok(Stefo::check($special, 'hello world'), "'hello world' matches");
    ok(!Stefo::check($special, 'helloworld'), "'helloworld' doesn't match");
}

# String with numbers (string comparison)
{
    my $numstr = Stefo::compile(sub { $_ eq '123' });
    ok(Stefo::is_optimized($numstr), "numeric string comparison optimized");
    ok(Stefo::check($numstr, '123'), "'123' eq '123' is true");
    ok(!Stefo::check($numstr, '124'), "'124' eq '123' is false");
}

# Regex with special regex characters
{
    my $dots = Stefo::compile(sub { $_ =~ /\.txt$/ });
    ok(Stefo::is_optimized($dots), "regex with escaped dot optimized");
    ok(Stefo::check($dots, 'file.txt'), "'file.txt' matches /\\.txt\$/");
    ok(!Stefo::check($dots, 'filetxt'), "'filetxt' doesn't match");
}

# Regex with alternation
{
    my $alt = Stefo::compile(sub { $_ =~ /foo|bar/ });
    ok(Stefo::is_optimized($alt), "regex with alternation optimized");
    ok(Stefo::check($alt, 'foo'), "'foo' matches /foo|bar/");
    ok(Stefo::check($alt, 'bar'), "'bar' matches /foo|bar/");
    ok(Stefo::check($alt, 'foobar'), "'foobar' matches /foo|bar/");
    ok(!Stefo::check($alt, 'baz'), "'baz' doesn't match /foo|bar/");
}

# Regex with character class
{
    my $digits = Stefo::compile(sub { $_ =~ /^\d+$/ });
    ok(Stefo::is_optimized($digits), "regex with \\d+ optimized");
    ok(Stefo::check($digits, '123'), "'123' matches /^\\d+\$/");
    ok(Stefo::check($digits, '0'), "'0' matches /^\\d+\$/");
    ok(!Stefo::check($digits, 'abc'), "'abc' doesn't match /^\\d+\$/");
    ok(!Stefo::check($digits, '12a'), "'12a' doesn't match /^\\d+\$/");
}

# =============================================================================
# Complex Logic Expressions
# =============================================================================

# Double negation
{
    my $double_not = Stefo::compile(sub { !!$_ });
    ok(Stefo::is_optimized($double_not), "!! optimized");
    ok(Stefo::check($double_not, 1), "!!1 is true");
    ok(Stefo::check($double_not, 'hello'), "!!'hello' is true");
    ok(!Stefo::check($double_not, 0), "!!0 is false");
    ok(!Stefo::check($double_not, ''), "!!'' is false");
}

# OR with same operator
{
    my $multi_or = Stefo::compile(sub { $_ == 1 || $_ == 2 || $_ == 3 });
    ok(Stefo::is_optimized($multi_or), "multiple OR conditions optimized");
    ok(Stefo::check($multi_or, 1), "1 matches");
    ok(Stefo::check($multi_or, 2), "2 matches");
    ok(Stefo::check($multi_or, 3), "3 matches");
    ok(!Stefo::check($multi_or, 4), "4 doesn't match");
    ok(!Stefo::check($multi_or, 0), "0 doesn't match");
}

# Mixed AND/OR (left associative)
{
    my $mixed = Stefo::compile(sub { $_ > 0 && $_ < 10 || $_ > 90 });
    ok(Stefo::is_optimized($mixed), "mixed AND/OR optimized");
    ok(Stefo::check($mixed, 5), "5: in first range");
    ok(Stefo::check($mixed, 95), "95: in second range");
    ok(!Stefo::check($mixed, 50), "50: in neither range");
    ok(!Stefo::check($mixed, 0), "0: excluded from first range");
}

# =============================================================================
# Instruction Count Verification
# =============================================================================

{
    my $simple = Stefo::compile(sub { $_ > 0 });
    my $complex = Stefo::compile(sub { $_ > 0 && $_ < 100 && $_ != 50 });

    my $simple_count = Stefo::instruction_count($simple);
    my $complex_count = Stefo::instruction_count($complex);

    ok($simple_count > 0, "simple has instructions");
    ok($complex_count > 0, "complex has instructions");
    ok($complex_count > $simple_count, "complex has more instructions than simple");
}

# =============================================================================
# Type Coercion
# =============================================================================

# String used in numeric context
{
    my $gt = Stefo::compile(sub { $_ > 10 });
    ok(Stefo::check($gt, '15'), "'15' > 10 is true (string coerced)");
    ok(!Stefo::check($gt, '5'), "'5' > 10 is false (string coerced)");
}

# Number used in string context
{
    my $eq = Stefo::compile(sub { $_ eq '42' });
    ok(Stefo::check($eq, 42), "42 eq '42' is true (number coerced)");
}
