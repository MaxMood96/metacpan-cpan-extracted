#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 10;

use Bored;

# Test stare_into_void
my $void = Bored::stare_into_void();
ok(defined $void, "void exists (paradox?)");
isa_ok($void, 'Bored::Void', "void is a Bored::Void");

is($void->depth, 'infinite', "void depth is infinite");

# Test stare_back
my $stare = $void->stare_back();
is($stare, "👁️", "void stares back with eye emoji");

# Test void singleton
my $void2 = Bored::stare_into_void();
is($void, $void2, "void is a singleton");

# Test whisper into the void
my $response = $void->whisper("Hello?");
is($response, undef, "void consumes all messages (returns nothing)");

# Test get_void_stare_count
my $stares = Bored::get_void_stare_count();
ok($stares >= 2, "void stare count incremented: $stares");

# Test await_heat_death
my $heat_death = Bored::await_heat_death();
like($heat_death, qr/heat death/, "await_heat_death returns message");
like($heat_death, qr/10\^100/, "includes estimated time");

# Test contemplate_mortality (should do nothing)
Bored::contemplate_mortality(0.001);
ok(1, "survived contemplating mortality");
