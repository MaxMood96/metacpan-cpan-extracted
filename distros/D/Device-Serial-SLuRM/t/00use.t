#!/usr/bin/perl

use v5.28;
use warnings;

use Test2::V0;

require Device::Serial::SLuRM::Protocol;

require Device::Serial::SLuRM;
require Device::Serial::MSLuRM;

pass( 'Modules loaded' );
done_testing;
