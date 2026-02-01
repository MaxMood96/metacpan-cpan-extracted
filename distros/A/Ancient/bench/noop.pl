#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use util qw(noop);

print "=" x 60, "\n";
print "noop - No-Operation Benchmark\n";
print "=" x 60, "\n\n";

# Pure Perl noop
sub pure_noop { undef }

print "=== Call noop ===\n";
cmpthese(-2, {
    'util::noop'  => sub { noop() },
    'pure_noop'   => sub { pure_noop() },
    'sub_undef'   => sub { sub { undef }->() },
});

print "\n=== Call with arguments (ignored) ===\n";
cmpthese(-2, {
    'util::noop'  => sub { noop(1, 2, 3) },
    'pure_noop'   => sub { pure_noop(1, 2, 3) },
});

print "\nDONE\n";
