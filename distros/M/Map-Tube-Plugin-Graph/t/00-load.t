#!/usr/bin/perl

use 5.014;
use strict;
use warnings;
use Test::More tests => 2;

use_ok($_) for qw(
    Map::Tube::Plugin::Graph
    Map::Tube::Plugin::Graph::Utils
);

diag( "Testing Map::Tube::Plugin::Graph $Map::Tube::Plugin::Graph::VERSION, Perl $], $^X" );
