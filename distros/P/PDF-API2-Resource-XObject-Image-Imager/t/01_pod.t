#!/usr/bin/perl

use strict;
use warnings;

use Test::More;
plan skip_all => 'Set RELEASE_TESTING=1 to run this test' if not $ENV{RELEASE_TESTING};
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();
