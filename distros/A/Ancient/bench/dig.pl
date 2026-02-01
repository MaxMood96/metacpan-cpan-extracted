#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use util qw(dig);

print "=" x 60, "\n";
print "dig - Safe Hash Navigation Benchmark\n";
print "=" x 60, "\n\n";

my $data = {
    a => {
        b => {
            c => {
                d => 42
            }
        }
    }
};

# Pure Perl dig
sub pure_dig {
    my ($hash, @keys) = @_;
    for my $key (@keys) {
        return undef unless ref($hash) eq 'HASH' && exists $hash->{$key};
        $hash = $hash->{$key};
    }
    return $hash;
}

print "=== 4 levels deep - existing path ===\n";
cmpthese(-2, {
    'util::dig'    => sub { dig($data, 'a', 'b', 'c', 'd') },
    'pure_dig'     => sub { pure_dig($data, 'a', 'b', 'c', 'd') },
    'direct_access'=> sub { $data->{a}{b}{c}{d} },
});

print "\n=== 2 levels deep ===\n";
cmpthese(-2, {
    'util::dig'    => sub { dig($data, 'a', 'b') },
    'pure_dig'     => sub { pure_dig($data, 'a', 'b') },
    'direct_access'=> sub { $data->{a}{b} },
});

print "\n=== Missing key (safe) ===\n";
cmpthese(-2, {
    'util::dig'    => sub { dig($data, 'a', 'x', 'y') },
    'pure_dig'     => sub { pure_dig($data, 'a', 'x', 'y') },
});

print "\nDONE\n";
