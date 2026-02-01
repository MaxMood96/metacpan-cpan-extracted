#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(memo));

# Test basic memoization
my $call_count = 0;
my $expensive = memo(sub {
    my $n = shift;
    $call_count++;
    return $n * 2;
});

is($expensive->(5), 10, 'first call returns correct value');
is($call_count, 1, 'function was called once');

is($expensive->(5), 10, 'second call returns correct value');
is($call_count, 1, 'function was not called again (cached)');

is($expensive->(10), 20, 'different arg returns correct value');
is($call_count, 2, 'function was called for new arg');

is($expensive->(5), 10, 'cached value still works');
is($call_count, 2, 'still cached');

# Test with multiple arguments
my $multi_call = 0;
my $add = memo(sub {
    $multi_call++;
    return $_[0] + $_[1];
});

is($add->(1, 2), 3, 'two args work');
is($multi_call, 1, 'called once');

is($add->(1, 2), 3, 'same args cached');
is($multi_call, 1, 'still one call');

is($add->(2, 1), 3, 'different arg order');
is($multi_call, 2, 'new args = new call');

# Test with no arguments
my $no_arg_count = 0;
my $constant = memo(sub {
    $no_arg_count++;
    return 42;
});

is($constant->(), 42, 'no-arg function works');
is($no_arg_count, 1, 'called once');

is($constant->(), 42, 'cached');
is($no_arg_count, 1, 'still one call');

done_testing;
