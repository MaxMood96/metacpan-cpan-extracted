#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(time);
use FindBin qw($Bin);
use lib "$Bin/../blib/lib", "$Bin/../blib/arch";

use Stefo;

# Quick benchmark - run each test N iterations and report times

my $iterations = 100_000;
my @data = (1..100);

print "Quick Benchmark: $iterations iterations each\n";
print "=" x 60, "\n\n";

my @tests = (
    ['$_ > 50',              sub { $_ > 50 }],
    ['$_ == 42',             sub { $_ == 42 }],
    ['$_ >= 10 && $_ <= 90', sub { $_ >= 10 && $_ <= 90 }],
    ['defined($_)',          sub { defined($_) }],
    ['$_ % 2 == 0',          sub { $_ % 2 == 0 }],
);

printf "%-30s %12s %12s %10s\n", "Pattern", "Perl (ms)", "Stefo (ms)", "Speedup";
print "-" x 60, "\n";

for my $test (@tests) {
    my ($name, $sub) = @$test;
    my $compiled = Stefo::compile($sub);

    # Warm up
    for (1..1000) {
        for my $val (@data) { $sub->() for local $_ = $val; }
        for my $val (@data) { Stefo::check($compiled, $val); }
    }

    # Time Perl sub
    my $t0 = time();
    for (1..$iterations) {
        for my $val (@data) {
            local $_ = $val;
            $sub->();
        }
    }
    my $perl_time = (time() - $t0) * 1000;

    # Time Stefo
    $t0 = time();
    for (1..$iterations) {
        for my $val (@data) {
            Stefo::check($compiled, $val);
        }
    }
    my $stefo_time = (time() - $t0) * 1000;

    my $speedup = $perl_time / $stefo_time;
    printf "%-30s %12.2f %12.2f %9.2fx\n", $name, $perl_time, $stefo_time, $speedup;
}

print "\n";
