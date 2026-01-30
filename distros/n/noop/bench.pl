#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(cmpthese);
use lib 'blib/lib', 'blib/arch';

use noop 'noop';

sub pp_noop { }
sub pp_noop_return { return }
sub pp_noop_empty { () }

print "=== NOOP BENCHMARK (1000 iterations per call) ===\n\n";

cmpthese(-2, {
    'xs_noop'        => sub { noop() for 1..1000 },
    'pp_noop'        => sub { pp_noop() for 1..1000 },
    'pp_noop_return' => sub { pp_noop_return() for 1..1000 },
    'pp_noop_empty'  => sub { pp_noop_empty() for 1..1000 },
});
