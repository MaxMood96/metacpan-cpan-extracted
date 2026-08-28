# SPDX-FileCopyrightText: SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# FpIndex is to fingerprint segments what Index is to pattern segments: the Perl-maximal lifecycle layer
# over a directory of compiled fingerprint segments. Adding a batch of files compiles ONE new segment and
# appends it to the manifest; a rare compaction ("merge") rebuilds a single base segment from the full
# file set. A query opens the active segments (memory-mapped, shared across workers) and scores a snippet
# by containment. The native engine only winnows and searches; every decision about which segments are
# active lives here.
#
# It deliberately reuses Cavil::Matcher::Manifest (generation, atomic save, segment list) and the same
# concurrency and deferred-deletion discipline as Index. Fingerprint segments carry no per-pattern ids, so
# the manifest's tombstone machinery is simply unused, and the per-segment "pattern_count" slot records
# the fingerprint record count instead.
#
# WHAT LIVES HERE vs IN CAVIL. This layer manages segments on one host. Two decisions that need Cavil's
# database are deliberately NOT here: (1) skipping a package version whose content was already fingerprinted
# (content-addressing by checkout checksum), and (2) mapping a matched file back to the packages/versions
# that carry it. build_fp_segment already deduplicates byte-identical files WITHIN one build; global,
# cross-build content dedup and the content->packages mapping belong in Cavil, where the source of truth is.

package Cavil::Matcher::FpIndex;

use strict;
use warnings;
use v5.20;
use feature 'signatures';
no warnings 'experimental::signatures';

use Cavil::Matcher;
use Cavil::Matcher::Manifest;
use Carp 'croak';
use Fcntl ':flock';
use File::Spec;
use Cpanel::JSON::XS ();

# k (tokens per gram) and w (grams per window) must be identical for every segment in an index and for
# every query against it, or fingerprints would not line up. They are fixed when the index is first
# created and persisted beside the segments, so a reopened index always winnows queries the same way.
sub new ($class, %args) {
  croak 'dir required' unless defined $args{dir};
  my $dir = $args{dir};
  mkdir $dir                                unless -d $dir;
  croak "index dir $dir is not a directory" unless -d $dir;

  my $self = bless {dir => $dir}, $class;
  if (my $cfg = $self->_read_config) {
    ($self->{k}, $self->{w}) = ($cfg->{k}, $cfg->{w});
  }
  else {
    $self->{k} = $args{k} // 5;
    $self->{w} = $args{w} // 64;
    $self->_write_config;
  }
  return $self;
}

sub dir        ($self) { $self->{dir} }
sub k          ($self) { $self->{k} }
sub w          ($self) { $self->{w} }
sub generation ($self) { $self->_manifest->generation }
sub _manifest  ($self) { Cavil::Matcher::Manifest->new(dir => $self->{dir}) }

sub _config_path ($self) { File::Spec->catfile($self->{dir}, 'fpconfig.json') }

sub _read_config ($self) {
  my $path = $self->_config_path;
  return undef unless -f $path;
  my $json = do {
    open my $fh, '<:raw', $path or return undef;    # uncoverable branch true (unreadable after stat)
    local $/;
    <$fh>;
  };
  my $data = eval { Cpanel::JSON::XS->new->decode($json) };
  return undef unless ref $data eq 'HASH';
  my ($k, $w) = ($data->{k}, $data->{w});
  return undef unless defined $k && !ref $k && $k =~ /^\d+$/ && defined $w && !ref $w && $w =~ /^\d+$/;
  return {k => 0 + $k, w => 0 + $w};
}

sub _write_config ($self) {
  my $path = $self->_config_path;
  my $tmp  = "$path.tmp.$$";
  my $json = Cpanel::JSON::XS->new->canonical->encode({k => $self->{k}, w => $self->{w}});
  open my $fh, '>:raw', $tmp or croak "cannot write fpconfig: $!";    # uncoverable branch true (I/O error)
  print {$fh} $json or croak "cannot write fpconfig: $!";             # uncoverable branch true (I/O error)
  close $fh         or croak "cannot write fpconfig: $!";             # uncoverable branch true (I/O error)
  rename $tmp, $path or croak "cannot rename fpconfig: $!";
  return $self;
}

# Serialize mutations on one host, exactly as Index does: an exclusive advisory flock held around the
# whole read-modify-save. Readers (search) never lock; the manifest swap is atomic and merge defers
# deleting retired segments, so a reader that read the old manifest can still mmap the files it named.
sub _locked ($self, $code) {
  my $path = File::Spec->catfile($self->{dir}, '.fplock');
  open my $lock, '>', $path or croak "cannot open index lock $path: $!";    # uncoverable branch true (I/O error)
  flock $lock, LOCK_EX or croak "cannot lock index $path: $!";              # uncoverable branch true (flock failure)
  return $code->();
}

# Manifest-level integrity checksum of a segment file (on top of the segment's own internal CRC), using
# the engine's hash so no extra dependency is needed.
sub _checksum ($path) {
  open my $fh, '<:raw', $path or return '';    # uncoverable branch true (callers verify -r first)
  my $ctx = Cavil::Matcher::init_hash(0, 0);
  local $/ = \65536;
  while (my $chunk = <$fh>) { $ctx->add($chunk) }
  close $fh;
  return $ctx->hex;
}

# Incrementally add a batch of files as one new fingerprint segment. Existing segments are untouched.
# $files is an arrayref of paths. Byte-identical files within the batch are stored once (see the module
# header for why cross-build dedup lives in Cavil). Returns the new generation.
sub add_segment ($self, $files) {
  return $self->generation unless $files && @$files;
  return $self->_locked(sub {
    my $man  = $self->_manifest;
    my $gen  = $man->bump;
    my $file = sprintf('fpseg-%010d.fp', $gen);
    my $path = File::Spec->catfile($self->{dir}, $file);
    my $st   = Cavil::Matcher::fp_build($files, $path, $self->{k}, $self->{w}, 1);
    croak "failed to build fingerprint segment $file" unless $st->{ok};

    my $checksum = _checksum($path);
    croak "failed to checksum new segment $file" unless length $checksum;    # uncoverable branch true (I/O race)
    $man->add_segment(file => $file, checksum => $checksum, pattern_count => $st->{records});
    $man->save;
    return $gen;
  });
}

# Rare compaction: rebuild a single base segment from the full file set and retire every existing segment.
# Reading the full set from the caller (Cavil, from its database) keeps the source of truth outside the
# cache, exactly as Index::merge does for patterns. Returns the new generation.
sub merge ($self, $files) {
  return $self->_locked(sub {
    my $man  = $self->_manifest;
    my $gen  = $man->bump;
    my $file = sprintf('fpbase-%010d.fp', $gen);
    my $path = File::Spec->catfile($self->{dir}, $file);
    my $st   = Cavil::Matcher::fp_build($files // [], $path, $self->{k}, $self->{w}, 1);
    croak "failed to build base fingerprint segment $file" unless $st->{ok};

    my $checksum = _checksum($path);
    croak "failed to checksum new base segment $file" unless length $checksum;    # uncoverable branch true (I/O race)
    my @old = map { $_->{file} } @{$man->segments};
    $man->set_segments({file => $file, checksum => $checksum, pattern_count => $st->{records}});
    $man->save;

    # Deferred deletion, identical in spirit to Index::merge: readers do not lock, so we retire @old only
    # at the NEXT merge. Here we delete files orphaned by a PREVIOUS merge and any crash-leftover temp
    # files. Compaction is rare, so "one merge ago" is an ample grace period for a reader's
    # read-manifest-then-mmap window.
    my %keep = map { $_ => 1 } (@old, $file);
    if (opendir my $dh, $self->{dir}) {    # uncoverable branch false (the index dir always exists here)
      for my $f (readdir $dh) {
        my $orphan = $f =~ /^(?:fpseg|fpbase)-[0-9]+\.fp\z/ && !$keep{$f};
        my $stale  = $f =~ /\.tmp(?:\.[0-9]+)?\z/;    # Manifest's .tmp.<pid> and fp_build's <name>.tmp
        unlink File::Spec->catfile($self->{dir}, $f) if $orphan || $stale;
      }
      closedir $dh;
    }
    return $gen;
  });
}

# Winnow a file into the query fingerprints this index expects (its own k/w). A snippet supplied as text
# should be written to a file first; keeping the reader in one place (the native, NUL-tolerant one) avoids
# a second, subtly-different tokenization path.
sub fingerprints_for ($self, $path) {
  return [map { $_->[0] } @{Cavil::Matcher::fingerprint_file($path, $self->{k}, $self->{w})}];
}

# Score a query (an arrayref of fingerprint values) against every active segment and return up to $top_n
# candidates as [filename, hits, containment], best containment first. Because each file lives in exactly
# one segment and every segment scores against the same query, per-segment containments are directly
# comparable, so merging is a plain concatenate-and-sort. Damaged or missing segments are skipped, never
# fatal.
#
# $min_containment (optional) drops matches below that containment inside the scorer, so a query full of
# common fingerprints does not ship hundreds of thousands of coincidental matches back for the caller to
# filter. It is a plain floor, so the caller still owns the value and can change it.
#
# $max_df (optional, 0 = off) ignores query fingerprints that appear in more than max_df records of a segment:
# boilerplate that matches nearly everything, coincidentally. It neither adds matches nor counts against
# containment. Off by default so behaviour is unchanged until a caller opts in (a compacted single-segment
# index makes the per-segment record count the true document frequency).
#
# Opened segments are cached and reused across calls, because opening them (memory-mapping and faulting in
# the header) is a fixed cost that otherwise dominates every search on a long-lived query server, regardless
# of the query. Segments are immutable append-only files, so a cached handle always maps the same bytes; a
# handle whose segment has left the manifest (compacted away) is dropped, releasing its mapping.
sub search ($self, $query_fps, $top_n = 10, $min_containment = 0, $max_df = 0) {
  my $man   = $self->_manifest;
  my $cache = $self->{open} //= {};

  my (%active, @all);
  for my $seg (@{$man->segments}) {
    my $file = $seg->{file};
    $active{$file} = 1;
    my $fp = $cache->{$file};
    unless ($fp) {
      my $path = File::Spec->catfile($self->{dir}, $file);
      next unless -r $path;
      $fp = Cavil::Matcher::fp_open($path) or next;
      $cache->{$file} = $fp;
    }
    push @all, @{$fp->score($query_fps, $top_n > 0 ? $top_n : 0, $min_containment, $max_df)};
  }
  delete @$cache{grep { !$active{$_} } keys %$cache};

  @all = sort { $b->[2] <=> $a->[2] } @all;
  @all = @all[0 .. $top_n - 1] if $top_n > 0 && @all > $top_n;
  return \@all;
}

# Convenience: winnow a file and search in one step.
sub search_file ($self, $path, $top_n = 10) {
  return $self->search($self->fingerprints_for($path), $top_n);
}

1;
