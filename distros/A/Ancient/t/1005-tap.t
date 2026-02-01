#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('util', qw(tap));

# Test basic tap - returns original value
my $result = tap(sub { }, 42);
is($result, 42, 'tap returns original value');

# Test tap executes the block
my $side_effect = 0;
$result = tap(sub { $side_effect = 1 }, 'hello');
is($result, 'hello', 'tap returns original string value');
is($side_effect, 1, 'tap executed the block');

# Test tap sets $_
my $captured;
$result = tap(sub { $captured = $_ }, 'world');
is($captured, 'world', 'tap sets $_ to the value');
is($result, 'world', 'tap returns the value');

# Test tap also passes value as argument
my $arg_captured;
$result = tap(sub { $arg_captured = $_[0] }, 123);
is($arg_captured, 123, 'tap passes value as argument');

# Test tap with complex data
my $array = [1, 2, 3];
$result = tap(sub { push @$_, 4 }, $array);
is_deeply($result, [1, 2, 3, 4], 'tap can modify the value');
is($result, $array, 'tap returns same reference');

# Test tap with hash
my $hash = { a => 1 };
$result = tap(sub { $_->{b} = 2 }, $hash);
is_deeply($result, { a => 1, b => 2 }, 'tap can modify hash');

# Test tap in pipeline-like usage
my @log;
my $value = 10;
$result = tap(sub { push @log, "Got: $_" }, $value);
is($result, 10, 'tap returns value in pipeline');
is_deeply(\@log, ['Got: 10'], 'tap logged correctly');

# Test tap ignores return value of block
$result = tap(sub { return 'ignored' }, 'kept');
is($result, 'kept', 'tap ignores block return value');

# Test chained taps
my @trace;
$result = tap(sub { push @trace, "first: $_" },
    tap(sub { push @trace, "second: $_" }, 5));
is($result, 5, 'chained taps return original');
is_deeply(\@trace, ['second: 5', 'first: 5'], 'chained taps execute in order');

done_testing;
