#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use util qw(trim ltrim rtrim);

print "=" x 60, "\n";
print "trim/ltrim/rtrim Benchmark\n";
print "=" x 60, "\n\n";

my $str = "   hello world   ";

print "=== trim ===\n";
cmpthese(-2, {
    'util::trim'  => sub { trim($str) },
    'regex_s///'  => sub { my $s = $str; $s =~ s/^\s+|\s+$//g; $s },
    'two_regex'   => sub { my $s = $str; $s =~ s/^\s+//; $s =~ s/\s+$//; $s },
});

print "\n=== ltrim ===\n";
cmpthese(-2, {
    'util::ltrim' => sub { ltrim($str) },
    'regex'       => sub { my $s = $str; $s =~ s/^\s+//; $s },
});

print "\n=== rtrim ===\n";
cmpthese(-2, {
    'util::rtrim' => sub { rtrim($str) },
    'regex'       => sub { my $s = $str; $s =~ s/\s+$//; $s },
});

print "\n=== trim (already trimmed) ===\n";
my $trimmed = "hello world";
cmpthese(-2, {
    'util::trim'  => sub { trim($trimmed) },
    'regex_s///'  => sub { my $s = $trimmed; $s =~ s/^\s+|\s+$//g; $s },
});

print "\nDONE\n";
