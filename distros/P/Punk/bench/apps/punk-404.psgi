#!/usr/bin/env perl
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/../../lib";

# BENCH-PATH: /nope

# The cheapest answer this framework can give: a path that matches nothing.
# No context, no controller, no Perl frame - the router misses and the 404
# is bytes that were frozen at boot.
#
# Which makes it the purest measurement of what the request costs BEFORE the
# framework does anything: the PSGI env the server built, and the handful of
# hv_fetches the dispatcher makes to find out there is nothing to do. Every
# microsecond here is overhead by definition, and it is the number the
# C-handoff work should move furthest.
#
# Read against bare (the ceiling) and punk-hello (the same table, one hit).

package BenchNotFound;
use Punk;

# a table with something in it, so the miss is a real miss and not an
# empty-router short circuit
get '/'       => sub { $_[0]->text('hello') };
get '/books'  => sub { $_[0]->text('books') };
get '/about'  => sub { $_[0]->text('about') };

package main;
BenchNotFound->to_app;
