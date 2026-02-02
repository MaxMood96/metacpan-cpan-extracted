#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

# Test file module functions work correctly in map/grep context
# This ensures call checkers properly handle $_ usage

use file;

my $tempdir = tempdir(CLEANUP => 1);

# Create test files
my @files;
for my $i (1..3) {
    my $path = "$tempdir/test$i.txt";
    file::spew($path, "content $i line 1\ncontent $i line 2");
    push @files, $path;
}

# ============================================
# file::slurp in map (1-arg custom op)
# ============================================
subtest 'file::slurp in map' => sub {
    my @contents = map { file::slurp($_) } @files;
    is(scalar(@contents), 3, 'slurp returns 3 results in map');
    like($contents[0], qr/content 1/, 'first file content correct');
    like($contents[1], qr/content 2/, 'second file content correct');
    like($contents[2], qr/content 3/, 'third file content correct');
};

# ============================================
# file::slurp in grep
# ============================================
subtest 'file::slurp in grep' => sub {
    # Create a file with specific content
    my $special = "$tempdir/special.txt";
    file::spew($special, "MARKER_FOUND");
    
    my @test_files = (@files, $special);
    my @matching = grep { file::slurp($_) =~ /MARKER/ } @test_files;
    is(scalar(@matching), 1, 'grep finds 1 matching file');
    is($matching[0], $special, 'correct file matched');
};

# ============================================
# file::exists in map/grep
# ============================================
subtest 'file::exists in map/grep' => sub {
    my $nonexistent = "$tempdir/nonexistent.txt";
    my @test_files = (@files, $nonexistent);
    
    my @existing = grep { file::exists($_) } @test_files;
    is(scalar(@existing), 3, 'grep finds 3 existing files');
    
    my @results = map { file::exists($_) ? 1 : 0 } @test_files;
    is_deeply(\@results, [1, 1, 1, 0], 'map returns correct existence flags');
};

# ============================================
# file::lines in map
# ============================================
subtest 'file::lines in map' => sub {
    # file::lines returns an arrayref
    my @all_lines = map { file::lines($_) } @files;
    is(scalar(@all_lines), 3, 'lines returns 3 arrayrefs in map');
    is(scalar(@{$all_lines[0]}), 2, 'first file has 2 lines');
    is(scalar(@{$all_lines[1]}), 2, 'second file has 2 lines');
};

# ============================================
# Nested map with file operations
# ============================================
subtest 'nested map with file' => sub {
    # Use (\@files) to create array of arrayrefs, not [\@files] which nests an extra level
    my @file_groups = (\@files);
    my @results = map {
        my $group = $_;
        [ map { file::exists($_) ? 1 : 0 } @$group ]
    } @file_groups;
    is_deeply($results[0], [1, 1, 1], 'nested map with file::exists works');
};

# ============================================
# for/foreach loops with file functions
# ============================================
subtest 'file::slurp in foreach loop' => sub {
    my @contents;
    for (@files) {
        push @contents, file::slurp($_);
    }
    is(scalar(@contents), 3, 'slurp in foreach returns 3 results');
    like($contents[0], qr/content 1/, 'first file slurped in foreach');
};

subtest 'file::exists in for loop' => sub {
    my $nonexistent = "$tempdir/nonexistent.txt";
    my @test_files = (@files, $nonexistent);
    
    my $count = 0;
    for (@test_files) {
        $count++ if file::exists($_);
    }
    is($count, 3, 'exists counts correctly in for loop with $_');
};

subtest 'nested for with file operations' => sub {
    my @file_groups = (\@files);
    my @results;
    for my $group (@file_groups) {
        my @exists;
        for (@$group) {
            push @exists, file::exists($_) ? 1 : 0;
        }
        push @results, \@exists;
    }
    is_deeply($results[0], [1, 1, 1], 'nested for with file::exists works');
};

done_testing();
