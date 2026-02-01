#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use lib 'blib/lib', 'blib/arch';

BEGIN {
    eval { require Test::LeakTrace };
    plan skip_all => 'Test::LeakTrace required' if $@;
}
use Test::LeakTrace;

use file;

my $tmpdir = tempdir(CLEANUP => 1);

# Create test files
my $small_file = "$tmpdir/small.txt";
my $medium_file = "$tmpdir/medium.txt";
file::spew($small_file, "line1\nline2\nline3\nline4\nline5");
file::spew($medium_file, join("\n", map { "Line $_" } 1..100));

# Warmup
for (1..10) {
    my $iter = file::lines_iter($small_file);
    while (!$iter->eof) { $iter->next; }
    $iter->close;
}

# ============================================
# Basic iterator lifecycle
# ============================================

subtest 'lines_iter create and close no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $iter = file::lines_iter($small_file);
            $iter->close;
        }
    } 'lines_iter create and close does not leak';
};

subtest 'lines_iter full read no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $iter = file::lines_iter($small_file);
            while (!$iter->eof) {
                my $line = $iter->next;
            }
            $iter->close;
        }
    } 'lines_iter full read does not leak';
};

subtest 'lines_iter partial read no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $iter = file::lines_iter($medium_file);
            for (1..10) {
                my $line = $iter->next;
            }
            $iter->close;
        }
    } 'lines_iter partial read does not leak';
};

# ============================================
# Iterator operations
# ============================================

subtest 'iterator next no leak' => sub {
    my $iter = file::lines_iter($small_file);
    no_leaks_ok {
        for (1..500) {
            # Reset iterator by closing and reopening
            $iter->close;
            $iter = file::lines_iter($small_file);
            my $line = $iter->next;
        }
    } 'iterator next does not leak';
    $iter->close;
};

subtest 'iterator eof no leak' => sub {
    my $iter = file::lines_iter($small_file);
    no_leaks_ok {
        for (1..500) {
            my $eof = $iter->eof;
        }
    } 'iterator eof does not leak';
    $iter->close;
};

# ============================================
# Multiple iterators
# ============================================

subtest 'multiple iterators no leak' => sub {
    no_leaks_ok {
        for (1..50) {
            my $iter1 = file::lines_iter($small_file);
            my $iter2 = file::lines_iter($medium_file);

            $iter1->next;
            $iter2->next;
            $iter1->next;
            $iter2->next;

            $iter1->close;
            $iter2->close;
        }
    } 'multiple iterators does not leak';
};

# ============================================
# Iterator with collect
# ============================================

subtest 'iterator collect all no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $iter = file::lines_iter($small_file);
            my @lines;
            while (!$iter->eof) {
                push @lines, $iter->next;
            }
            $iter->close;
        }
    } 'iterator collect all does not leak';
};

# ============================================
# Double close safety
# ============================================

subtest 'double close no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $iter = file::lines_iter($small_file);
            $iter->next;
            $iter->close;
            $iter->close;  # Safe double close
        }
    } 'double close does not leak';
};

# ============================================
# Iterator destruction without close
# ============================================

subtest 'iterator goes out of scope no leak' => sub {
    no_leaks_ok {
        for (1..100) {
            my $iter = file::lines_iter($small_file);
            $iter->next;
            # No explicit close - iterator goes out of scope
        }
    } 'iterator going out of scope does not leak';
};

done_testing();
