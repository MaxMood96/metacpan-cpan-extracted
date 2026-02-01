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

# Create test files
my $small_file = "$tmpdir/small.txt";
my $medium_file = "$tmpdir/medium.txt";
file::spew($small_file, "small content");
file::spew($medium_file, "x" x 10000);

# Warmup
for (1..10) {
    my $c = file::slurp($small_file);
}

subtest 'slurp small file' => sub {
    no_leaks_ok {
        for (1..100) {
            my $content = file::slurp($small_file);
        }
    } 'slurp small file does not leak';
};

subtest 'slurp medium file' => sub {
    no_leaks_ok {
        for (1..50) {
            my $content = file::slurp($medium_file);
        }
    } 'slurp medium file does not leak';
};

subtest 'slurp_raw' => sub {
    no_leaks_ok {
        for (1..100) {
            my $content = file::slurp_raw($small_file);
        }
    } 'slurp_raw does not leak';
};

subtest 'slurp nonexistent' => sub {
    no_leaks_ok {
        for (1..100) {
            my $content = file::slurp("$tmpdir/nonexistent.txt");
        }
    } 'slurp nonexistent does not leak';
};

done_testing();
