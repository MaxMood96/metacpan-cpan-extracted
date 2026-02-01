#!/usr/bin/env perl
# Integration test: file + nvec + util for file-based data processing
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use lib 'blib/lib', 'blib/arch';

use file;
use nvec;
use util;
use const;

my $tmpdir = tempdir(CLEANUP => 1);

subtest 'read numeric data into nvec' => sub {
    my $datafile = "$tmpdir/numbers.txt";
    file::spew($datafile, "10\n20\n30\n40\n50");
    
    my $lines = file::lines($datafile);
    my @nums = map { $_ + 0 } @$lines;
    
    my $vec = nvec::new(\@nums);
    is($vec->len, 5, 'nvec has 5 elements');
    is($vec->sum, 150, 'sum is 150');
    is($vec->mean, 30, 'mean is 30');
};

subtest 'filter and transform file data' => sub {
    my $datafile = "$tmpdir/mixed.txt";
    file::spew($datafile, "-5\n10\n-3\n20\n-1\n30");
    
    my @collected;
    file::each_line($datafile, sub {
        my $val = shift;
        push @collected, $val if util::is_positive($val);
    });
    
    is_deeply(\@collected, [10, 20, 30], 'filtered positive values');
    
    my $vec = nvec::new(\@collected);
    my $scaled = $vec->scale(2);
    is_deeply($scaled->to_array, [20, 40, 60], 'scaled values correctly');
};

subtest 'compute statistics and write results' => sub {
    my $input = "$tmpdir/stats_in.txt";
    my $output = "$tmpdir/stats_out.txt";
    
    file::spew($input, "1\n2\n3\n4\n5\n6\n7\n8\n9\n10");
    
    my $lines = file::lines($input);
    my @nums = map { $_ + 0 } @$lines;
    my $vec = nvec::new(\@nums);
    
    my $results = sprintf("sum=%d\nmean=%.1f\nlen=%d", 
        $vec->sum, $vec->mean, $vec->len);
    
    file::spew($output, $results);
    
    my $written = file::slurp($output);
    like($written, qr/sum=55/, 'sum written');
    like($written, qr/mean=5\.5/, 'mean written');
    like($written, qr/len=10/, 'length written');
};

subtest 'iterator with clamp' => sub {
    my $datafile = "$tmpdir/clamp.txt";
    file::spew($datafile, "5\n50\n500\n5000");
    
    ok(file::exists($datafile), 'clamp file created');
    
    my $iter = file::lines_iter($datafile);
    my @clamped;
    
    while (!$iter->eof) {
        my $line = $iter->next;
        last unless defined $line;
        my $v = util::clamp($line + 0, 10, 100);
        push @clamped, $v;
    }
    
    is_deeply(\@clamped, [10, 50, 100, 100], 'clamped values correctly');
};

subtest 'freeze config data' => sub {
    my $path = "$tmpdir/frozen_test.txt";
    file::spew($path, "test content");
    
    my $config = const::c({ path => $path, created => time() });
    ok(const::is_readonly($config->{path}), 'config values are frozen');
    
    my $content = file::slurp($config->{path});
    is($content, "test content", 'read from config path works');
};

done_testing();
