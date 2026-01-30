#!perl
use strict;
use warnings;

use Test::More;

BEGIN {
  use_ok('Hash::Util::Join::PP', qw[ hash_inner_join
                                     hash_left_join
                                     hash_right_join
                                     hash_outer_join
                                     hash_left_anti_join
                                     hash_right_anti_join
                                     hash_full_anti_join ]);
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

    # Inner join
    {
      my $exp_vec  = $vx & $vy;
      my %exp      = map { $_ => $y{$_} } vec_keys($exp_vec);
      {
        my %got = hash_inner_join %x, %y;
        is_deeply(\%got, \%exp, 'inner join - list context');
      }
      {
        my $got = hash_inner_join %x, %y;
        is_deeply($got, \%exp, 'inner join - scalar context');
      }
    }

    # Left join
    {
      my $exp_vec  = $vx;
      my %exp      = map {
        $_ => exists $y{$_} ? $y{$_} : $x{$_}
      } vec_keys($exp_vec);

      {
        my %got = hash_left_join %x, %y;
        is_deeply(\%got, \%exp, 'left join - list context');
      }
      {
        my $got = hash_left_join %x, %y;
        is_deeply($got, \%exp, 'left join - scalar context');
      }
    }

    # Right join
    {
      my $exp_vec  = $vy;
      my %exp      = map {
        $_ => exists $x{$_} ? $x{$_} : $y{$_}
      } vec_keys($exp_vec);

      {
        my %got = hash_right_join %x, %y;
        is_deeply(\%got, \%exp, 'rigth join - list context');

      }
      {
        my $got = hash_right_join %x, %y;
        is_deeply($got, \%exp, 'rigth join - scalar context');

      }
    }

    # Outer join
    {
      my $exp_vec  = $vx | $vy;
      my %exp      = map {
        $_ => exists $y{$_} ? $y{$_} : $x{$_}
      } vec_keys($exp_vec);

      {
        my %got = hash_outer_join %x, %y;
        is_deeply(\%got, \%exp, 'outer join - list context');
      }
      {
        my $got = hash_outer_join %x, %y;
        is_deeply($got, \%exp, 'outer join - scalar context');
      }
    }

    # Left anti join
    {
      my $exp_vec = $vx & ~$vy;
      my @exp_keys = vec_keys($exp_vec);
      my %exp = map { $_ => $x{$_} } @exp_keys;
      {
        my %got = hash_left_anti_join %x, %y;
        is_deeply(\%got, \%exp, 'left anti join - list context');
      }
      {
        my $got = hash_left_anti_join %x, %y;
        is_deeply($got, \%exp, 'left anti join - scalar context');
      }
    }

    # Right anti join
    {
      my $exp_vec = $vy & ~$vx;
      my @exp_keys = vec_keys($exp_vec);
      my %exp = map { $_ => $y{$_} } @exp_keys;

      {
        my %got = hash_right_anti_join %x, %y;
        is_deeply(\%got, \%exp, 'right anti join - list context');
      }
      {
        my $got = hash_right_anti_join %x, %y;
        is_deeply($got, \%exp, 'right anti join - scalar context');
      }
    }

    # Full anti join
    {
      my $exp_vec = $vx ^ $vy;
      my @exp_keys = vec_keys($exp_vec);
      my %exp = map {
        $_ => exists $x{$_} ? $x{$_} : $y{$_}
      } @exp_keys;

      {
        my %got = hash_full_anti_join %x, %y;
        is_deeply(\%got, \%exp, 'full anti join - list context');
      }
      {
        my $got = hash_full_anti_join %x, %y;
        is_deeply($got, \%exp, 'full anti join - scalar context');
      }
    }

    # Test with custom merge function
    {
      my $exp_vec  = $vx & $vy;
      my @exp_keys = vec_keys($exp_vec);
      my %exp = map {
        $_ => $x{$_} + $y{$_}
      } @exp_keys;

      {
        my %got = hash_inner_join %x, %y, sub { $_[1] + $_[2] };
        is_deeply(\%got, \%exp, 'custom merge - list context');
      }
      {
        my $got = hash_inner_join %x, %y, sub { $_[1] + $_[2] };
        is_deeply($got, \%exp, 'custom merge - scalar context');
      }
    }
  };
}

done_testing;
