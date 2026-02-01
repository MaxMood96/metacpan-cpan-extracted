#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use util qw(pick);

print "=" x 60, "\n";
print "pick - Extract Hash Keys Benchmark\n";
print "=" x 60, "\n\n";

my %hash = (a => 1, b => 2, c => 3, d => 4, e => 5);
my $href = \%hash;

# Pure Perl pick
sub pure_pick {
    my ($hash, @keys) = @_;
    my %result;
    for my $k (@keys) {
        $result{$k} = $hash->{$k} if exists $hash->{$k};
    }
    return \%result;
}

print "=== pick 2 keys ===\n";
cmpthese(-2, {
    'util::pick' => sub { pick($href, 'a', 'c') },
    'pure_pick'  => sub { pure_pick($href, 'a', 'c') },
    'hash_slice' => sub { my %r; @r{qw(a c)} = @{$href}{qw(a c)}; \%r },
});

print "\n=== pick 4 keys ===\n";
cmpthese(-2, {
    'util::pick' => sub { pick($href, 'a', 'b', 'c', 'd') },
    'pure_pick'  => sub { pure_pick($href, 'a', 'b', 'c', 'd') },
});

print "\nDONE\n";
