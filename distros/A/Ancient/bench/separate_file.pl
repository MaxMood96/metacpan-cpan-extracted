#!/usr/bin/env perl
use strict;
use warnings;
use lib 'blib/lib', 'blib/arch', 't/lib';
use Benchmark qw(cmpthese);

# Load class from separate file
use FastAnimal;

# Import function-style accessors AFTER loading the class
BEGIN {
    require object;
    object::import_accessors('FastAnimal');
}

my $obj = new FastAnimal 'Whiskers', 3, 'cat';

print "Testing separate file scenario...\n\n";

# Verify it works
print "Method style: ", $obj->name, "\n";
print "Function style: ", name($obj), "\n";
print "speak(): ", $obj->speak, "\n\n";

print "--- Benchmark: separate file ---\n";
cmpthese(-2, {
    "method->name"  => sub { my $v = $obj->name },
    "name \$obj"     => sub { my $v = name($obj) },
});

print "\n--- SET ---\n";
cmpthese(-2, {
    "method->age(4)" => sub { $obj->age(4) },
    "age \$obj, 4"    => sub { age($obj, 4) },
});
