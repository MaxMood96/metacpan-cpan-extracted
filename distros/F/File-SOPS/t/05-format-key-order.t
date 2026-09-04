#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;

use File::SOPS::Format::YAML;
use File::SOPS::Format::JSON;
use File::SOPS::Metadata;

# ----------------------------------------------------------------------------
# Regression: File::SOPS's MAC is hashed over sorted keys on the encrypt side
# (File::SOPS::_sorted_leaves uses `sort keys %$node`) but over DOCUMENT order
# on the decrypt side (_document_leaves takes its order from an
# order-preserving reparse of the raw text, because Perl's hash iteration
# order is randomized per-process and cannot be trusted to reconstruct the
# original order, and because a file written by sops is in whatever order its
# author wrote it).
#
# For files this library writes, the two sides agree ONLY because both format
# serializers happen to emit hash keys in sorted order: YAML::XS::Dump sorts
# keys, and File::SOPS::Format::JSON builds its encoder with `canonical => 1`.
# Nothing else enforces this. If either serializer stopped sorting, every
# self-produced file would fail MAC verification, and the failure would
# surface as an opaque "MAC verification failed" deep in File::SOPS::decrypt
# -- nowhere near the serializer that actually broke the guarantee.
#
# This test pins the guarantee at its source: it asserts directly on
# serialize() output, so a regression here fails loudly and locally instead
# of three layers away as an unexplained MAC failure.
# ----------------------------------------------------------------------------

# Deliberately unsorted key insertion order, with keys of mixed length, so
# that Perl's randomized hash iteration order is very unlikely to coincide
# with sorted order by chance (8 keys => at most 1/8! chance of a false
# pass if the sort were silently dropped).
my @keys = qw(zebra mango apple kiwi fig elderberry date banana);
my $sorted_keys = [ sort @keys ];

my %data = map { $_ => "value-$_" } @keys;

# Sanity check on the test fixture itself: if Perl's hash order for this
# key set happened to already be sorted, the assertions below would pass
# even with a broken serializer that just preserves hash order. Confirm the
# raw hash order differs from sorted order so the test can actually fail.
my @raw_order = keys %data;
isnt(join(',', @raw_order), join(',', @$sorted_keys),
    'fixture: raw hash key order is not already sorted (test can detect a regression)');

my $key_pattern = join('|', map { quotemeta($_) } @keys);

my $metadata = File::SOPS::Metadata->new;

subtest 'File::SOPS::Format::YAML->serialize emits keys in sorted order' => sub {
  my $yaml = File::SOPS::Format::YAML->serialize(
    data     => \%data,
    metadata => $metadata,
  );

  my @found;
  while ($yaml =~ /^($key_pattern):/mg) {
    push @found, $1;
  }

  is_deeply(\@found, $sorted_keys,
    'top-level keys appear in sorted order in the YAML output');
};

subtest 'File::SOPS::Format::JSON->serialize emits keys in sorted order' => sub {
  my $json = File::SOPS::Format::JSON->serialize(
    data     => \%data,
    metadata => $metadata,
  );

  my @found;
  while ($json =~ /"($key_pattern)"\s*:/g) {
    push @found, $1;
  }

  is_deeply(\@found, $sorted_keys,
    'top-level keys appear in sorted order in the JSON output');
};

done_testing;
