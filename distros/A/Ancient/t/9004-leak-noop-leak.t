#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

# Skip if ps command not available (Windows, minimal docker containers, etc.)
my $ps_available = eval { my $r = `ps -o rss= -p $$ 2>/dev/null`; defined $r && $r =~ /\d/ };
plan skip_all => 'ps command not available' unless $ps_available;

# Memory leak tests for noop module

use noop 'noop';

# Helper to get current RSS in KB
sub get_rss {
    my $pid = $$;
    my $rss = `ps -o rss= -p $pid`;
    chomp $rss;
    return $rss + 0;
}

# Helper to test for memory leak
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

# Test noop - should be extremely fast and have zero allocations
test_no_leak("noop()", sub {
    noop();
}, 1_000_000);

# Test noop via full name
test_no_leak("noop::noop()", sub {
    noop::noop();
}, 1_000_000);

# Test as callback
my $callback = \&noop;
test_no_leak("noop as callback", sub {
    $callback->();
}, 1_000_000);

done_testing;
