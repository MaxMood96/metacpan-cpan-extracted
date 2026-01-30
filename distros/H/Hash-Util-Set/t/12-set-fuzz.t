#!perl
use strict;
use warnings;

use Test::More;

BEGIN {
  use_ok('Hash::Util::Set::PP', qw[ keys_union
                                    keys_intersection
                                    keys_difference
                                    keys_symmetric_difference
                                    keys_disjoint
                                    keys_equal
                                    keys_subset
                                    keys_proper_subset
                                    keys_superset
                                    keys_proper_superset
                                    keys_any
                                    keys_all
                                    keys_none
                                    keys_partition ]);
}

{
  package MyTiedHash;
  sub TIEHASH  { bless {}, shift }
  sub SCALAR   { scalar %{$_[0]} }
  sub STORE    { $_[0]{$_[1]} = $_[2] }
  sub FETCH    { $_[0]{$_[1]} }
  sub EXISTS   { exists $_[0]{$_[1]} }
  sub DELETE   { delete $_[0]{$_[1]} }
  sub CLEAR    { %{$_[0]} = () }
  sub FIRSTKEY { my $a = scalar keys %{$_[0]}; each %{$_[0]} }
  sub NEXTKEY  { each %{$_[0]} }
}

sub TRUE    () { !!1 }
sub FALSE   () { !!0 }

sub MAX_KEY () {   64 }
sub ROUNDS  () { 1000 }

sub rand_hash {
  my ($use_tied_hash) = @_;

  my %h;
  if ($use_tied_hash) {
    tie %h, 'MyTiedHash';
  }

  for my $k (0..MAX_KEY - 1) {
    $h{$k} = 1 if rand() < 0.5;
  }
  return %h;
}

sub hash_to_vec {
  my ($h) = @_;
  my $v = "\x00" x 8;
  vec($v, $_, 1) = 1 for keys %$h;
  return $v;
}

sub vec_keys {
  my ($v) = @_;
  return grep { vec($v, $_, 1) } 0..MAX_KEY - 1;
}

sub vec_keys_count {
  my ($v) = @_;
  return scalar grep { vec($v, $_, 1) } 0..MAX_KEY - 1;
}

sub vec_any {
  my ($v, @k) = @_;
  return FALSE unless @k;
  for (@k) {
    return TRUE if vec($v, $_, 1);
  }
  return FALSE;
}

sub vec_all {
  my ($v, @k) = @_;
  for (@k) {
    return FALSE unless vec($v, $_, 1);
  }
  return TRUE;
}

sub vec_none {
  my ($v, @k) = @_;
  for (@k) {
    return FALSE if vec($v, $_, 1);
  }
  return TRUE;
}

foreach my $round (1..ROUNDS) {
  my $use_tied_hash = ($round >= (ROUNDS - 100));
  my %x = rand_hash($use_tied_hash);
  my %y = rand_hash($use_tied_hash);

  my $vx = hash_to_vec(\%x);
  my $vy = hash_to_vec(\%y);

  vec($vx, MAX_KEY - 1, 1) |= 0;
  vec($vy, MAX_KEY - 1, 1) |= 0;
  
  my $subtest = sprintf 'round:%d hash:%s x=%d y=%d',
    $round, ($use_tied_hash ? 'tied' : 'plain'), , scalar keys %x, scalar keys %y;

  subtest $subtest => sub {
    {
      my $exp_vec = $vx | $vy;
      {
        my $got = [ sort { $a <=> $b } keys_union %x, %y ];
        my $exp = [ vec_keys($exp_vec) ];
        is_deeply($got, $exp, 'union - list context');
      }
      {
        my $got = keys_union %x, %y;
        my $exp = vec_keys_count($exp_vec);
        is($got, $exp, 'union - scalar context');
      }
    }

    {
      my $exp_vec = $vx & $vy;
      {
        my $got = [ sort { $a <=> $b } keys_intersection %x, %y ];
        my $exp = [ vec_keys($exp_vec) ];
        is_deeply($got, $exp, 'intersection - list context');
      }
      {
        my $got = keys_intersection %x, %y;
        my $exp = vec_keys_count($exp_vec);
        is($got, $exp, 'intersection - scalar context');
      }
    }

    {
      my $exp_vec = $vx & ~$vy;
      {
        my $got = [ sort { $a <=> $b } keys_difference %x, %y ];
        my $exp = [ vec_keys($exp_vec) ];
        is_deeply($got, $exp, 'difference - list context');
      }
      {
        my $got = keys_difference %x, %y;
        my $exp = vec_keys_count($exp_vec);
        is($got, $exp, 'difference - scalar context');
      }
    }

    {
      my $exp_vec = $vx ^ $vy;
      {
        my $got = [ sort { $a <=> $b } keys_symmetric_difference %x, %y ];
        my $exp = [ vec_keys($exp_vec) ];
        is_deeply($got, $exp, 'symmetric difference - list context');
      }
      {
        my $got = keys_symmetric_difference %x, %y;
        my $exp = vec_keys_count($exp_vec);
        is($got, $exp, 'symmetric difference - scalar context');
      }
    }
  
    {
      my $exp_vec_only_x = $vx & ~$vy;
      my $exp_vec_both   = $vx & $vy;
      my $exp_vec_only_y = $vy & ~$vx;

      my ($got_only_x, $got_both, $got_only_y) = keys_partition %x, %y;

      {
        my $got = [ sort { $a <=> $b } @$got_only_x ];
        my $exp = [ vec_keys($exp_vec_only_x) ];
        is_deeply($got, $exp, 'keys_partition - only_x');
      }
      {
        my $got = [ sort { $a <=> $b } @$got_both ];
        my $exp = [ vec_keys($exp_vec_both) ];
        is_deeply($got, $exp, 'keys_partition - both');
      }
      {
        my $got = [ sort { $a <=> $b } @$got_only_y ];
        my $exp = [ vec_keys($exp_vec_only_y) ];
        is_deeply($got, $exp, 'keys_partition - only_y');
      }
    }

    {
      my $disjoint        = !($vx & $vy);
      my $equal           = $vx eq $vy;
      my $subset          = !($vx & ~$vy);
      my $proper_subset   = !($vx & ~$vy) && $vx ne $vy;
      my $superset        = !($vy & ~$vx);
      my $proper_superset = !($vy & ~$vx) && $vx ne $vy;
    
      is(keys_disjoint(%x, %y), $disjoint, 'disjoint');
      is(keys_equal(%x, %y), $equal, 'equal' );
      is(keys_subset(%x, %y), $subset, 'subset');
      is(keys_proper_subset(%x, %y), $proper_subset, 'proper subset');
      is(keys_superset(%x, %y), $superset, 'superset');
      is(keys_proper_superset(%x, %y), $proper_superset, 'proper superset');
    }

    {
      my @k = map { int rand MAX_KEY } 0..int rand 10;

      is(keys_any(%x, @k), vec_any($vx, @k), 'keys_any');
      is(keys_all(%x, @k), vec_all($vx, @k), 'keys_all');
      is(keys_none(%x, @k), vec_none($vx, @k), 'keys_none');
    }
  };
}

done_testing;
