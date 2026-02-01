#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese timethese :hireswallclock);

# Add blib paths for development
use lib 'blib/lib', 'blib/arch';
use slot;

# Create slots at compile time - these can be optimized
use slot qw(accessor_slot compile_time_slot);
my $idx = slot::index('compile_time_slot');

print "=" x 70, "\n";
print "Benchmark: slot access methods (with call checker optimization)\n";
print "=" x 70, "\n\n";

# Initialize values
accessor_slot(42);
slot::set('compile_time_slot', 42);

print "Testing GET operations (compile-time slot):\n";
print "-" x 50, "\n\n";

my $results = cmpthese(-2, {
    'accessor()' => sub {
        my $x = accessor_slot();
        $x = accessor_slot();
        $x = accessor_slot();
        $x = accessor_slot();
        $x = accessor_slot();
    },
    'slot::get(const)' => sub {
        my $x = slot::get('compile_time_slot');
        $x = slot::get('compile_time_slot');
        $x = slot::get('compile_time_slot');
        $x = slot::get('compile_time_slot');
        $x = slot::get('compile_time_slot');
    },
    'slot::get_by_idx' => sub {
        my $x = slot::get_by_idx($idx);
        $x = slot::get_by_idx($idx);
        $x = slot::get_by_idx($idx);
        $x = slot::get_by_idx($idx);
        $x = slot::get_by_idx($idx);
    },
});

print "\n\nTesting SET operations (compile-time slot):\n";
print "-" x 50, "\n\n";

cmpthese(-2, {
    'accessor($v)' => sub {
        accessor_slot(1);
        accessor_slot(2);
        accessor_slot(3);
        accessor_slot(4);
        accessor_slot(5);
    },
    'slot::set(const,$v)' => sub {
        slot::set('compile_time_slot', 1);
        slot::set('compile_time_slot', 2);
        slot::set('compile_time_slot', 3);
        slot::set('compile_time_slot', 4);
        slot::set('compile_time_slot', 5);
    },
    'slot::set_by_idx' => sub {
        slot::set_by_idx($idx, 1);
        slot::set_by_idx($idx, 2);
        slot::set_by_idx($idx, 3);
        slot::set_by_idx($idx, 4);
        slot::set_by_idx($idx, 5);
    },
});

print "\n\nTesting dynamic name (no optimization possible):\n";
print "-" x 50, "\n\n";

my $name = 'compile_time_slot';  # Runtime variable

cmpthese(-2, {
    'slot::get(const)' => sub {
        my $x = slot::get('compile_time_slot');
        $x = slot::get('compile_time_slot');
        $x = slot::get('compile_time_slot');
        $x = slot::get('compile_time_slot');
        $x = slot::get('compile_time_slot');
    },
    'slot::get($var)' => sub {
        my $x = slot::get($name);
        $x = slot::get($name);
        $x = slot::get($name);
        $x = slot::get($name);
        $x = slot::get($name);
    },
});

print "\n";
print "=" x 70, "\n";
print "Note: 'slot::get(const)' with constant string is optimized at compile\n";
print "      time to a custom op when slot exists at compile time.\n";
print "=" x 70, "\n";
