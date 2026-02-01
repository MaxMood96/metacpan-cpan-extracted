#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'void';
use Test::More;

# Skip if ps command not available (Windows, minimal docker containers, etc.)
my $ps_available = eval { my $r = `ps -o rss= -p $$ 2>/dev/null`; defined $r && $r =~ /\d/ };
plan skip_all => 'ps command not available' unless $ps_available;

# Memory leak tests for const module
# We test that repeated operations don't cause unbounded memory growth

use const qw/all/;

# Helper to get current RSS in KB
sub get_rss {
    my $pid = $$;
    my $rss = `ps -o rss= -p $pid`;
    chomp $rss;
    return $rss + 0;
}

# Helper to test for memory leak
# Runs $code $iterations times, checks memory doesn't grow more than $threshold KB
sub test_no_leak {
    my ($name, $code, $iterations, $threshold) = @_;
    $iterations //= 100_000;
    $threshold //= 10_000;  # 10MB threshold
    
    # Warmup
    $code->() for 1..1000;
    
    my $before = get_rss();
    $code->() for 1..$iterations;
    my $after = get_rss();
    
    my $growth = $after - $before;
    ok($growth < $threshold, "$name: memory growth ${growth}KB < ${threshold}KB threshold");
    
    if ($growth >= $threshold) {
        diag("LEAK DETECTED: $name grew by ${growth}KB after $iterations iterations");
    }
}

# Test c() with scalars
test_no_leak("c(scalar)", sub {
    my $x = const::c(42);
});

# Test c() with strings
test_no_leak("c(string)", sub {
    my $x = const::c("hello world");
});

# Test c() with arrayrefs
test_no_leak("c(arrayref)", sub {
    my $x = const::c([1, 2, 3]);
});

# Test c() with hashrefs  
test_no_leak("c(hashref)", sub {
    my $x = const::c({a => 1, b => 2});
});

# Test c() with nested structures
test_no_leak("c(nested)", sub {
    my $x = const::c({
        arr => [1, 2, 3],
        hash => { deep => 'value' }
    });
});

# Test const() with scalar
test_no_leak("const scalar", sub {
    const my $x => 42;
});

# Test const() with array
test_no_leak("const array", sub {
    const my @arr => (1, 2, 3);
});

# Test const() with hash
test_no_leak("const hash", sub {
    const my %h => (a => 1, b => 2);
});

# Test make_readonly
test_no_leak("make_readonly scalar", sub {
    my $x = 42;
    make_readonly($x);
});

# Test make_readonly with ref
test_no_leak("make_readonly ref", sub {
    my $x = { a => 1 };
    make_readonly($x);
});

# Test unmake_readonly
test_no_leak("unmake_readonly", sub {
    my $x = 42;
    make_readonly($x);
    unmake_readonly($x);
});

# Test is_readonly
const my $readonly_var => 42;
test_no_leak("is_readonly", sub {
    my $r = is_readonly($readonly_var);
});

done_testing;
