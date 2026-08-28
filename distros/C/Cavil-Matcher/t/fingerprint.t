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

my $file_a  = write_file('a.txt',  $block_a);
my $file_ab = write_file('ab.txt', "$block_a\n$block_b");    # shares block_a with a.txt, distinct content
my $file_b  = write_file('b.txt',  $block_b);

my ($hash_a, $hash_ab, $hash_b) = map { Cavil::Matcher::content_hash($_) } $file_a, $file_ab, $file_b;

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

my $seg = File::Spec->catfile($dir, 'index.fp');

subtest 'build writes a segment and reports sane stats' => sub {
  my $st = Cavil::Matcher::fp_build([$file_a, $file_ab, $file_b], $seg, $K, $W);
  ok $st->{ok}, 'build ok';
  ok -s $seg,   'segment file exists';
  is $st->{files}, 3, 'counted all files';
  ok $st->{records} > 0,                'has records';
  ok $st->{distinct} <= $st->{records}, 'distinct <= records';
  is $st->{unique_contents}, 3, 'three distinct contents';
};

my $fp = Cavil::Matcher::fp_open($seg);

subtest 'open validates the segment' => sub {
  ok $fp, 'opened and validated segment';
};

subtest 'exact re-query: full self-containment, ranked first, with a highlight region' => sub {
  my $q    = Cavil::Matcher::fingerprint_file($file_b, $K, $W);
  my @qfps = map { $_->[0] } @$q;
  my $hits = $fp->score(\@qfps, 0);
  ok @$hits, 'got matches';
  my ($self) = grep { $_->[0] eq $hash_b } @$hits;
  ok $self, 'self content is among matches';
  is $self->[2], 1.0, 'containment (query direction) is 1.0';
  is $self->[3], 1.0, 'containment_of (content direction) is 1.0 for the exact same content';
  ok @{$self->[4]} > 0, 'matched regions are returned for highlighting';
  is scalar(grep { @$_ == 3 && $_->[1] >= 0 } @{$self->[4]}), scalar(@{$self->[4]}), 'regions are [sline, span, fp]';

  # each region carries the query fingerprint value it matched, so a caller can map matches to query
  # positions (distinguishing an aligned copy from scattered coincidental hits).
  my %qset = map { $_ => 1 } @qfps;
  is scalar(grep { $qset{$_->[2]} } @{$self->[4]}), scalar(@{$self->[4]}), 'each region names a query fingerprint';
};

subtest 'a shared block is NOT deduplicated away, and both containment directions are reported' => sub {
  my @qfps  = map { $_->[0] } @{Cavil::Matcher::fingerprint_file($file_a, $K, $W)};
  my @rows  = @{$fp->score(\@qfps, 0)};
  my %by    = map { $_->[0] => $_->[2] } @rows;    # query-direction containment
  my %by_of = map { $_->[0] => $_->[3] } @rows;    # content-direction containment
  is $by{$hash_a},    1.0, 'the original content fully contains the query';
  is $by_of{$hash_a}, 1.0, 'and it is exactly the query (content direction 1.0)';
  ok $by{$hash_ab} > 0.9,    'the larger content that embeds the block also contains the query';
  ok $by_of{$hash_ab} < 1.0, 'but it is only partly the query (content direction < 1.0)';
  ok !exists $by{$hash_b},   'the unrelated content is not matched (precision)';
};

subtest 'empty and unrelated queries' => sub {
  is_deeply $fp->score([],        0), [], 'empty query => no matches';
  is_deeply $fp->score([1, 2, 3], 0), [], 'fingerprints absent from the index => no matches';
};

subtest 'top_n limits the ranking' => sub {
  my @qfps = map { $_->[0] } @{Cavil::Matcher::fingerprint_file($file_a, $K, $W)};
  ok @{$fp->score(\@qfps, 1)} <= 1, 'top_n=1 returns at most one';
};

subtest 'content dedup collapses byte-identical copies without losing lookups' => sub {

  # Two files with identical content but different names stand in for the same file shipped across two
  # package versions (rust1.23, rust1.24), which no name parsing could group.
  my $v1  = write_file('pkg-1.0-mod.c', $block_a);
  my $v2  = write_file('pkg-1.1-mod.c', $block_a);
  my @all = ($v1, $v2, $file_b);

  my $plain = Cavil::Matcher::fp_build(\@all, File::Spec->catfile($dir, 'plain.fp'), $K, $W, 0);
  my $dd    = Cavil::Matcher::fp_build(\@all, File::Spec->catfile($dir, 'dedup.fp'), $K, $W, 1);

  is $dd->{duplicate_files}, 1, 'one duplicate content detected';
  ok $plain->{records} > $dd->{records}, 'dedup stores fewer records than the naive build';
  is $dd->{unique_contents}, $plain->{unique_contents}, 'both agree on the number of distinct contents';

  my $fpd    = Cavil::Matcher::fp_open(File::Spec->catfile($dir, 'dedup.fp'));
  my @qfps   = map { $_->[0] } @{Cavil::Matcher::fingerprint_file($v1, $K, $W)};
  my ($self) = grep { $_->[0] eq Cavil::Matcher::content_hash($v1) } @{$fpd->score(\@qfps, 0)};
  is $self->[2], 1.0, 'the deduped content is still fully looked up';
};

subtest 'verify() catches payload corruption that the scan-path open() trusts' => sub {
  my $good = File::Spec->catfile($dir, 'verify.fp');
  Cavil::Matcher::fp_build([$file_a, $file_b], $good, $K, $W);
  ok Cavil::Matcher::fp_open($good)->verify($good), 'an intact segment verifies';

  # Flip a byte inside the record payload: structure stays valid (so open still trusts it), CRC must fail.
  open my $fh, '+<:raw', $good or die;
  my $off = 60;    # past the ~44-byte header, inside the first record
  seek $fh, $off, 0;
  read $fh, my $b, 1;
  seek $fh, $off, 0;
  print $fh chr(ord($b) ^ 0xFF);
  close $fh;

  ok Cavil::Matcher::fp_open($good),                 'still opens (open trusts the CRC of a published cache)';
  ok !Cavil::Matcher::fp_open($good)->verify($good), 'verify() detects the corruption';
};

subtest 'corrupt or foreign files are rejected, not mis-read' => sub {
  is Cavil::Matcher::fp_open(File::Spec->catfile($dir, 'nope.fp')),                    undef, 'missing file => undef';
  is Cavil::Matcher::fp_open(write_file('garbage.fp', 'this is not a segment' x 100)), undef, 'wrong magic => undef';

  open my $in, '<:raw', $seg or die;
  my $bytes = do { local $/; <$in> };
  close $in;
  my $trunc = write_file('trunc.fp', substr($bytes, 0, int(length($bytes) / 2)));
  is Cavil::Matcher::fp_open($trunc), undef, 'truncated segment => undef';
};

done_testing;
