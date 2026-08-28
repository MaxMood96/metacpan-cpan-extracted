# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

use strict;
use warnings;
use Test::More;
use Cavil::Matcher::FpIndex;
use File::Temp qw(tempdir);
use File::Spec;

my $root = tempdir(CLEANUP => 1);
my $src  = File::Spec->catdir($root, 'src');
mkdir $src;

sub write_src {
  my ($name, $text) = @_;
  my $path = File::Spec->catfile($src, $name);
  open my $fh, '>', $path or die "write $path: $!";
  print $fh $text;
  close $fh;
  return $path;
}

my $code_a = join ' ', map {"alpha$_ beta$_ gamma$_ delta$_"} 1 .. 20;
my $code_b = join ' ', map {"omega$_ sigma$_ kappa$_ lambda$_"} 1 .. 20;
my $code_c = join ' ', map {"red$_ green$_ blue$_ white$_"} 1 .. 20;
my $file_a = write_src('a.txt', $code_a);
my $file_b = write_src('b.txt', $code_b);
my $file_c = write_src('c.txt', $code_c);

# Results identify content by hash (filenames live in the caller's database), so match on that.
sub ch { Cavil::Matcher::content_hash($_[0]) }

my $idir = File::Spec->catdir($root, 'index');

subtest 'new persists k/w and a reopened index recovers them' => sub {
  my $idx = Cavil::Matcher::FpIndex->new(dir => $idir, k => 3, w => 4);
  is $idx->k,          3, 'k stored';
  is $idx->w,          4, 'w stored';
  is $idx->generation, 0, 'empty index starts at generation 0';

  # Reopen WITHOUT passing k/w, and with different defaults, to prove config wins over args.
  my $again = Cavil::Matcher::FpIndex->new(dir => $idir, k => 9, w => 9);
  is $again->k, 3, 'k recovered from config, not from args';
  is $again->w, 4, 'w recovered from config, not from args';
};

my $idx = Cavil::Matcher::FpIndex->new(dir => $idir);

subtest 'add_segment builds a segment and bumps the generation' => sub {
  is $idx->add_segment([]), 0, 'empty batch is a no-op';
  my $g = $idx->add_segment([$file_a, $file_b]);
  is $g,               1, 'first segment => generation 1';
  is $idx->generation, 1, 'generation persisted';
};

subtest 'search finds the right file and separates unrelated code' => sub {
  my $hits = $idx->search_file($file_a, 5);
  ok @$hits, 'got matches';
  is $hits->[0][0], ch($file_a), 'best match is the source content';
  is $hits->[0][2], 1.0,         'full containment for the exact file';
  ok !(grep { $_->[0] eq ch($file_c) } @$hits), 'unrelated file c (not indexed) is absent';
};

subtest 'an optional containment floor filters inside the scorer' => sub {
  my $q = $idx->fingerprints_for($file_a);
  is $idx->search($q, 5, 0.99)->[0][0], ch($file_a), 'the exact file clears a high floor';
  is scalar @{$idx->search($q, 5, 1.01)}, 0, 'nothing clears an impossible floor';
  ok scalar @{$idx->search($q, 5, 0)} >= scalar @{$idx->search($q, 5, 0.99)}, 'a higher floor never returns more';
};

subtest 'optional DF-pruning ignores fingerprints that are common across the segment' => sub {

  # A shared block in several files makes its fingerprints common; unique tails keep the files distinct.
  my $shared = join ' ', map {"shared$_ common$_ boiler$_ plate$_"} 1 .. 20;
  my @files  = map { write_src("df$_.txt", "$shared unique${_}a unique${_}b unique${_}c") } 1 .. 6;
  my $ddir   = File::Spec->catdir($root, 'index_df');
  my $dfx    = Cavil::Matcher::FpIndex->new(dir => $ddir, k => 3, w => 4);
  $dfx->add_segment(\@files);

  # A query that is only the shared block matches every file through the common fingerprints...
  my $shared_file = write_src('shared_only.txt', $shared);
  my $q           = $dfx->fingerprints_for($shared_file);
  my $without     = $dfx->search($q, 20, 0, 0);
  ok scalar @$without >= 6, 'without pruning the shared block matches every file carrying it';

  # ...but with a DF cap below the number of carriers, those fingerprints are pruned and the noise collapses.
  my $with = $dfx->search($q, 20, 0, 3);
  ok scalar @$with < scalar @$without, 'DF-pruning drops the common-fingerprint matches';
};

subtest 'incremental add: a second segment is searched alongside the first' => sub {
  my $g = $idx->add_segment([$file_c]);
  is $g, 2, 'second segment => generation 2';
  my $hits = $idx->search_file($file_c, 5);
  is $hits->[0][0], ch($file_c), 'newly added file is found via the delta segment';
  is $hits->[0][2], 1.0,         'full containment';

  # And the original segment is still queryable.
  is $idx->search_file($file_b, 5)->[0][0], ch($file_b), 'first segment still searchable';
};

subtest 'merge compacts to a single base and stays correct' => sub {
  my $g = $idx->merge([$file_a, $file_b, $file_c]);
  is $g, 3, 'merge => generation 3';
  my @segs = @{Cavil::Matcher::Manifest->new(dir => $idir)->segments};
  is scalar @segs, 1, 'exactly one segment after compaction';
  like $segs[0]{file}, qr/^fpbase-/, 'it is a base segment';
  for my $f ($file_a, $file_b, $file_c) {
    is $idx->search_file($f, 5)->[0][0], ch($f), "still finds " . (File::Spec->splitpath($f))[2];
  }
};

subtest 'a second merge sweeps prior-merge orphans, deferring only the last base' => sub {
  $idx->merge([$file_a]);
  opendir my $dh, $idir or die;
  my @fp = grep {/\.fp\z/} readdir $dh;
  closedir $dh;

  # Deferred deletion (readers do not lock): the delta segments retired by the FIRST merge are now gone,
  # but the base the first merge produced is kept one grace period, so current-base + one prior base.
  is scalar(grep {/^fpseg-/} @fp),  0, 'delta segments from before the first merge are deleted';
  is scalar(grep {/^fpbase-/} @fp), 2, 'current base plus the one deferred prior base remain';
};

subtest 'search tolerates a damaged segment instead of dying' => sub {
  $idx->add_segment([$file_b]);                # add a delta so there are two segments
  my @segs    = @{Cavil::Matcher::Manifest->new(dir => $idir)->segments};
  my ($delta) = grep { $_->{file} =~ /^fpseg-/ } @segs;
  my $path    = File::Spec->catfile($idir, $delta->{file});
  open my $fh, '>:raw', $path or die;          # clobber the delta with garbage
  print $fh 'not a segment';
  close $fh;
  my $hits = $idx->search_file($file_a, 5);    # file_a is in the intact base
  is $hits->[0][0], ch($file_a), 'intact base still answers while the broken delta is skipped';
};

subtest 'segment handles are cached across searches and pruned on compaction' => sub {
  my $dir2   = File::Spec->catdir($root, 'index2');
  my $reader = Cavil::Matcher::FpIndex->new(dir => $dir2, k => 3, w => 4);
  $reader->add_segment([$file_a]);
  $reader->add_segment([$file_b]);

  $reader->search_file($file_a, 5);
  my @files = keys %{$reader->{open}};
  is scalar @files, 2, 'both active segments are cached after a search';

  my $handle = $reader->{open}{$files[0]};
  $reader->search_file($file_b, 5);
  is $reader->{open}{$files[0]}, $handle, 'a second search reuses the cached handle instead of reopening';

  $reader->merge([$file_a, $file_b]);
  $reader->search_file($file_a, 5);
  is scalar keys %{$reader->{open}}, 1, 'the handle for a compacted-away segment is dropped, leaving the base';
};

done_testing;
