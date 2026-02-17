#!/usr/bin/env perl
use v5.36;
use strict;
use warnings;

use Test2::V0;

use Linux::Event;
use Linux::Event::Fork;  # installs $loop->fork and $loop->fork_helper

my $loop = Linux::Event->new;

ok($loop->can('fork'),        'loop has fork() after use Linux::Event::Fork');
ok($loop->can('fork_helper'), 'loop has fork_helper() after use Linux::Event::Fork');

done_testing;
