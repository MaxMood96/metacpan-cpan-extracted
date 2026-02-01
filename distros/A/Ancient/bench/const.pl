#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';

use const qw/all/;
use Const::XS ();

print "=== const() scalar benchmark ===\n";
cmpthese(-2, {
    "const" => sub { const my $x => 42 },
    "Const::XS" => sub { Const::XS::const(my $y => 42) },
});
print "\n";

print "=== const() array benchmark ===\n";
cmpthese(-2, {
    "const" => sub { const my @arr => qw/a b c d e/ },
    "Const::XS" => sub { Const::XS::const(my @arr2 => qw/a b c d e/) },
});
print "\n";

print "=== const() hash benchmark ===\n";
cmpthese(-2, {
    "const" => sub { const my %h => (a => 1, b => 2, c => 3) },
    "Const::XS" => sub { Const::XS::const(my %h2 => (a => 1, b => 2, c => 3)) },
});
print "\n";

print "=== make_readonly scalar benchmark ===\n";
cmpthese(-2, {
    "const" => sub { my $x = 42; const::make_readonly($x) },
    "Const::XS" => sub { my $y = 42; Const::XS::make_readonly($y) },
});
print "\n";

print "=== make_readonly hashref benchmark ===\n";
cmpthese(-2, {
    "const" => sub { my $h = { a => 1, b => { c => 2 } }; const::make_readonly($h) },
    "Const::XS" => sub { my $h = { a => 1, b => { c => 2 } }; Const::XS::make_readonly($h) },
});
print "\n";

print "=== is_readonly benchmark ===\n";
const my $ro => 42;
Const::XS::const(my $ro2 => 42);
cmpthese(-2, {
    "const" => sub { const::is_readonly($ro) },
    "Const::XS" => sub { Const::XS::is_readonly($ro2) },
});
print "\n";

print "=== c() vs Const::XS::const for inline use ===\n";
cmpthese(-2, {
    "c()" => sub { my $x = const::c(42) },
    "Const::XS" => sub { Const::XS::const(my $y => 42) },
});
print "\n";

print "=" x 60, "\n";
print "=== DIFFERENT USES OF const ===\n";
print "=" x 60, "\n\n";

print "=== Accessing pre-created constants ===\n";
const my $const_scalar => 'hello world';
const my @const_array => (1, 2, 3, 4, 5);
const my %const_hash => (a => 1, b => 2, c => 3);
my $ro_ref = const::c({ x => 10, y => 20 });

cmpthese(-2, {
    "scalar access" => sub { my $x = $const_scalar },
    "array access" => sub { my $x = $const_array[2] },
    "hash access" => sub { my $x = $const_hash{b} },
    "c() ref access" => sub { my $x = $ro_ref->{x} },
});
print "\n";

print "=== c() with different types ===\n";
cmpthese(-1, {
    "c(int)" => sub { my $x = const::c(42) },
    "c(string)" => sub { my $x = const::c('hello') },
    "c(float)" => sub { my $x = const::c(3.14159) },
});
print "\n";

print "=== c() with refs ===\n";
cmpthese(-1, {
    "c(arrayref)" => sub { my $x = const::c([1,2,3]) },
    "c(hashref)" => sub { my $x = const::c({a=>1}) },
});
print "\n";

print "=== Inline constant vs variable lookup ===\n";
my $name = 'counter';
const my $const_name => 'counter';
cmpthese(-1, {
    "c('literal')" => sub { my $x = const::c('counter') },
    "variable" => sub { my $x = $name },
    "const var" => sub { my $x = $const_name },
});
print "\n";

print "=== const vs plain (readonly overhead) ===\n";
cmpthese(-1, {
    "const scalar" => sub { const my $x => 42 },
    "plain scalar" => sub { my $x = 42 },
});
print "\n";

cmpthese(-1, {
    "const array" => sub { const my @a => (1,2,3) },
    "plain array" => sub { my @a = (1,2,3) },
});
print "\n";

cmpthese(-1, {
    "const hash" => sub { const my %h => (a=>1) },
    "plain hash" => sub { my %h = (a=>1) },
});
