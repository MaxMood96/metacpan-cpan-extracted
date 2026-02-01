#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use_ok('file');

my $tmpdir = tempdir(CLEANUP => 1);

# Create test file
my $test_file = "$tmpdir/mmap.txt";
file::spew($test_file, "x" x 10000);

# Warmup
for (1..10) {
    my $mmap = file::mmap_open($test_file);
    my $data = $mmap->data;
    $mmap->close;
}

subtest 'mmap_open/close cycle no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $mmap = file::mmap_open($test_file);
            $mmap->close;
        }
    } 'mmap_open/close does not leak';
};

subtest 'mmap data access no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $mmap = file::mmap_open($test_file);
            my $data = $mmap->data;
            my $len = length($data);
            $mmap->close;
        }
    } 'mmap data access does not leak';
};

subtest 'mmap implicit close (DESTROY) no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $mmap = file::mmap_open($test_file);
            my $data = $mmap->data;
            # Let DESTROY handle close
        }
    } 'mmap implicit close does not leak';
};

done_testing();
