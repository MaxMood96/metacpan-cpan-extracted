package Hash::Util::Join::PP;
use strict;
use warnings;

use Exporter        qw[import];
use Hash::Util::Set qw[:operations];

our $VERSION   = '0.06';
our @EXPORT_OK = qw[ hash_inner_join
                     hash_left_join
                     hash_right_join
                     hash_outer_join
                     hash_left_anti_join
                     hash_right_anti_join
                     hash_full_anti_join ];

our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub hash_inner_join(\%\%;&) {
  my ($x, $y, $merge_fn) = @_;
  $merge_fn //= sub { $_[2] };
  my %result;
  foreach my $k (keys_intersection %$x, %$y) {
    $result{$k} = $merge_fn->($k, $x->{$k}, $y->{$k});
  }
  return wantarray ? %result : \%result;
}

sub hash_left_join(\%\%;&) {
  my ($x, $y, $merge_fn) = @_;
  $merge_fn //= sub { $_[2] // $_[1] };
  my %result;
  foreach my $k (keys %$x) {
    $result{$k} = $merge_fn->($k, $x->{$k}, $y->{$k});
  }
  return wantarray ? %result : \%result;
}

sub hash_right_join(\%\%;&) {
  my ($x, $y, $merge_fn) = @_;
  $merge_fn //= sub { $_[2] // $_[1] };
  my %result;
  foreach my $k (keys %$y) {
    $result{$k} = $merge_fn->($k, $x->{$k}, $y->{$k});
  }
  return wantarray ? %result : \%result;
}

sub hash_outer_join(\%\%;&) {
  my ($x, $y, $merge_fn) = @_;
  $merge_fn //= sub { $_[2] // $_[1] };
  my %result;
  foreach my $k (keys_union %$x, %$y) {
    $result{$k} = $merge_fn->($k, $x->{$k}, $y->{$k});
  }
  return wantarray ? %result : \%result;
}

sub hash_left_anti_join(\%\%) {
  my ($x, $y) = @_;
  my %result = map { $_ => $x->{$_} } keys_difference %$x, %$y;
  return wantarray ? %result : \%result;
}

sub hash_right_anti_join(\%\%) {
  my ($x, $y) = @_;
  my %result = map { $_ => $y->{$_} } keys_difference %$y, %$x;
  return wantarray ? %result : \%result;
}

sub hash_full_anti_join(\%\%) {
  my ($x, $y) = @_;
  my %result;
  foreach my $k (keys_symmetric_difference %$x, %$y) {
    $result{$k} = exists $x->{$k} ? $x->{$k} : $y->{$k};
  }
  return wantarray ? %result : \%result;
}

BEGIN {
  delete @Hash::Util::Join::PP::{qw[ keys_union
                                     keys_intersection
                                     keys_difference
                                     keys_symmetric_difference
                                     keys_partition ]};
}

1;
