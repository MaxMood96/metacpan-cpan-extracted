#!/usr/bin/perl

use v5.22;
use warnings;

use Test2::V0;

eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;

all_pod_files_ok();
