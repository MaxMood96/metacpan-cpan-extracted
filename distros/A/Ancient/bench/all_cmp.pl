#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use List::Util ();
use util qw(all_gt all_lt all_ge all_le all_eq all_ne);

print "=" x 60, "\n";
print "all_* - Specialized All Comparison Benchmark\n";
print "=" x 60, "\n\n";

my @numbers = 1..1000;

print "=== all_gt (all match) ===\n";
cmpthese(-2, {
    'util::all_gt'    => sub { all_gt(\@numbers, 0) },
    'List::Util::all' => sub { List::Util::all { $_ > 0 } @numbers },
});

print "\n=== all_lt (fail at end) ===\n";
cmpthese(-2, {
    'util::all_lt'    => sub { all_lt(\@numbers, 1000) },
    'List::Util::all' => sub { List::Util::all { $_ < 1000 } @numbers },
});

print "\n=== all_ge (fail early) ===\n";
cmpthese(-2, {
    'util::all_ge'    => sub { all_ge(\@numbers, 500) },
    'List::Util::all' => sub { List::Util::all { $_ >= 500 } @numbers },
});

print "\n=== all_ge (hash - all adults) ===\n";
my @adults = map { { id => $_, age => 18 + int(rand(50)) } } 1..1000;
cmpthese(-2, {
    'util::all_ge'    => sub { all_ge(\@adults, 'age', 18) },
    'List::Util::all' => sub { List::Util::all { $_->{age} >= 18 } @adults },
});

print "\nDONE\n";
