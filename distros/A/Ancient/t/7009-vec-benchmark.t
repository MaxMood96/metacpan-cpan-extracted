#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;
use Time::HiRes qw(time);
use lib 'blib/lib', 'blib/arch';

BEGIN { use_ok('nvec') }

# Create a decent-sized vector for benchmarking
my @data = map { rand() } 1..10000;
my $v = nvec::new(\@data);

# Benchmark sum operation (custom op should be fast)
my $iterations = 10000;
my $start = time();
my $result;
for (1..$iterations) {
    $result = $v->sum();
}
my $elapsed = time() - $start;
my $ops_per_sec = int($iterations / $elapsed);

ok($ops_per_sec > 50000, "sum() fast: $ops_per_sec ops/sec (should be >50k with custom ops)");

# Benchmark chained operations
$start = time();
for (1..$iterations) {
    my $x = $v->add($v)->scale(2.0)->sum();
}
$elapsed = time() - $start;
$ops_per_sec = int($iterations / $elapsed);

ok($ops_per_sec > 5000, "chained ops: $ops_per_sec ops/sec");

diag "Benchmark complete - custom ops working efficiently";
