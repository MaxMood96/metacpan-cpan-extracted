#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese timethese :hireswallclock);
use FindBin qw($Bin);
use lib "$Bin/../blib/lib", "$Bin/../blib/arch";
use feature 'fc';

use Stefo;

print "=" x 75, "\n";
print "Advanced Stefo Benchmark\n";
print "=" x 75, "\n\n";

# =============================================================================
# Test 1: Raw check overhead (single value, many iterations)
# =============================================================================
print "Test 1: Raw check overhead (single value)\n";
print "-" x 60, "\n";

{
    my $sub = sub { $_ > 50 };
    my $compiled = Stefo::compile($sub);
    my $val = 75;

    cmpthese(-3, {
        'perl_sub' => sub {
            local $_ = $val;
            $sub->();
        },
        'stefo' => sub {
            Stefo::check($compiled, $val);
        },
    });
}
print "\n";

# =============================================================================
# Test 2: grep over array (where Stefo shines - no $_ setup per iteration)
# =============================================================================
print "Test 2: grep over 10,000 element array\n";
print "-" x 60, "\n";

{
    my @data = (1..10_000);
    my $sub = sub { $_ > 5000 };
    my $compiled = Stefo::compile($sub);

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { $_ > 5000 } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 3: Complex boolean expression
# =============================================================================
print "Test 3: Complex boolean ((\$_ > 100 && \$_ < 300) || (\$_ > 700 && \$_ < 900))\n";
print "-" x 60, "\n";

{
    my @data = (1..1000);
    my $sub = sub { ($_ > 100 && $_ < 300) || ($_ > 700 && $_ < 900) };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { ($_ > 100 && $_ < 300) || ($_ > 700 && $_ < 900) } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 4: String operations
# =============================================================================
print "Test 4: String length check (length(\$_) > 15)\n";
print "-" x 60, "\n";

{
    my @data = map { "string_" . ("x" x ($_ % 30)) } (1..1000);
    my $sub = sub { length($_) > 15 };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { length($_) > 15 } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 5: Regex matching
# =============================================================================
print "Test 5: Regex match (\$_ =~ /^item_\\d{3}\$/)\n";
print "-" x 60, "\n";

{
    my @data = map { "item_" . sprintf("%03d", $_ % 1000) } (1..1000);
    push @data, map { "other_$_" } (1..500);
    my $sub = sub { $_ =~ /^item_\d{3}$/ };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { /^item_\d{3}$/ } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 6: Reference type checking
# =============================================================================
print "Test 6: Reference type (ref(\$_) eq 'HASH')\n";
print "-" x 60, "\n";

{
    my @data = map { $_ % 3 == 0 ? {} : $_ % 3 == 1 ? [] : \$_ } (1..1000);
    my $sub = sub { ref($_) eq 'HASH' };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { ref($_) eq 'HASH' } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 7: Arithmetic expression
# =============================================================================
print "Test 7: Arithmetic (\$_ * 2 + 10 > 100)\n";
print "-" x 60, "\n";

{
    my @data = (1..1000);
    my $sub = sub { $_ * 2 + 10 > 100 };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { $_ * 2 + 10 > 100 } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 8: Defined check with complex data
# =============================================================================
print "Test 8: Defined check with sparse data\n";
print "-" x 60, "\n";

{
    my @data = map { $_ % 5 == 0 ? undef : $_ } (1..1000);
    my $sub = sub { defined($_) && $_ > 500 };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { defined($_) && $_ > 500 } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 9: Case-insensitive string comparison
# =============================================================================
print "Test 9: Case-insensitive (fc(\$_) eq 'target')\n";
print "-" x 60, "\n";

{
    my @data = map { $_ % 100 == 0 ? 'TARGET' : $_ % 50 == 0 ? 'Target' : "item_$_" } (1..1000);
    my $sub = sub { fc($_) eq 'target' };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { fc($_) eq 'target' } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 10: Bitwise operations
# =============================================================================
print "Test 10: Bitwise ((\$_ & 0x0F) == 0x0F)\n";
print "-" x 60, "\n";

{
    my @data = (0..1000);
    my $sub = sub { ($_ & 0x0F) == 0x0F };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { ($_ & 0x0F) == 0x0F } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 11: Very large dataset
# =============================================================================
print "Test 11: Large dataset (100,000 elements)\n";
print "-" x 60, "\n";

{
    my @data = (1..100_000);
    my $sub = sub { $_ > 50_000 };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { $_ > 50_000 } @data;
        },
    });
}
print "\n";

# =============================================================================
# Test 12: Hash element access
# =============================================================================
print "Test 12: Hash element access (\$_->{status} eq 'active')\n";
print "-" x 60, "\n";

{
    my @data = map { { id => $_, status => $_ % 3 == 0 ? 'active' : 'inactive' } } (1..1000);
    my $sub = sub { $_->{status} eq 'active' };
    my $compiled = Stefo::compile($sub);

    printf "Optimized: %s\n", Stefo::is_optimized($compiled) ? "YES" : "NO";

    cmpthese(-3, {
        'perl_grep' => sub {
            my @r = grep { $sub->() } @data;
        },
        'stefo_grep' => sub {
            my @r = grep { Stefo::check($compiled, $_) } @data;
        },
        'native_grep' => sub {
            my @r = grep { $_->{status} eq 'active' } @data;
        },
    });
}
print "\n";

print "=" x 75, "\n";
print "Legend:\n";
print "  perl_grep   = grep { \$compiled_sub->() } \@data\n";
print "  stefo_grep  = grep { Stefo::check(\$compiled, \$_) } \@data\n";
print "  native_grep = grep { <inline expression> } \@data\n";
print "=" x 75, "\n";
