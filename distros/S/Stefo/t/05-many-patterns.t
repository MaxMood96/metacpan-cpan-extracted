#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 18;

use Stefo;

# =============================================================================
# Many Patterns - Testing Complex Subs with Multiple Conditions
# =============================================================================

# Many AND conditions (linear - doesn't grow stack depth)
{
    my $many_and = Stefo::compile(sub {
        $_ > 0 && $_ < 1000 && $_ != 13 && $_ != 666 && $_ != 999
    });
    ok(Stefo::is_optimized($many_and), "5 AND conditions optimized");
    ok(Stefo::check($many_and, 500), "500 passes all conditions");
    ok(!Stefo::check($many_and, 13), "13 excluded");
    ok(!Stefo::check($many_and, 666), "666 excluded");
    ok(!Stefo::check($many_and, 999), "999 excluded");
    ok(!Stefo::check($many_and, -1), "negative excluded");
}

# Many OR conditions (linear - doesn't grow stack depth)
{
    my $many_or = Stefo::compile(sub {
        $_ == 1 || $_ == 2 || $_ == 3 || $_ == 5 || $_ == 8 || $_ == 13
    });
    ok(Stefo::is_optimized($many_or), "6 OR conditions optimized");
    ok(Stefo::check($many_or, 1), "1 matches");
    ok(Stefo::check($many_or, 5), "5 matches");
    ok(Stefo::check($many_or, 13), "13 matches");
    ok(!Stefo::check($many_or, 4), "4 doesn't match");
    ok(!Stefo::check($many_or, 100), "100 doesn't match");
}

# Mixed complex expression
{
    my $complex = Stefo::compile(sub {
        ($_ > 0 && $_ < 10) || ($_ > 100 && $_ < 200) || $_ == 999
    });
    ok(Stefo::is_optimized($complex), "complex grouped conditions optimized");
    ok(Stefo::check($complex, 5), "5 in first range");
    ok(Stefo::check($complex, 150), "150 in second range");
    ok(Stefo::check($complex, 999), "999 special value");
    ok(!Stefo::check($complex, 50), "50 in no range");
}

# Instruction count scales with complexity
{
    my $simple = Stefo::compile(sub { $_ > 0 });
    my $medium = Stefo::compile(sub { $_ > 0 && $_ < 100 });
    my $complex = Stefo::compile(sub { $_ > 0 && $_ < 100 && $_ != 50 && $_ != 25 });

    my $s = Stefo::instruction_count($simple);
    my $m = Stefo::instruction_count($medium);
    my $c = Stefo::instruction_count($complex);

    ok($s < $m && $m < $c, "instruction count grows: $s < $m < $c");
}
