#!/usr/bin/env perl
use strict;
use warnings;
no warnings 'void';
use Test::More;

# Skip if ps command not available (Windows, minimal docker containers, etc.)
my $ps_available = eval { my $r = `ps -o rss= -p $$ 2>/dev/null`; defined $r && $r =~ /\d/ };
plan skip_all => 'ps command not available' unless $ps_available;

# Extended memory leak tests for const module

use const qw/all/;

plan tests => 12;

# Helper to get current RSS in KB
sub get_rss {
    my $rss = `ps -o rss= -p $$`;
    chomp $rss;
    return $rss + 0;
}

sub test_no_leak {
    my ($name, $code, $iterations, $threshold_kb) = @_;
    $iterations //= 50_000;
    $threshold_kb //= 10_000;
    
    $code->() for 1..500;  # Warmup
    
    my $before = get_rss();
    $code->() for 1..$iterations;
    my $after = get_rss();
    
    my $diff = $after - $before;
    my $passed = $diff < $threshold_kb;
    ok($passed, "$name - memory growth: ${diff}KB");
    diag("LEAK: before=${before}KB after=${after}KB") unless $passed;
}

# Test c() with undef
test_no_leak("c(undef)", sub {
    my $x = const::c(undef);
});

# Test c() with empty arrayref
test_no_leak("c([])", sub {
    my $x = const::c([]);
});

# Test c() with empty hashref
test_no_leak("c({})", sub {
    my $x = const::c({});
});

# Test c() with large array
test_no_leak("c(large array)", sub {
    my $x = const::c([1..100]);
}, 20_000);

# Test c() with large hash
test_no_leak("c(large hash)", sub {
    my $x = const::c({ map { $_ => $_ } 1..50 });
}, 20_000);

# Test deeply nested structure
test_no_leak("c(deep nest)", sub {
    my $x = const::c({
        l1 => {
            l2 => {
                l3 => [1, 2, { l4 => 'deep' }]
            }
        }
    });
}, 20_000);

# Test const with large arrays
test_no_leak("const large array", sub {
    const my @arr => (1..100);
}, 20_000);

# Test const with large hash
test_no_leak("const large hash", sub {
    const my %h => map { $_ => $_ } 1..50;
}, 20_000);

# Test is_readonly on various types
my $scalar = const::c(42);
my $aref = const::c([1,2,3]);
my $href = const::c({a=>1});

test_no_leak("is_readonly scalar", sub {
    my $r = is_readonly($scalar);
});

test_no_leak("is_readonly arrayref", sub {
    my $r = is_readonly($aref);
});

test_no_leak("is_readonly hashref", sub {
    my $r = is_readonly($href);
});

# Test make_readonly/unmake_readonly cycle on refs
test_no_leak("readonly cycle on ref", sub {
    my $x = { a => [1, 2, 3] };
    make_readonly($x);
    unmake_readonly($x);
}, 20_000);

done_testing();
