#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use AppPtpTest;
use File::Temp;
use Test::More;

unless ($^O =~ /cygwin|linux/) {
  plan skip_all => 'Shell tests disabled on non-linux-like platform.';
}

{
  my $temp = File::Temp->new();
  my $f = $temp->filename;
  ptp(['--shell', "cat > $f"], \"foo\nbar\nbaz\n");
  is(slurp($f), "foo\nbar\nbaz\n", 'works');
}{
  my $temp = File::Temp->new();
  my $f = $temp->filename;
  my $out = ptp(['--shell', "cat > $f"], \"foo\nbar\nbaz\n");
  is($out, "", 'eat the output');
}{
  my $temp = File::Temp->new();
  my $f = $temp->filename;
  my $out = ptp(['--push', '--shell', "cat > $f", '--pop'], \"foo\nbar\nbaz\n");
  is($out, "foo\nbar\nbaz\n", 'restore the output');
}{
  my $temp = File::Temp->new();
  my $f = $temp->filename;
  my $out = ptp(['--push', '--shell', "cat > $f", '--pop', '--eat'], \"foo\nbar\nbaz\n");
  is($out, "", 'restore and then eat the output');
}{
  my $temp = File::Temp->new();
  my $f = $temp->filename;
  my $out = ptp(['--shell', "echo \"foo\" > $f"], \"foo\nbar\nbaz\n");
  is(slurp($f), "foo\n", 'command with quote');
}{
  my $temp = File::Temp->new();
  my $f = $temp->filename;
  my $out = ptp(['-Q', '--shell', "echo \"foo\" > $f"], \"foo\nbar\nbaz\n");
  is(slurp($f), "foo\n", 'escape command with quote');
}{
  my $temp = File::Temp->new();
  my $f = $temp->filename;
  my $out = ptp(['-e', '$a = "abc"', '--shell', "echo \"\$a\" > $f"], \"foo\nbar\nbaz\n");
  is(slurp($f), "abc\n", 'interpolate variable');
}{
  my $temp = File::Temp->new();
  my $f = $temp->filename;
  ptp(['--xargs', "echo {} >> $f"], \"foo\nbar\nbaz\n");
  is(slurp($f), "foo\nbar\nbaz\n", 'xargs');
}

done_testing();
