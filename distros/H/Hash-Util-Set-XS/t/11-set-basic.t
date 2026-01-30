#!perl
use strict;
use warnings;

use utf8;
use open ':std', ':encoding(UTF-8)';

use Test::More;

BEGIN {
  use_ok('Hash::Util::Set::XS', qw[ keys_union
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

subtest 'Testing with empty hashes' => sub {
  my %x = ();
  my %y = ();

  is_deeply([ keys_union %x, %y ], [], 'union of empty hashes');
  is_deeply([ keys_intersection %x, %y ], [], 'intersection of empty hashes');
  is_deeply([ keys_difference %x, %y ], [], 'difference of empty hashes');
  is_deeply([ keys_symmetric_difference %x, %y ], [], 'symmetric difference of empty hashes');

  ok(keys_disjoint(%x, %y), 'empty hashes are disjoint');
  ok(keys_equal(%x, %y), 'empty hashes are equal');
  ok(keys_subset(%x, %y), 'empty is subset of empty');
  ok(!keys_proper_subset(%x, %y), 'empty is not proper subset of empty');
  ok(keys_superset(%x, %y), 'empty is superset of empty');
  ok(!keys_proper_superset(%x, %y), 'empty is not proper superset of empty');
};

subtest 'Testing empty vs non-empty' => sub {
  my %empty = ();
  my %full = (a => 1, b => 2, c => 3);

  {
    my $got = [ sort { $a cmp $b } keys_union %empty, %full ];
    is_deeply($got, [qw(a b c)], 'union: empty + full');
  }

  is_deeply([ keys_intersection %empty, %full ], [], 'intersection: empty ∩ full');
  is_deeply([ keys_difference %empty, %full ], [], 'difference: empty - full');

  {
    my $got = [ sort { $a cmp $b } keys_difference %full, %empty ];
    is_deeply($got, [qw(a b c)], 'difference: full - empty');
  }

  {
    my $got = [ sort { $a cmp $b } keys_symmetric_difference %empty, %full ];
    is_deeply($got, [qw(a b c)], 'symmetric difference: empty △ full');
  }

  ok(keys_disjoint(%empty, %full), 'empty and full are disjoint');
  ok(!keys_equal(%empty, %full), 'empty ≠ full');
  ok(keys_subset(%empty, %full), 'empty ⊆ full');
  ok(keys_proper_subset(%empty, %full), 'empty ⊂ full');
  ok(!keys_subset(%full, %empty), 'full ⊄ empty');
  ok(keys_superset(%full, %empty), 'full ⊇ empty');
  ok(keys_proper_superset(%full, %empty), 'full ⊃ empty');
};

subtest 'Testing identical hashes' => sub {
  my %x = (a => 1,  b => 2,  c => 3);
  my %y = (a => 10, b => 20, c => 30);

  {
    my $got = [ sort { $a cmp $b } keys_union %x, %y ];
    is_deeply($got, [qw(a b c)], 'union: identical keys');
  }

  {
    my $got = [ sort { $a cmp $b } keys_intersection %x, %y ];
    is_deeply($got, [qw(a b c)], 'intersection: identical keys');
  }

  is_deeply([ keys_difference %x, %y ], [], 'difference: identical keys');
  is_deeply([ keys_symmetric_difference %x, %y ], [], 'symmetric difference: identical keys');

  ok(!keys_disjoint(%x, %y), 'identical keys are not disjoint');
  ok(keys_equal(%x, %y), 'identical keys are equal');
  ok(keys_subset(%x, %y), 'identical keys: subset');
  ok(!keys_proper_subset(%x, %y), 'identical keys: not proper subset');
  ok(keys_superset(%x, %y), 'identical keys: superset');
  ok(!keys_proper_superset(%x, %y), 'identical keys: not proper superset');
};

subtest 'Testing disjoint sets' => sub {
  my %x = (a => 1, b => 2              );
  my %y = (               c => 3, d => 4);

  {
    my $got = [ sort { $a cmp $b } keys_union %x, %y ];
    is_deeply($got, [qw(a b c d)], 'union: disjoint');
  }

  is_deeply([ keys_intersection %x, %y ], [], 'intersection: disjoint');

  {
    my $got = [ sort { $a cmp $b } keys_difference %x, %y ];
    is_deeply($got, [qw(a b)], 'difference: disjoint x - y');
  }

  {
    my $got = [ sort { $a cmp $b } keys_difference %y, %x ];
    is_deeply($got, [qw(c d)], 'difference: disjoint y - x');
  }

  {
    my $got = [ sort { $a cmp $b } keys_symmetric_difference %y, %x ];
    is_deeply($got, [qw(a b c d)], 'symmetric difference: disjoint');
  }

  ok(keys_disjoint(%x, %y), 'disjoint sets');
  ok(!keys_equal(%x, %y), 'disjoint: not equal');
};

subtest 'Testing keys_any' => sub {
  my %h = (a => 1, b => 2, c => 3);

  ok(keys_any(%h, 'a'), 'any: single existing key');
  ok(!keys_any(%h, 'x'), 'any: single non-existing key');
  ok(keys_any(%h, 'x', 'y', 'a'), 'any: one match among several');
  ok(keys_any(%h, 'a', 'b', 'c'), 'any: all match');
  ok(!keys_any(%h, 'x', 'y', 'z'), 'any: none match');
  ok(!keys_any(%h), 'any: empty list');

  my %empty = ();
  ok(!keys_any(%empty, 'a'), 'any: empty hash');
  ok(!keys_any(%empty), 'any: empty hash, empty list');
};

subtest 'Testing keys_all' => sub {
  my %h = (a => 1, b => 2, c => 3);

  ok(keys_all(%h, 'a'), 'all: single existing key');
  ok(!keys_all(%h, 'x'), 'all: single non-existing key');
  ok(keys_all(%h, 'a', 'b'), 'all: multiple existing keys');
  ok(!keys_all(%h, 'a', 'b', 'x'), 'all: some non-existing');
  ok(!keys_all(%h, 'x', 'y', 'z'), 'all: none existing');
  ok(keys_all(%h), 'all: empty list returns true');

  my %empty = ();
  ok(!keys_all(%empty, 'a'), 'all: empty hash');
  ok(keys_all(%empty), 'all: empty hash, empty list returns true');
};

subtest 'Testing keys_none' => sub {
  my %h = (a => 1, b => 2, c => 3);

  ok(!keys_none(%h, 'a'), 'none: single existing key');
  ok(keys_none(%h, 'x'), 'none: single non-existing key');
  ok(!keys_none(%h, 'a', 'b'), 'none: multiple existing keys');
  ok(!keys_none(%h, 'a', 'x'), 'none: some existing');
  ok(keys_none(%h, 'x', 'y', 'z'), 'none: all non-existing');
  ok(keys_none(%h), 'none: empty list returns true');

  my %empty = ();
  ok(keys_none(%empty, 'a'), 'none: empty hash');
  ok(keys_none(%empty), 'none: empty hash, empty list returns true');
};

subtest 'partial overlap' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  {
    my $got = [sort { $a cmp $b } keys_union %x, %y];
    is_deeply($got, [qw(a b c d)], 'union: partial overlap');
  }

  {
    my $got = [sort { $a cmp $b } keys_intersection %x, %y];
    is_deeply($got, [qw(b c)], 'intersection: partial overlap');
  }

  {
    my $got = [sort { $a cmp $b } keys_difference %x, %y];
    is_deeply($got, [qw(a)], 'difference: x - y');
  }

  {
    my $got = [sort { $a cmp $b } keys_difference %y, %x];
    is_deeply($got, [qw(d)], 'difference: y - x');
  }

  {
    my $got = [sort { $a cmp $b } keys_symmetric_difference %x, %y];
    is_deeply($got, [qw(a d)], 'symmetric difference: partial overlap');
  }

  ok(!keys_disjoint(%x, %y), 'partial overlap: not disjoint');
  ok(!keys_equal(%x, %y), 'partial overlap: not equal');
  ok(!keys_subset(%x, %y), 'partial overlap: x ⊄ y');
  ok(!keys_superset(%x, %y), 'partial overlap: x ⊅ y');
};

subtest 'proper subset/superset' => sub {
  my %small = (a => 1, b => 2                );
  my %large = (a => 1, b => 2, c => 3, d => 4);

  ok(keys_subset(%small, %large), 'small ⊆ large');
  ok(keys_proper_subset(%small, %large), 'small ⊂ large');
  ok(!keys_subset(%large, %small), 'large ⊄ small');
  ok(!keys_proper_subset(%large, %small), 'large ⊄ small (not proper)');

  ok(keys_superset(%large, %small), 'large ⊇ small');
  ok(keys_proper_superset(%large, %small), 'large ⊃ small');
  ok(!keys_superset(%small, %large), 'small ⊅ large');
  ok(!keys_proper_superset(%small, %large), 'small ⊅ large (not proper)');
};

subtest 'single element hashes' => sub {
  my %x = (a => 1);
  my %y = (a => 2);
  my %z = (b => 1);

  {
    my $got = [sort { $a cmp $b } keys_union %x, %y];
    is_deeply($got, [qw(a)], 'union: single same key');
  }

  {
    my $got = [sort { $a cmp $b } keys_union %x, %z];
    is_deeply($got, [qw(a b)], 'union: single different keys');
  }

  {
    my $got = [sort { $a cmp $b } keys_intersection %x, %y];
    is_deeply($got, [qw(a)], 'intersection: single same key');
  }

  is_deeply([keys_intersection %x, %z], [], 'intersection: single different keys');

  ok(keys_equal(%x, %y), 'single element: equal keys');
  ok(!keys_equal(%x, %z), 'single element: different keys');
  ok(keys_disjoint(%x, %z), 'single element: disjoint');
  ok(!keys_disjoint(%x, %y), 'single element: not disjoint');
};

subtest 'numeric keys' => sub {
  my %x = (0 => 'a', 1 => 'b', 2 => 'c'          );
  my %y = (          1 => 'x', 2 => 'y', 3 => 'z');

  {
    my $got = [sort { $a <=> $b } keys_union %x, %y];
    is_deeply($got, [0, 1, 2, 3], 'union: numeric keys');
  }

  {
    my $got = [sort { $a <=> $b } keys_intersection %x, %y];
    is_deeply($got, [1, 2], 'intersection: numeric keys');
  }

  {
    my $got = [sort { $a <=> $b } keys_difference %x, %y];
    is_deeply($got, [0], 'difference: numeric keys');
  }
};

subtest 'unicode keys' => sub {
  use utf8;
  my %x = (café => 1, naïve => 2, ñoño => 3);
  my %y = (café => 4, château => 5);

  {
    my $got = [sort { $a cmp $b } keys_union %x, %y];
    is_deeply($got, [qw(café château naïve ñoño)], 'union: unicode keys');
  }

  {
    my $got = [sort { $a cmp $b } keys_intersection %x, %y];
    is_deeply($got, [qw(café)], 'intersection: unicode keys');
  }

  ok(keys_any(%x, 'café', 'missing'), 'any: unicode key match');
  ok(keys_all(%x, 'café', 'naïve'), 'all: unicode keys');
  ok(keys_none(%x, 'château', 'missing'), 'none: unicode key not present');
};

subtest 'special character keys' => sub {
  my %x = ('foo-bar' => 1, 'baz_qux' => 2, 'a.b.c' => 3);
  my %y = ('foo-bar' => 4, 'test key' => 5);

  {
    my $got = [sort { $a cmp $b } keys_intersection %x, %y];
    is_deeply($got, ['foo-bar'], 'intersection: special chars in keys');
  }

  ok(keys_any(%x, 'foo-bar', 'baz_qux'), 'any: special char keys');
};

subtest 'empty string key' => sub {
  my %x = ('' => 'empty', a => 1);
  my %y = ('' => 'also empty', b => 2);

  {
    my $got = [sort { $a cmp $b } keys_intersection %x, %y];
    is_deeply($got, [''], 'intersection: empty string key');
  }

  ok(keys_any(%x, '', 'a'), 'any: empty string key');
  ok(keys_all(%x, '', 'a'), 'all: empty string key');
};

subtest 'keys_partition' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my ($only_x, $both, $only_y) = keys_partition %x, %y;

  {
    my $got = [sort { $a cmp $b } @$only_x];
    is_deeply($got, [qw(a)], 'partition: only in x');
  }

  {
    my $got = [sort { $a cmp $b } @$both];
    is_deeply($got, [qw(b c)], 'partition: in both');
  }

  {
    my $got = [sort { $a cmp $b } @$only_y];
    is_deeply($got, [qw(d)], 'partition: only in y');
  }
};

subtest 'keys_partition - empty hashes' => sub {
  my %x = ();
  my %y = ();

  my ($only_x, $both, $only_y) = keys_partition %x, %y;

  is_deeply($only_x, [], 'partition empty: only_x empty');
  is_deeply($both, [], 'partition empty: both empty');
  is_deeply($only_y, [], 'partition empty: only_y empty');
};

subtest 'keys_partition - disjoint' => sub {
  my %x = (a => 1, b => 2               );
  my %y = (               c => 3, d => 4);

  my ($only_x, $both, $only_y) = keys_partition %x, %y;

  {
    my $got = [sort { $a cmp $b } @$only_x];
    is_deeply($got, [qw(a b)], 'partition disjoint: only_x');
  }

  is_deeply($both, [], 'partition disjoint: both empty');

  {
    my $got = [sort { $a cmp $b } @$only_y];
    is_deeply($got, [qw(c d)], 'partition disjoint: only_y');
  }
};

subtest 'keys_partition - identical' => sub {
  my %x = (a => 1, b => 2);
  my %y = (a => 3, b => 4);

  my ($only_x, $both, $only_y) = keys_partition %x, %y;

  is_deeply($only_x, [], 'partition identical: only_x empty');
  my $got = [sort { $a cmp $b } @$both];
  is_deeply($got, [qw(a b)], 'partition identical: both');
  is_deeply($only_y, [], 'partition identical: only_y empty');
};

subtest 'large hashes' => sub {
  my %x = map { $_ => $_ * 2 } 1..1000;
  my %y = map { $_ => $_ * 3 } 500..1500;

  my @intersection = keys_intersection %x, %y;
  is(scalar @intersection, 501, 'intersection: large hashes');

  my @union = keys_union %x, %y;
  is(scalar @union, 1500, 'union: large hashes');

  ok(!keys_disjoint(%x, %y), 'large hashes: not disjoint');
};

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

subtest 'tied hash' => sub {
  my (%x, %y);

  tie %x, 'MyTiedHash';
  %x = (a => 1, b => 2, c => 3        );
  %y = (b => 4,         c => 5, d => 6);

  {
    my $got = [sort { $a cmp $b } keys_union %x, %y];
    is_deeply($got, [qw(a b c d)], 'tied hash: union');
  }

  {
    my $got = [sort { $a cmp $b } keys_intersection %x, %y];
    is_deeply($got, [qw(b c)], 'tied hash: intersection');
  }

  ok(keys_any(%x, 'a', 'x'), 'tied hash: keys_any');
  ok(keys_all(%x, 'a', 'b', 'c'), 'tied hash: keys_all');
  ok(keys_none(%x, 'x', 'y', 'z'), 'tied hash: keys_none');
};

subtest 'both hashes tied' => sub {
  tie my %x, 'MyTiedHash';
  tie my %y, 'MyTiedHash';

  %x = (a => 1, b => 2        );
  %y = (        b => 3, c => 4);

  my $got = [sort { $a cmp $b } keys_union %x, %y];
  is_deeply($got, [qw(a b c)], 'both tied: union');
  ok(keys_equal(%x, %x), 'both tied: equal to itself');
};

subtest 'large hashes tied' => sub {
  tie my %x, 'MyTiedHash';
  tie my %y, 'MyTiedHash';

  %x = map { $_ => $_ * 2 } 1..1000;
  %y = map { $_ => $_ * 3 } 500..1500;

  my @intersection = keys_intersection %x, %y;
  is(scalar @intersection, 501, 'intersection: large hashes tied');

  my @union = keys_union %x, %y;
  is(scalar @union, 1500, 'union: large hashes tied');

  ok(!keys_disjoint(%x, %y), 'large hashes tied: not disjoint');
};

subtest 'undef values' => sub {
  my %x = (a => undef, b => 2,     c => undef           );
  my %y = (            b => undef, c => 3,    d => undef);

  my $got = [sort { $a cmp $b } keys_intersection %x, %y];
  is_deeply($got, [qw(b c)], 'undef values: intersection');
  ok(keys_any(%x, 'a'), 'undef values: keys_any');
  ok(keys_all(%x, 'a', 'b', 'c'), 'undef values: keys_all');
};

subtest 'zero and empty string values' => sub {
  my %x = (a => 0, b => '',  c => undef);
  my %y = (a => 1, b => 'x', c => 3);

  my $got = [sort { $a cmp $b } keys_intersection %x, %y];
  is_deeply($got, [qw(a b c)], 'zero/empty values: intersection');
  ok(keys_equal(%x, %y), 'zero/empty values: keys equal');
};

done_testing;
