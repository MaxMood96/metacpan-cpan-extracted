#!perl

use warnings;
use strict;

use Test::More tests => 1;

require_ok('HTTP::Tiny::Paranoid');

local $HTTP::Tiny::Paranoid::VERSION = $HTTP::Tiny::Paranoid::VERSION || 'from repo';
note("HTTP::Tiny::Paranoid $HTTP::Tiny::Paranoid::VERSION, Perl $], $^X");
