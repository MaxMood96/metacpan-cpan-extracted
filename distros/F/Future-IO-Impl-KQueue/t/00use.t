#!/usr/bin/perl

use v5.20;
use warnings;

use Test2::V0;

require Future::IO::Impl::KQueue;

pass( 'Modules loaded' );
done_testing;
