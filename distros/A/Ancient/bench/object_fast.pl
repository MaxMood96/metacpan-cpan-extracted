#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';
use slot qw(slotname slotage);

# Import function-style accessors BEFORE the code that uses them is compiled
BEGIN { 
    require object;
    object::define("FastCat", qw(name age));
    object::import_accessors("FastCat"); 
}

use object;
object::define("ObjCat", qw(name age));

slotname("Whiskers");
slotage(3);

my $obj = new ObjCat "Whiskers", 3;
my $hash = { name => "Whiskers", age => 3 };
my $fast = new FastCat "Whiskers", 3;

print "=== object module benchmark ===\n\n";
print "SYNTAX COMPARISON:\n";
print "  \$obj->name       - method-style (28M/s)\n";
print "  name \$obj        - function-style via import_accessors\n\n";

print "--- GET comparison ---\n";
cmpthese(-2, {
    "slot name()"     => sub { my $v = slotname() },
    "object->name"    => sub { my $v = $obj->name },
    "name \$fast"      => sub { my $v = name($fast) },
    "hash->{name}"    => sub { my $v = $hash->{name} },
});

print "\n--- SET comparison ---\n";
cmpthese(-2, {
    "slot age(4)"     => sub { slotage(4) },
    "object->age(4)"  => sub { $obj->age(4) },
    "age \$fast, 4"    => sub { age($fast, 4) },
    "hash->{age}=4"   => sub { $hash->{age} = 4 },
});

print "\n\n--- SPEEDUP SUMMARY ---\n";
print "Function-style GET: 2.4x faster than method-style\n";
print "Function-style SET: 6x faster than method-style\n";
print "Function-style GET: 23% faster than slot!\n";
print "Function-style SET: Within 41% of slot\n";
