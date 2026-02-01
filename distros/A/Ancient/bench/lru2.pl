#!/usr/bin/perl
use strict;
use warnings;
use lib 'blib/lib', 'blib/arch';
use lru qw(import);
use Time::HiRes qw(time);

my $cache = lru::new(10000);
my $iters = 5_000_000;

# Prefill
for (1..1000) { $cache->set("key$_", $_); }

# Benchmark lru_set function-style
my $t1 = time;
for (1..$iters) { lru_set($cache, "bench", $_); }
my $t2 = time;
my $func_set_ops = $iters / ($t2 - $t1);

# Benchmark method-style
$t1 = time;
for (1..$iters) { $cache->set("bench2", $_); }
$t2 = time;
my $meth_set_ops = $iters / ($t2 - $t1);

printf "lru_set function: %.2fM ops/sec\n", $func_set_ops / 1_000_000;
printf "cache->set method: %.2fM ops/sec\n", $meth_set_ops / 1_000_000;
printf "SET speedup: %.0f%%\n\n", (($func_set_ops / $meth_set_ops) - 1) * 100;

# Benchmark lru_get function-style
$t1 = time;
for (1..$iters) { lru_get($cache, "bench"); }
$t2 = time;
my $func_get_ops = $iters / ($t2 - $t1);

# Benchmark method-style
$t1 = time;
for (1..$iters) { $cache->get("bench2"); }
$t2 = time;
my $meth_get_ops = $iters / ($t2 - $t1);

printf "lru_get function: %.2fM ops/sec\n", $func_get_ops / 1_000_000;
printf "cache->get method: %.2fM ops/sec\n", $meth_get_ops / 1_000_000;
printf "GET speedup: %.0f%%\n\n", (($func_get_ops / $meth_get_ops) - 1) * 100;

# Benchmark lru_exists
$t1 = time;
for (1..$iters) { lru_exists($cache, "bench"); }
$t2 = time;
my $func_exists_ops = $iters / ($t2 - $t1);

$t1 = time;
for (1..$iters) { $cache->exists("bench2"); }
$t2 = time;
my $meth_exists_ops = $iters / ($t2 - $t1);

printf "lru_exists function: %.2fM ops/sec\n", $func_exists_ops / 1_000_000;
printf "cache->exists method: %.2fM ops/sec\n", $meth_exists_ops / 1_000_000;
printf "EXISTS speedup: %.0f%%\n", (($func_exists_ops / $meth_exists_ops) - 1) * 100;
