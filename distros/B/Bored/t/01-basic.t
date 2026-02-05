#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 14;

use Bored;

# Test do_nothing_efficiently
ok(1, "do_nothing_efficiently exists");
Bored::do_nothing_efficiently();
ok(1, "do_nothing_efficiently completed (by doing nothing)");

# Test is_pointless - should always return true
ok(Bored::is_pointless("work"), "work is pointless");
ok(Bored::is_pointless("existence"), "existence is pointless");
ok(Bored::is_pointless(42), "42 is pointless");
ok(Bored::is_pointless(undef), "undef is pointless");
ok(Bored::is_pointless(""), "empty string is pointless");

# Test accelerated_sigh
my $sigh = Bored::sigh();
like($sigh, qr/\*sigh/, "sigh contains *sigh");

# Test ultimate_nothing (whatever)
my $whatever = Bored::whatever();
is($whatever, "¯\\_(ツ)_/¯", "whatever returns shrug");

# Test meh with different intensities
my $meh5 = Bored::meh(5);
is($meh5, "meeeeeh", "meh(5) has 5 e's");

my $meh1 = Bored::meh(1);
is($meh1, "meh", "meh(1) is just meh");

my $meh10 = Bored::meh(10);
is($meh10, "meeeeeeeeeeh", "meh(10) has 10 e's");

# Test get_boredom_level
my $level = Bored::get_boredom_level();
ok(defined $level, "Boredom level is defined: $level");

# Test get_sighs_emitted
my $sighs = Bored::get_sighs_emitted();
ok($sighs >= 8, "sighs emitted after sigh(): $sighs");
