#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use util qw(defaults);

print "=" x 60, "\n";
print "defaults - Hash Defaults Benchmark\n";
print "=" x 60, "\n\n";

my $opts = { a => 1, b => undef };
my $defs = { a => 10, b => 20, c => 30 };

# Pure Perl defaults
sub pure_defaults {
    my ($hash, $defaults) = @_;
    my %result = %$hash;
    for my $k (keys %$defaults) {
        $result{$k} = $defaults->{$k} unless defined $result{$k};
    }
    return \%result;
}

print "=== Apply 3 defaults (2 used) ===\n";
cmpthese(-2, {
    'util::defaults' => sub { defaults($opts, $defs) },
    'pure_defaults'  => sub { pure_defaults($opts, $defs) },
});

my $empty = {};
print "\n=== All defaults applied ===\n";
cmpthese(-2, {
    'util::defaults' => sub { defaults($empty, $defs) },
    'pure_defaults'  => sub { pure_defaults($empty, $defs) },
});

print "\nDONE\n";
