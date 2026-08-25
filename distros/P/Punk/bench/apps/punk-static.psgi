#!/usr/bin/env perl
use strict;
use warnings;
use FindBin ();
use lib "$FindBin::Bin/../../lib";

# BENCH-PATH: /static/bench.css

# A static file: one of the requests Punk answers entirely in C, with no
# controller, no Perl frame and nothing in the response that the router did
# not already know at boot.
#
# It is here as the denominator for the C-handoff work. Today this request
# still costs a full PSGI env - ~26 SVs and an HV sized to 64 buckets - built
# by the server so that the dispatcher can read PATH_INFO out of it and then
# answer from bytes it already had. Read punk-static against:
#
#   bare          a hand-rolled PSGI app, the ceiling
#   punk-hello    the same dispatch into a Perl handler
#   punk-404      the cheapest C answer there is
#
# The file is written to a temp dir at boot rather than committed, so the
# benchmark cannot drift against a stale asset and there is no data file to
# keep in MANIFEST.

use File::Temp ();
use File::Path ();

my $ROOT = File::Temp::tempdir(CLEANUP => 1);
File::Path::make_path("$ROOT/static");
open my $fh, '>', "$ROOT/static/bench.css" or die $!;
# A small file on purpose: this measures the dispatch, not the disk. A big
# one would be measuring sendfile, which is the server's half, not this one.
print {$fh} "body{margin:0;font:16px/1.5 system-ui;color:#111}\n";
close $fh;

package BenchStatic;
use Punk;

static '/static' => "$ROOT/static";

# so the app has an ordinary route too, and the static hit is not the only
# thing in the table
get '/' => sub { $_[0]->text('hello') };

package main;
BenchStatic->to_app;
