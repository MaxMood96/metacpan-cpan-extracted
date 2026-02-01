#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use util qw(always);

print "=" x 60, "\n";
print "always - Constant Function Benchmark\n";
print "=" x 60, "\n\n";

# Pure Perl always
sub pure_always {
    my $val = shift;
    return sub { $val };
}

my $util_const = always(42);
my $pure_const = pure_always(42);

print "=== Call constant function ===\n";
cmpthese(-2, {
    'util::always' => sub { $util_const->() },
    'pure_always'  => sub { $pure_const->() },
});

print "\n=== Create + call ===\n";
cmpthese(-2, {
    'util::always' => sub { always(42)->() },
    'pure_always'  => sub { pure_always(42)->() },
});

print "\nDONE\n";
