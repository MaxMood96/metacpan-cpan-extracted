#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use util;
use file;
use lru qw(import);
use File::Temp qw(tempdir);

# Test cross-module interactions in map/grep/for context
# Ensures custom ops from different modules work together

my $tempdir = tempdir(CLEANUP => 1);

# ============================================
# util + file combined
# ============================================
subtest 'util and file combined in map' => sub {
    # Create test files
    for my $i (1..3) {
        file::spew("$tempdir/file$i.txt", "content $i");
    }
    
    my @paths = map { "$tempdir/file$_.txt" } (1..3);
    
    # Combine file::exists check with util::is_defined
    my @existing = grep { 
        my $exists = file::exists($_);
        util::is_defined($exists) && $exists
    } @paths;
    is(scalar(@existing), 3, 'all 3 files exist');
    
    # Read and check content
    my @contents = map { file::slurp($_) } @existing;
    my @has_content = grep { util::is_defined($_) && length($_) > 0 } @contents;
    is(scalar(@has_content), 3, 'all 3 files have content');
};

# ============================================
# util + lru combined
# ============================================
subtest 'util and lru combined in map' => sub {
    my $cache = lru->new(10);
    
    # Set some values (mix of odd and even)
    $cache->set("key1", 10);
    $cache->set("key2", 15);
    $cache->set("key3", 20);
    $cache->set("key4", 25);
    $cache->set("key5", 30);
    
    my @keys = map { "key$_" } (1..5);
    
    # Get values and filter with util
    my @values = map { $cache->get($_) } @keys;
    my @even_values = grep { util::is_even($_) } @values;
    is_deeply(\@even_values, [10, 20, 30], 'even cached values found');
    
    # Clamp cached values - use explicit variable to avoid context issues
    my @clamped = map { my $v = util::clamp($cache->get($_), 15, 25); $v } @keys;
    is_deeply(\@clamped, [15, 15, 20, 25, 25], 'cached values clamped');
};

# ============================================
# file + lru combined
# ============================================
subtest 'file and lru combined' => sub {
    my $cache = lru->new(10);
    
    # Create files and cache their contents
    for my $i (1..3) {
        my $path = "$tempdir/cached$i.txt";
        file::spew($path, "data $i");
        $cache->set($path, file::slurp($path));
    }
    
    my @paths = map { "$tempdir/cached$_.txt" } (1..3);
    
    # Get from cache
    my @cached = map { $cache->get($_) } @paths;
    is(scalar(@cached), 3, 'retrieved 3 cached contents');
    like($cached[0], qr/data 1/, 'first cached content correct');
};

# ============================================
# All three modules combined
# ============================================
subtest 'util + file + lru combined' => sub {
    my $cache = lru->new(10);
    
    # Create files with numeric content
    my @nums = (5, 15, 25);
    for my $i (0..$#nums) {
        my $path = "$tempdir/num$i.txt";
        file::spew($path, $nums[$i]);
    }
    
    my @paths = map { "$tempdir/num$_.txt" } (0..2);
    
    # Read files, cache them, and process with util
    for (@paths) {
        my $content = file::slurp($_);
        $cache->set($_, $content + 0);  # Store as number
    }
    
    # Get cached values and clamp
    my @cached = map { $cache->get($_) } @paths;
    my @clamped = map { util::clamp($_, 10, 20) } @cached;
    is_deeply(\@clamped, [10, 15, 20], 'read->cache->clamp pipeline works');
};

# ============================================
# Nested loop with multiple modules
# ============================================
subtest 'nested loop with multiple modules' => sub {
    my $cache = lru->new(20);
    
    # Create a matrix of files
    for my $row (1..2) {
        for my $col (1..3) {
            my $path = "$tempdir/matrix_${row}_${col}.txt";
            my $value = $row * 10 + $col;
            file::spew($path, $value);
            $cache->set($path, $value);
        }
    }
    
    my @result;
    for my $row (1..2) {
        my @row_vals;
        for my $col (1..3) {
            my $path = "$tempdir/matrix_${row}_${col}.txt";
            my $val = $cache->get($path);
            my $clamped = util::clamp($val, 12, 22);
            my $v = $clamped;  # Force scalar context
            push @row_vals, $v;
        }
        push @result, \@row_vals;
    }
    
    # Row 1: 11,12,13 -> clamped to 12,12,13
    # Row 2: 21,22,23 -> clamped to 21,22,22
    is_deeply($result[0], [12, 12, 13], 'first row clamped');
    is_deeply($result[1], [21, 22, 22], 'second row clamped');
};

# ============================================
# Error handling across modules
# ============================================
subtest 'missing file with cache fallback' => sub {
    my $cache = lru->new(10);
    $cache->set('default', 'fallback_value');
    
    my @paths = ("$tempdir/exists.txt", "$tempdir/missing.txt");
    file::spew($paths[0], 'real_content');
    
    my @contents = map {
        file::exists($_) ? file::slurp($_) : $cache->get('default')
    } @paths;
    
    is($contents[0], 'real_content', 'existing file read');
    is($contents[1], 'fallback_value', 'missing file uses cache fallback');
};

# ============================================
# Conditional module usage
# ============================================
subtest 'conditional module usage' => sub {
    my @items = (
        { type => 'file', path => "$tempdir/cond1.txt", value => 100 },
        { type => 'cache', key => 'cond_key', value => 200 },
        { type => 'number', value => 300 },
    );
    
    # Setup
    file::spew($items[0]{path}, $items[0]{value});
    my $cache = lru->new(10);
    $cache->set($items[1]{key}, $items[1]{value});
    
    my @results;
    for my $item (@items) {
        my $val;
        if ($item->{type} eq 'file') {
            $val = file::slurp($item->{path}) + 0;
        } elsif ($item->{type} eq 'cache') {
            $val = $cache->get($item->{key});
        } else {
            $val = $item->{value};
        }
        my $clamped = util::clamp($val, 150, 250);
        push @results, $clamped;
    }
    
    is_deeply(\@results, [150, 200, 250], 'conditional module usage with clamp');
};

done_testing();
