#!/usr/bin/env perl
# -*- cperl; cperl-indent-level: 4 -*-
# Copyright (C) 2021, Roland van Ipenburg
use strict;
use warnings;
use utf8;
use 5.014000;

our $VERSION = 'v1.0.4';

use Test::More;
use Test::Requires { 'Test::Pod::Coverage' => 0 };
## no critic (RequireExplicitInclusion ProhibitCallsToUnexportedSubs)
Test::Pod::Coverage::all_pod_coverage_ok();
## use critic
