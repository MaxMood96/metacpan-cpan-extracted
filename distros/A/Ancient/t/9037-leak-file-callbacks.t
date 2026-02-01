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

# Create test file with various content
my $test_file = "$tmpdir/callback.txt";
file::spew($test_file, "apple\nbanana\n\ncherry\n# comment\ndate\n");

# Warmup
for (1..10) {
    my $r = file::grep_lines($test_file, sub { 1 });
    my $c = file::count_lines($test_file);
}

subtest 'grep_lines with coderef no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $result = file::grep_lines($test_file, sub {
                length(shift) > 3;
            });
        }
    } 'grep_lines with coderef does not leak';
};

subtest 'grep_lines with builtin no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $result = file::grep_lines($test_file, 'is_not_blank');
        }
    } 'grep_lines with builtin does not leak';
};

subtest 'count_lines no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $count = file::count_lines($test_file);
        }
    } 'count_lines does not leak';
};

subtest 'count_lines with predicate no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $count = file::count_lines($test_file, 'is_not_blank');
        }
    } 'count_lines with predicate does not leak';
};

subtest 'find_line no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $found = file::find_line($test_file, sub { /cherry/ });
        }
    } 'find_line does not leak';
};

subtest 'find_line no match no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $found = file::find_line($test_file, sub { /nonexistent/ });
        }
    } 'find_line no match does not leak';
};

subtest 'map_lines no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $result = file::map_lines($test_file, sub {
                uc(shift);
            });
        }
    } 'map_lines does not leak';
};

subtest 'register_line_callback no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            file::register_line_callback("test_cb_$_", sub { 1 });
        }
    } 'register_line_callback does not leak';
};

subtest 'list_line_callbacks no leak' => sub {
    no_leaks_ok {
        for (1..200) {
            my $list = file::list_line_callbacks();
        }
    } 'list_line_callbacks does not leak';
};

done_testing();
