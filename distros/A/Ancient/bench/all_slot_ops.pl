#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese :hireswallclock);

use lib 'blib/lib', 'blib/arch';
use slot;

# Create slots at compile time for optimization
use slot qw(bench_slot);

print "=" x 70, "\n";
print "Benchmark: All slot:: functions with call checker optimization\n";
print "=" x 70, "\n\n";

bench_slot(42);

print "slot::get - constant vs variable name:\n";
print "-" x 50, "\n";
my $name = 'bench_slot';
cmpthese(-2, {
    'get(const)' => sub { 
        my $x;
        $x = slot::get('bench_slot');
        $x = slot::get('bench_slot');
        $x = slot::get('bench_slot');
        $x = slot::get('bench_slot');
        $x = slot::get('bench_slot');
    },
    'get($var)'  => sub { 
        my $x;
        $x = slot::get($name);
        $x = slot::get($name);
        $x = slot::get($name);
        $x = slot::get($name);
        $x = slot::get($name);
    },
});

print "\n\nslot::set - constant vs variable name:\n";
print "-" x 50, "\n";
cmpthese(-2, {
    'set(const,$v)' => sub { 
        slot::set('bench_slot', 1);
        slot::set('bench_slot', 2);
        slot::set('bench_slot', 3);
        slot::set('bench_slot', 4);
        slot::set('bench_slot', 5);
    },
    'set($var,$v)'  => sub { 
        slot::set($name, 1);
        slot::set($name, 2);
        slot::set($name, 3);
        slot::set($name, 4);
        slot::set($name, 5);
    },
});

print "\n\nslot::index - constant (compile-time folded) vs variable:\n";
print "-" x 50, "\n";
cmpthese(-2, {
    'index(const)' => sub { 
        my $x;
        $x = slot::index('bench_slot');
        $x = slot::index('bench_slot');
        $x = slot::index('bench_slot');
        $x = slot::index('bench_slot');
        $x = slot::index('bench_slot');
    },
    'index($var)'  => sub { 
        my $x;
        $x = slot::index($name);
        $x = slot::index($name);
        $x = slot::index($name);
        $x = slot::index($name);
        $x = slot::index($name);
    },
});

print "\n\nslot::clear - constant vs variable name:\n";
print "-" x 50, "\n";
cmpthese(-2, {
    'clear(const)' => sub { 
        slot::clear('bench_slot');
        slot::clear('bench_slot');
        slot::clear('bench_slot');
        slot::clear('bench_slot');
        slot::clear('bench_slot');
    },
    'clear($var)'  => sub { 
        slot::clear($name);
        slot::clear($name);
        slot::clear($name);
        slot::clear($name);
        slot::clear($name);
    },
});

print "\n";
print "=" x 70, "\n";
print "All slot::* functions with constant name args are now optimized\n";
print "to custom ops at compile time when the slot exists.\n";
print "=" x 70, "\n";
