#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 2;

use_ok('Algorithm::TimelinePacking');

my $t = Algorithm::TimelinePacking->new;
isa_ok($t, 'Algorithm::TimelinePacking');
