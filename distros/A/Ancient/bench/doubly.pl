#!/usr/bin/env perl
use strict;
use warnings;
use Benchmark qw(:all);

# Load installed Doubly first (before blib)
use Doubly;

# Now load our XS doubly from blib
use blib;
use doubly;     # XS version

my $r = timethese(100000, {
    'doubly (XS)' => sub {
        my $linked = doubly->new(123);
        $linked->bulk_add(0..1000);
        $linked = $linked->end;
        $linked->is_end;
        $linked = $linked->start;
        $linked->is_start;
        $linked->add(789);
        $linked->destroy;
    },
    'Doubly (PP)' => sub {
        my $linked = Doubly->new(123);
        $linked->bulk_add(0..1000);
        $linked = $linked->end;
        $linked->is_end;
        $linked = $linked->start;
        $linked->is_start;
        $linked->add(789);
        $linked->destroy;
    },
});
cmpthese $r;
