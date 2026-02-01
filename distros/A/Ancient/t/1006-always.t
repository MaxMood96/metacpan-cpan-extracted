#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(always));

# Test basic always - returns constant value
my $get_zero = always(0);
is($get_zero->(), 0, 'always(0) returns 0');
is($get_zero->(), 0, 'always(0) returns 0 again');
is($get_zero->(), 0, 'always(0) returns 0 third time');

# Test with various types
my $get_string = always('hello');
is($get_string->(), 'hello', 'always works with strings');

my $get_number = always(42);
is($get_number->(), 42, 'always works with numbers');

my $get_float = always(3.14);
is($get_float->(), 3.14, 'always works with floats');

# Test with references
my $config = { debug => 1, verbose => 0 };
my $get_config = always($config);
is_deeply($get_config->(), $config, 'always works with hashrefs');
is($get_config->(), $config, 'always returns same reference');

my $list = [1, 2, 3];
my $get_list = always($list);
is_deeply($get_list->(), $list, 'always works with arrayrefs');
is($get_list->(), $list, 'always returns same arrayref');

# Test that arguments are ignored
my $const = always(100);
is($const->('ignored'), 100, 'always ignores arguments');
is($const->(1, 2, 3), 100, 'always ignores multiple arguments');

# Test multiple always functions are independent
my $a = always('A');
my $b = always('B');
is($a->(), 'A', 'first always returns A');
is($b->(), 'B', 'second always returns B');
is($a->(), 'A', 'first still returns A');
is($b->(), 'B', 'second still returns B');

# Test with undef
my $get_undef = always(undef);
is($get_undef->(), undef, 'always(undef) returns undef');

# Test using always in map
my @results = map { always($_)->() } (1, 2, 3);
is_deeply(\@results, [1, 2, 3], 'always works in map');

# Test always as a callback
sub apply_callback {
    my ($cb, @args) = @_;
    return $cb->(@args);
}

is(apply_callback(always(99), 'ignored'), 99, 'always as callback');

done_testing;
