#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use List::Util ();
use util qw(none_gt none_lt none_ge none_le none_eq none_ne);

print "=" x 60, "\n";
print "none_* - Specialized None Comparison Benchmark\n";
print "=" x 60, "\n\n";

my @numbers = 1..1000;

print "=== none_gt (none match - check all) ===\n";
cmpthese(-2, {
    'util::none_gt'    => sub { none_gt(\@numbers, 2000) },
    'List::Util::none' => sub { List::Util::none { $_ > 2000 } @numbers },
});

print "\n=== none_lt (match early - short circuit) ===\n";
cmpthese(-2, {
    'util::none_lt'    => sub { none_lt(\@numbers, 500) },
    'List::Util::none' => sub { List::Util::none { $_ < 500 } @numbers },
});

print "\n=== none_eq (check all) ===\n";
cmpthese(-2, {
    'util::none_eq'    => sub { none_eq(\@numbers, 9999) },
    'List::Util::none' => sub { List::Util::none { $_ == 9999 } @numbers },
});

print "\n=== none_lt (hash - no minors) ===\n";
my @adults = map { { id => $_, age => 18 + int(rand(50)) } } 1..1000;
cmpthese(-2, {
    'util::none_lt'    => sub { none_lt(\@adults, 'age', 18) },
    'List::Util::none' => sub { List::Util::none { $_->{age} < 18 } @adults },
});

print "\nDONE\n";
