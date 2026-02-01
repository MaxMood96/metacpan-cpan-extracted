#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use List::Util ();
use util qw(first);

print "=" x 60, "\n";
print "first - Find First Matching Element Benchmark\n";
print "=" x 60, "\n\n";

my @numbers = 1..1000;

print "=== Match at position ~500 ===\n";
cmpthese(-2, {
    'util::first'       => sub { first(sub { $_ > 500 }, \@numbers) },
    'List::Util::first' => sub { List::Util::first { $_ > 500 } @numbers },
});

print "\n=== Early match (position 10) ===\n";
cmpthese(-2, {
    'util::first'       => sub { first(sub { $_ > 10 }, \@numbers) },
    'List::Util::first' => sub { List::Util::first { $_ > 10 } @numbers },
});

print "\n=== No match (check all elements) ===\n";
cmpthese(-2, {
    'util::first'       => sub { first(sub { $_ > 2000 }, \@numbers) },
    'List::Util::first' => sub { List::Util::first { $_ > 2000 } @numbers },
});

print "\nDONE\n";
