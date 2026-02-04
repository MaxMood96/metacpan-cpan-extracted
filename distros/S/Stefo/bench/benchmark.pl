#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese timethese);
use FindBin qw($Bin);
use lib "$Bin/../blib/lib", "$Bin/../blib/arch";

use Stefo;

print "=" x 70, "\n";
print "Stefo Benchmark: Optimized Bytecode vs Normal Perl Sub Calling\n";
print "=" x 70, "\n\n";

# Test data
my @numbers = (1..1000);
my @strings = map { "string_$_" } (1..1000);
my @mixed = map { $_ % 2 ? $_ : "str_$_" } (1..1000);

# =============================================================================
# Benchmark 1: Simple numeric comparison
# =============================================================================
print "Benchmark 1: Numeric comparison (\$_ > 500)\n";
print "-" x 50, "\n";

my $num_sub = sub { $_ > 500 };
my $num_compiled = Stefo::compile($num_sub);

printf "Optimized: %s\n", Stefo::is_optimized($num_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $num_sub->() } @numbers;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($num_compiled, $_) } @numbers;
    },
});
print "\n";

# =============================================================================
# Benchmark 2: String equality
# =============================================================================
print "Benchmark 2: String equality (\$_ eq 'string_500')\n";
print "-" x 50, "\n";

my $str_sub = sub { $_ eq 'string_500' };
my $str_compiled = Stefo::compile($str_sub);

printf "Optimized: %s\n", Stefo::is_optimized($str_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $str_sub->() } @strings;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($str_compiled, $_) } @strings;
    },
});
print "\n";

# =============================================================================
# Benchmark 3: Regex match
# =============================================================================
print "Benchmark 3: Regex match (\$_ =~ /^string_[0-9]+\$/)\n";
print "-" x 50, "\n";

my $rx_sub = sub { $_ =~ /^string_[0-9]+$/ };
my $rx_compiled = Stefo::compile($rx_sub);

printf "Optimized: %s\n", Stefo::is_optimized($rx_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $rx_sub->() } @strings;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($rx_compiled, $_) } @strings;
    },
});
print "\n";

# =============================================================================
# Benchmark 4: Compound condition (AND)
# =============================================================================
print "Benchmark 4: Compound AND (\$_ > 100 && \$_ < 900)\n";
print "-" x 50, "\n";

my $and_sub = sub { $_ > 100 && $_ < 900 };
my $and_compiled = Stefo::compile($and_sub);

printf "Optimized: %s\n", Stefo::is_optimized($and_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $and_sub->() } @numbers;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($and_compiled, $_) } @numbers;
    },
});
print "\n";

# =============================================================================
# Benchmark 5: defined check
# =============================================================================
print "Benchmark 5: Defined check (defined(\$_))\n";
print "-" x 50, "\n";

my @with_undef = (@numbers[0..499], (undef) x 500);

my $def_sub = sub { defined($_) };
my $def_compiled = Stefo::compile($def_sub);

printf "Optimized: %s\n", Stefo::is_optimized($def_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $def_sub->() } @with_undef;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($def_compiled, $_) } @with_undef;
    },
});
print "\n";

# =============================================================================
# Benchmark 6: Length check
# =============================================================================
print "Benchmark 6: Length check (length(\$_) > 10)\n";
print "-" x 50, "\n";

my $len_sub = sub { length($_) > 10 };
my $len_compiled = Stefo::compile($len_sub);

printf "Optimized: %s\n", Stefo::is_optimized($len_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $len_sub->() } @strings;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($len_compiled, $_) } @strings;
    },
});
print "\n";

# =============================================================================
# Benchmark 7: Numeric range (common filter pattern)
# =============================================================================
print "Benchmark 7: Numeric range (\$_ >= 200 && \$_ <= 800)\n";
print "-" x 50, "\n";

my $range_sub = sub { $_ >= 200 && $_ <= 800 };
my $range_compiled = Stefo::compile($range_sub);

printf "Optimized: %s\n", Stefo::is_optimized($range_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $range_sub->() } @numbers;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($range_compiled, $_) } @numbers;
    },
});
print "\n";

# =============================================================================
# Benchmark 8: Case-insensitive string match (fc)
# =============================================================================
print "Benchmark 8: Case-insensitive (fc(\$_) eq 'string_500')\n";
print "-" x 50, "\n";

use feature 'fc';
my $fc_sub = sub { fc($_) eq 'string_500' };
my $fc_compiled = Stefo::compile($fc_sub);

printf "Optimized: %s\n", Stefo::is_optimized($fc_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $fc_sub->() } @strings;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($fc_compiled, $_) } @strings;
    },
});
print "\n";

# =============================================================================
# Benchmark 9: Reference type check
# =============================================================================
print "Benchmark 9: Reference type (ref(\$_) eq 'ARRAY')\n";
print "-" x 50, "\n";

my @refs = map { $_ % 3 == 0 ? [] : $_ % 3 == 1 ? {} : \$_ } (1..1000);

my $ref_sub = sub { ref($_) eq 'ARRAY' };
my $ref_compiled = Stefo::compile($ref_sub);

printf "Optimized: %s\n", Stefo::is_optimized($ref_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $ref_sub->() } @refs;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($ref_compiled, $_) } @refs;
    },
});
print "\n";

# =============================================================================
# Benchmark 10: Complex expression
# =============================================================================
print "Benchmark 10: Complex ((\$_ > 100 && \$_ < 500) || \$_ > 900)\n";
print "-" x 50, "\n";

my $complex_sub = sub { ($_ > 100 && $_ < 500) || $_ > 900 };
my $complex_compiled = Stefo::compile($complex_sub);

printf "Optimized: %s\n", Stefo::is_optimized($complex_compiled) ? "YES" : "NO (Perl fallback)";

cmpthese(-2, {
    'perl_sub' => sub {
        my @r = grep { $complex_sub->() } @numbers;
    },
    'stefo_check' => sub {
        my @r = grep { Stefo::check($complex_compiled, $_) } @numbers;
    },
});
print "\n";

print "=" x 70, "\n";
print "Benchmark complete.\n";
print "=" x 70, "\n";
