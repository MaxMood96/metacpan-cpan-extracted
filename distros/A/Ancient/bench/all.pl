#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use List::Util ();
use util qw(all);

print "=" x 60, "\n";
print "all - All Match Benchmark\n";
print "=" x 60, "\n\n";

my @numbers = 1..1000;

print "=== All match ===\n";
cmpthese(-2, {
    'util::all'       => sub { all(sub { $_ > 0 }, \@numbers) },
    'List::Util::all' => sub { List::Util::all { $_ > 0 } @numbers },
});

print "\n=== Fail early ===\n";
cmpthese(-2, {
    'util::all'       => sub { all(sub { $_ > 10 }, \@numbers) },
    'List::Util::all' => sub { List::Util::all { $_ > 10 } @numbers },
});

print "\n=== Fail at end ===\n";
cmpthese(-2, {
    'util::all'       => sub { all(sub { $_ < 1000 }, \@numbers) },
    'List::Util::all' => sub { List::Util::all { $_ < 1000 } @numbers },
});

print "\nDONE\n";
