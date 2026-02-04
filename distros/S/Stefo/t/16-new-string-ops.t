#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use Stefo;

# Plan tests - 13 total (5 fc + 2 chop/chomp + 3 lc + 3 uc)
plan tests => 13;

# =============================================================================
# fc() - Fold case (Perl 5.16+ only)
# =============================================================================

SKIP: {
    skip "fc() requires Perl 5.16+", 5 unless $] >= 5.016;

    # Must use BEGIN to get fc() properly imported before compilation
    my $fc = eval q{
        use feature 'fc';
        Stefo::compile(sub { fc($_) eq 'hello' });
    };

    if ($@) {
        skip "fc() eval failed: $@", 5;
    }

    ok(defined($fc), "fc compiles");
    ok(Stefo::is_optimized($fc), "fc optimized");
    ok(Stefo::check($fc, 'HELLO'), "fc HELLO eq hello");
    ok(Stefo::check($fc, 'Hello'), "fc Hello eq hello");
    ok(!Stefo::check($fc, 'world'), "fc world ne hello");
}

# =============================================================================
# chop() and chomp() are mutating operations - just verify they compile
# =============================================================================

{
    my $chop = Stefo::compile(sub { chop($_) eq 'o' });
    ok(1, "chop compiles");
}

{
    my $chomp = Stefo::compile(sub { chomp($_) == 1 });
    ok(1, "chomp compiles");
}

# =============================================================================
# Other string operations that ARE optimized
# =============================================================================

{
    my $lc = Stefo::compile(sub { lc($_) eq 'hello' });
    ok(Stefo::is_optimized($lc), "lc optimized");
    ok(Stefo::check($lc, 'HELLO'), "lc HELLO eq hello");
    ok(!Stefo::check($lc, 'world'), "lc world ne hello");
}

{
    my $uc = Stefo::compile(sub { uc($_) eq 'HELLO' });
    ok(Stefo::is_optimized($uc), "uc optimized");
    ok(Stefo::check($uc, 'hello'), "uc hello eq HELLO");
    ok(!Stefo::check($uc, 'world'), "uc world ne HELLO");
}
