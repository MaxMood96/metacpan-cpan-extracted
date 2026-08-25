#!/usr/bin/env perl
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/../../lib";

# BENCH-PATH: /
# BENCH-HEADER: If-None-Match: "v1"

# A conditional GET that HITS: the client sends the validator it was given,
# the strong validator says nothing changed, and the handler never runs.
#
# This is the third of the requests Punk answers without entering Perl, and
# the one a load generator never reaches - wrk does not send If-None-Match,
# so punk-conditional-get.psgi only ever measures the cost of the feature
# and never the saving. The BENCH-HEADER directive is what makes the other
# half measurable at all.
#
# Deliberately the same app and the same route as punk-conditional-get's
# first route, so the pair reads as one experiment:
#
#   punk-conditional-get   the 200: validator runs, handler runs, body sent
#   punk-304               the 304: validator runs, handler skipped
#
# The 304 should be the CHEAPER of the two - the only place in this framework
# where adding a feature makes a request cost less. If that inverts, the
# validator has stopped short-circuiting.

package BenchNotModified;
use Punk;

plugin 'ConditionalGet';

# one string comparison, no I/O - the floor for a validator
get '/' => sub { $_[0]->text('hello') }, { etag => sub { 'v1' } };

package main;
BenchNotModified->to_app;
