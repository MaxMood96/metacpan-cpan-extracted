#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);

use lru;

# Pure Perl LRU implementation for comparison
package PerlLRU;
sub new {
    my ($class, $capacity) = @_;
    bless {
        capacity => $capacity,
        hash => {},
        order => [],
    }, $class;
}
sub set {
    my ($self, $key, $value) = @_;
    if (exists $self->{hash}{$key}) {
        $self->{hash}{$key} = $value;
        @{$self->{order}} = grep { $_ ne $key } @{$self->{order}};
        unshift @{$self->{order}}, $key;
    } else {
        if (@{$self->{order}} >= $self->{capacity}) {
            my $old = pop @{$self->{order}};
            delete $self->{hash}{$old};
        }
        $self->{hash}{$key} = $value;
        unshift @{$self->{order}}, $key;
    }
}
sub get {
    my ($self, $key) = @_;
    return undef unless exists $self->{hash}{$key};
    @{$self->{order}} = grep { $_ ne $key } @{$self->{order}};
    unshift @{$self->{order}}, $key;
    return $self->{hash}{$key};
}
sub exists {
    my ($self, $key) = @_;
    return exists $self->{hash}{$key};
}

package main;

print "=== LRU Cache Benchmark ===\n\n";

my $xs_cache = lru::new(1000);
my $pl_cache = PerlLRU->new(1000);

# Pre-populate with some data
for my $i (1..500) {
    $xs_cache->set("key$i", "value$i");
    $pl_cache->set("key$i", "value$i");
}

print "--- SET (new keys, triggers eviction) ---\n";
my $set_i = 0;
cmpthese(-2, {
    'XS lru::set' => sub {
        $xs_cache->set("new" . $set_i++, "value");
    },
    'Perl LRU set' => sub {
        $pl_cache->set("new" . $set_i++, "value");
    },
});

print "\n--- GET (existing key, promotes) ---\n";
cmpthese(-2, {
    'XS lru::get' => sub {
        $xs_cache->get("key250");
    },
    'Perl LRU get' => sub {
        $pl_cache->get("key250");
    },
});

print "\n--- EXISTS (no promotion) ---\n";
cmpthese(-2, {
    'XS lru::exists' => sub {
        $xs_cache->exists("key250");
    },
    'Perl LRU exists' => sub {
        $pl_cache->exists("key250");
    },
});

print "\n--- Mixed workload (80% get, 20% set) ---\n";
my $mix_i = 0;
cmpthese(-2, {
    'XS lru mixed' => sub {
        if (rand() < 0.8) {
            $xs_cache->get("key" . int(rand(500)+1));
        } else {
            $xs_cache->set("mix" . $mix_i++, "value");
        }
    },
    'Perl LRU mixed' => sub {
        if (rand() < 0.8) {
            $pl_cache->get("key" . int(rand(500)+1));
        } else {
            $pl_cache->set("mix" . $mix_i++, "value");
        }
    },
});
