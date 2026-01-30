#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use lib 'blib/lib', 'blib/arch';

use_ok('noop', 'noop');

# Test that noop can be called
my $result = noop();
ok(!defined $result, 'noop returns undef/nothing');

# Test calling multiple times
noop();
noop();
noop();
pass('noop can be called multiple times');

# Test as callback
my $called = 0;
my $cb = \&noop;
$cb->();
is($called, 0, 'noop as callback does nothing');

done_testing();
