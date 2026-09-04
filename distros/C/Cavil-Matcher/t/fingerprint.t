# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use strict;
use warnings;
use Test::More;
use Cavil::Matcher;
use File::Temp qw(tempdir);
use File::Spec;

# Small k/w so tiny fixtures still winnow to fingerprints (density ~2/(w+1)).
my ($K, $W) = (3, 4);
my $dir = tempdir(CLEANUP => 1);

sub write_file {
  my ($name, $text) = @_;
  my $path = File::Spec->catfile($dir, $name);
  open my $fh, '>', $path or die "write $path: $!";
  print $fh $text;
  close $fh;
  return $path;
}

my $block_a = join ' ', map {"alpha$_ beta$_ gamma$_ delta$_"} 1 .. 20;
my $block_b = join ' ', map {"omega$_ sigma$_ kappa$_ lambda$_"} 1 .. 20;

my $file_a = write_file('a.txt', $block_a);
my $file_b = write_file('b.txt', $block_b);

my ($hash_a, $hash_b) = map { Cavil::Matcher::content_hash($_) } $file_a, $file_b;

subtest 'content_hash is a stable 32-hex digest of the bytes' => sub {
  like $hash_a, qr/^[0-9a-f]{32}$/, '32 hex chars';
  is $hash_a,   Cavil::Matcher::content_hash($file_a), 'same file, same hash';
  isnt $hash_a, $hash_b,                               'different content, different hash';
};

subtest 'fingerprint_file is deterministic with exact line spans' => sub {
  my $fp1 = Cavil::Matcher::fingerprint_file($file_a, $K, $W);
  my $fp2 = Cavil::Matcher::fingerprint_file($file_a, $K, $W);
  ok @$fp1 > 0, 'produced fingerprints';
  is_deeply $fp2, $fp1, 'identical input yields identical fingerprints';
  is scalar(grep { @$_ == 3 && $_->[2] >= $_->[1] } @$fp1), scalar(@$fp1), 'each row is [fp, sline, eline]';
};

subtest 'fingerprint_file on missing/empty input never dies' => sub {
  is_deeply Cavil::Matcher::fingerprint_file(File::Spec->catfile($dir, 'nope.txt'), $K, $W), [],
    'missing file => empty';
  is_deeply Cavil::Matcher::fingerprint_file(write_file('empty.txt', ''),       $K, $W), [], 'empty file => empty';
  is_deeply Cavil::Matcher::fingerprint_file(write_file('tiny.txt', 'one two'), $K, $W), [], 'sub-k-gram file => empty';
};

done_testing;
