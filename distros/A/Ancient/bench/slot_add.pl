#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese timethese);
use lib 'blib/lib', 'blib/arch';
use slot;

print "=== slot::add benchmark ===\n\n";

# Test 1: Single slot creation speed
print "--- Creating single slots ---\n";
my $counter = 0;
cmpthese(-2, {
    'slot::add' => sub {
        slot::add("bench_add_" . $counter++);
    },
    'use slot (import)' => sub {
        # Simulating import by calling it directly
        # Note: import also installs accessor, so this is slower by design
        slot->import("bench_import_" . $counter++);
    },
});

print "\n--- Index-based vs name-based access ---\n";
slot::add("idx_test");
my $idx = slot::index("idx_test");
slot::set("idx_test", 0);

cmpthese(-2, {
    'slot::get/set (name)' => sub {
        slot::set("idx_test", slot::get("idx_test") + 1);
    },
    'slot::get/set_by_idx' => sub {
        slot::set_by_idx($idx, slot::get_by_idx($idx) + 1);
    },
});

print "\n--- All access methods compared ---\n";
use slot qw(accessor_slot);
accessor_slot(0);
my $accessor_idx = slot::index("accessor_slot");

my %hash_store;
$hash_store{perl_slot} = 0;
my $scalar_store = 0;

cmpthese(-2, {
    'accessor (custom op)' => sub {
        accessor_slot(accessor_slot() + 1);
    },
    'get/set_by_idx' => sub {
        slot::set_by_idx($accessor_idx, slot::get_by_idx($accessor_idx) + 1);
    },
    'slot::get/set (name)' => sub {
        slot::set("accessor_slot", slot::get("accessor_slot") + 1);
    },
    'hash store' => sub {
        $hash_store{perl_slot} = $hash_store{perl_slot} + 1;
    },
    'scalar' => sub {
        $scalar_store = $scalar_store + 1;
    },
});
