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

subtest 'hash_inner_join - basic' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_inner_join %x, %y;
  is_deeply([sort keys %result], [qw(b c)], 'inner_join: correct keys');
  is($result{b}, 4, 'inner_join: default merge takes right value');
  is($result{c}, 5, 'inner_join: default merge takes right value');
};

subtest 'hash_inner_join - custom merge' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_inner_join %x, %y, sub { $_[1] + $_[2] };
  is($result{b}, 6, 'inner_join: custom merge sums values');
  is($result{c}, 8, 'inner_join: custom merge sums values');
};

subtest 'hash_inner_join - empty hashes' => sub {
  my %x = ();
  my %y = ();

  my %result = hash_inner_join %x, %y;
  is_deeply(\%result, {}, 'inner_join: empty hashes');
};

subtest 'hash_inner_join - no common keys' => sub {
  my %x = (a => 1, b => 2               );
  my %y = (               c => 3, d => 4);

  my %result = hash_inner_join %x, %y;
  is_deeply(\%result, {}, 'inner_join: disjoint sets');
};

subtest 'hash_left_join - basic' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_left_join %x, %y;
  is_deeply([sort keys %result], [qw(a b c)], 'left_join: all left keys');
  is($result{a}, 1, 'left_join: left-only key preserved');
  is($result{b}, 4, 'left_join: default merge prefers right');
  is($result{c}, 5, 'left_join: default merge prefers right');
};

subtest 'hash_left_join - custom merge with undef' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_left_join %x, %y, sub {
    my ($k, $left, $right) = @_;
    defined($right) ? "$left:$right" : "$left:none";
  };
  is($result{a}, '1:none', 'left_join: undef passed for missing right');
  is($result{b}, '2:4', 'left_join: both values present');
};

subtest 'hash_left_join - empty left' => sub {
  my %x = ();
  my %y = (a => 1, b => 2);

  my %result = hash_left_join %x, %y;
  is_deeply(\%result, {}, 'left_join: empty left hash');
};

subtest 'hash_right_join - basic' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_right_join %x, %y;
  is_deeply([sort keys %result], [qw(b c d)], 'right_join: all right keys');
  is($result{d}, 6, 'right_join: right-only key preserved');
  is($result{b}, 4, 'right_join: default merge prefers right');
};

subtest 'hash_right_join - custom merge with undef' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_right_join %x, %y, sub {
    my ($k, $left, $right) = @_;
    defined($left) ? "$left:$right" : "none:$right";
  };
  is($result{d}, 'none:6', 'right_join: undef passed for missing left');
  is($result{b}, '2:4', 'right_join: both values present');
};

subtest 'hash_outer_join - basic' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_outer_join %x, %y;
  is_deeply([sort keys %result], [qw(a b c d)], 'outer_join: all keys from both');
  is($result{a}, 1, 'outer_join: left-only key');
  is($result{d}, 6, 'outer_join: right-only key');
  is($result{b}, 4, 'outer_join: default merge prefers right');
};

subtest 'hash_outer_join - custom merge' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_outer_join %x, %y, sub {
    my ($k, $left, $right) = @_;
    return "$left:$right" if defined($left) && defined($right);
    return "$left:none"   if defined($left);
    return "none:$right";
  };
  is($result{a}, '1:none', 'outer_join: left-only with custom merge');
  is($result{d}, 'none:6', 'outer_join: right-only with custom merge');
  is($result{b}, '2:4', 'outer_join: both present with custom merge');
};

subtest 'hash_outer_join - empty hashes' => sub {
  my %x = ();
  my %y = ();

  my %result = hash_outer_join %x, %y;
  is_deeply(\%result, {}, 'outer_join: both empty');
};

subtest 'hash_left_anti_join - basic' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_left_anti_join %x, %y;
  is_deeply(\%result, {a => 1}, 'left_anti_join: keys only in left');
};

subtest 'hash_left_anti_join - no unique keys' => sub {
  my %x = (        b => 2, c => 3        );
  my %y = (a => 1, b => 4, c => 5, d => 6);

  my %result = hash_left_anti_join %x, %y;
  is_deeply(\%result, {}, 'left_anti_join: all keys in right');
};

subtest 'hash_left_anti_join - empty right' => sub {
  my %x = (a => 1, b => 2);
  my %y = ();

  my %result = hash_left_anti_join %x, %y;
  is_deeply(\%result, {a => 1, b => 2}, 'left_anti: empty right returns all left');
};

subtest 'hash_right_anti_join - basic' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_right_anti_join %x, %y;
  is_deeply(\%result, {d => 6}, 'right_anti_join: keys only in right');
};

subtest 'hash_right_anti_join - empty left' => sub {
  my %x = ();
  my %y = (a => 1, b => 2);

  my %result = hash_right_anti_join %x, %y;
  is_deeply(\%result, {a => 1, b => 2}, 'right_anti: empty left returns all right');
};

subtest 'hash_full_anti_join - basic' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %result = hash_full_anti_join %x, %y;
  is_deeply([sort keys %result], [qw(a d)], 'full_anti_join: keys in either but not both');
  is($result{a}, 1, 'full_anti_join: value from left');
  is($result{d}, 6, 'full_anti_join: value from right');
};

subtest 'hash_full_anti_join - all different' => sub {
  my %x = (a => 1, b => 2               );
  my %y = (               c => 3, d => 4);

  my %result = hash_full_anti_join %x, %y;
  is_deeply([sort keys %result], [qw(a b c d)], 'full_anti_join: disjoint sets');
};

subtest 'hash_full_anti_join - all same' => sub {
  my %x = (a => 1, b => 2);
  my %y = (a => 3, b => 4);

  my %result = hash_full_anti_join %x, %y;
  is_deeply(\%result, {}, 'full_anti_join: identical keys');
};

subtest 'hash_full_anti_join - one empty' => sub {
  my %x = (a => 1, b => 2);
  my %y = ();

  my %result = hash_full_anti_join %x, %y;
  is_deeply(\%result, {a => 1, b => 2}, 'full_anti: one empty returns the other');
};

subtest 'join with single key' => sub {
  my %x = (only => 'left');
  my %y = (only => 'right');

  my %inner = hash_inner_join %x, %y;
  my %left  = hash_left_join %x, %y;
  my %right = hash_right_join %x, %y;

  is($inner{only}, 'right', 'single key inner join');
  is($left{only}, 'right', 'single key left join');
  is($right{only}, 'right', 'single key right join');
};

subtest 'scalar context returns hashref' => sub {
  my %x = (a => 1, b => 2        );
  my %y = (        b => 3, c => 4);

  my $result = hash_inner_join %x, %y;
  is(ref $result, 'HASH', 'inner_join: scalar context returns hashref');
  is($result->{b}, 3, 'inner_join: scalar context has correct value');
};

subtest 'scalar context for all join types' => sub {
  my %x = (a => 1, b => 2        );
  my %y = (        b => 3, c => 4);

  my $inner      = hash_inner_join %x, %y;
  my $left       = hash_left_join %x, %y;
  my $right      = hash_right_join %x, %y;
  my $outer      = hash_outer_join %x, %y;
  my $left_anti  = hash_left_anti_join %x, %y;
  my $right_anti = hash_right_anti_join %x, %y;
  my $full_anti  = hash_full_anti_join %x, %y;

  ok(ref $inner eq 'HASH', 'inner_join returns hashref in scalar context');
  ok(ref $left eq 'HASH', 'left_join returns hashref in scalar context');
  ok(ref $right eq 'HASH', 'right_join returns hashref in scalar context');
  ok(ref $outer eq 'HASH', 'outer_join returns hashref in scalar context');
  ok(ref $left_anti eq 'HASH', 'left_anti_join returns hashref in scalar context');
  ok(ref $right_anti eq 'HASH', 'right_anti_join returns hashref in scalar context');
  ok(ref $full_anti eq 'HASH', 'full_anti_join returns hashref in scalar context');
};

subtest 'hash values (nested structures)' => sub {
  my %x = (
    a => { name => 'Alice', age => 30 },
    b => { name => 'Bob',   age => 25 },
  );
  my %y = (
    b => { score => 95 },
    c => { score => 87 },
  );

  my %result = hash_inner_join %x, %y, sub {
    my ($k, $left, $right) = @_;
    return { %$left, %$right };
  };

  is($result{b}{name}, 'Bob', 'inner_join: nested hash merge - name');
  is($result{b}{age}, 25, 'inner_join: nested hash merge - age');
  is($result{b}{score}, 95, 'inner_join: nested hash merge - score');
};

subtest 'numeric operations' => sub {
  my %x = (a => 10, b => 20, c => 30         );
  my %y = (          b => 5, c => 15, d => 25);

  my %sum = hash_inner_join %x, %y, sub {
    $_[1] + $_[2]
  };
  is($sum{b}, 25, 'inner_join: numeric sum');
  is($sum{c}, 45, 'inner_join: numeric sum');

  my %max = hash_inner_join %x, %y, sub {
    $_[1] > $_[2] ? $_[1] : $_[2]
  };
  is($max{b}, 20, 'inner_join: max value');
  is($max{c}, 30, 'inner_join: max value');
};

subtest 'string concatenation' => sub {
  my %x = (a => 'foo', b => 'bar'            );
  my %y = (            b => 'baz', c => 'qux');

  my %result = hash_inner_join %x, %y,
    sub { "$_[1]_$_[2]"
  };
  is($result{b}, 'bar_baz', 'inner_join: string concatenation');
};

subtest 'undef values in hash' => sub {
  my %x = (a => 1, b => undef, c => 3            );
  my %y = (        b => 2,     c => undef, d => 4);

  my %result = hash_inner_join %x, %y;
  ok(exists $result{b}, 'inner_join: key exists when value is undef');
  is($result{b}, 2, 'inner_join: right undef overridden by left defined');
  ok(!defined($result{c}), 'inner_join: undef from right preserved');
};

subtest 'zero and empty string values' => sub {
  my %x = (a => 0, b => '',  c => 3);
  my %y = (a => 1, b => 'x', c => 0);

  my %result = hash_inner_join %x, %y;
  is($result{a}, 1, 'inner_join: zero value handled correctly');
  is($result{b}, 'x', 'inner_join: empty string handled correctly');
  is($result{c}, 0, 'inner_join: zero value from right');
};

subtest 'large number of keys' => sub {
  my %x = map { $_ => $_ * 2 } 1..1000;
  my %y = map { $_ => $_ * 3 } 500..1500;

  my %result = hash_inner_join %x, %y;
  is(scalar keys %result, 501, 'inner_join: large hash intersection');
  is($result{500}, 1500, 'inner_join: large hash correct value');
};

subtest 'many keys, few common' => sub {
  my %x = map { ("x$_" => $_) } 1..100;
  my %y = map { ("y$_" => $_) } 1..100;
  $x{common} = 'xval';
  $y{common} = 'yval';

  my %result = hash_inner_join %x, %y;
  is(scalar keys %result, 1, 'many keys, one common');
  is($result{common}, 'yval', 'common key has correct value');
};

subtest 'three-way inner join' => sub {
  my %a = (1 => 'A', 2 => 'B', 3 => 'C', 4 => 'D'                    );
  my %b = (          2 => 'X', 3 => 'Y', 4 => 'Z', 5 => 'E'          );
  my %c = (                    3 => 'M', 4 => 'N', 5 => 'O', 6 => 'P');

  my %ab = hash_inner_join %a, %b;
  my %abc = hash_inner_join %ab, %c;

  is_deeply([sort keys %abc], [3, 4], 'three-way join: correct keys');
  is_deeply(\%abc, {3 => 'M', 4 => 'N'}, 'three-way join: correct');
};

subtest 'three-way outer join' => sub {
  my %a = (a => 1);
  my %b = (b => 2);
  my %c = (c => 3);

  my %ab = hash_outer_join %a, %b;
  my %abc = hash_outer_join %ab, %c;

  is_deeply([sort keys %abc], [qw(a b c)], 'three-way outer: all keys');
};

subtest 'mixed join types' => sub {
  my %x = (a => 1, b => 2                );
  my %y = (        b => 3, c => 4        );
  my %z = (                c => 5, d => 6);

  my %xy = hash_left_join %x, %y;
  my %xyz = hash_outer_join %xy, %z;

  is_deeply([sort keys %xyz], [qw(a b c d)], 'mixed join types: all keys');
};

subtest 'merge function receives key' => sub {
  my %x = (a => 1, b => 2);
  my %y = (a => 3, b => 4);

  my %result = hash_inner_join %x, %y, sub {
    my ($key, $left, $right) = @_;
    "$key:$left:$right";
  };

  is($result{a}, 'a:1:3', 'merge function receives key parameter');
  is($result{b}, 'b:2:4', 'merge function receives key parameter');
};

subtest 'inner join is commutative' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %xy = hash_inner_join %x, %y, sub { "$_[1],$_[2]" };
  my %yx = hash_inner_join %y, %x, sub { "$_[2],$_[1]" };

  is_deeply(\%xy, \%yx, 'inner_join is commutative (with symmetric merge)');
};

subtest 'full anti join is commutative' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %xy = hash_full_anti_join %x, %y;
  my %yx = hash_full_anti_join %y, %x;

  is_deeply([sort keys %xy], [sort keys %yx], 'full_anti_join is commutative (keys)');
};

subtest 'left and right anti are inverses' => sub {
  my %x = (a => 1, b => 2, c => 3        );
  my %y = (        b => 4, c => 5, d => 6);

  my %left_anti = hash_left_anti_join %x, %y;
  my %right_anti = hash_right_anti_join %y, %x;

  is_deeply(\%left_anti, \%right_anti, 'left_anti(x,y) == right_anti(y,x)');
};

subtest 'configuration merge' => sub {
  my %defaults = (timeout => 30, retries => 3, debug => 0             );
  my %custom =   (timeout => 60,                          verbose => 1);

  my %config = hash_outer_join %defaults, %custom;

  is($config{timeout}, 60, 'config merge: custom overrides default');
  is($config{retries}, 3, 'config merge: default preserved');
  is($config{debug}, 0, 'config merge: default preserved');
  is($config{verbose}, 1, 'config merge: custom added');
};

subtest 'data reconciliation' => sub {
  my %users =  (1 => 'Alice', 2 => 'Bob', 3 => 'Charlie'        );
  my %scores = (              2 => 95,    3 => 87,       4 => 92);

  my %complete = hash_inner_join %users, %scores, sub {
    { name => $_[1], score => $_[2] }
  };

  is($complete{2}{name}, 'Bob', 'reconciliation: inner join name');
  is($complete{2}{score}, 95, 'reconciliation: inner join score');

  my %missing = hash_left_anti_join %users, %scores;
  is_deeply(\%missing, {1 => 'Alice'}, 'reconciliation: find missing data');
};

subtest 'deep merge with outer join' => sub {
  my $deep_merge;
  $deep_merge = sub {
    my ($k, $left, $right) = @_;
    if (ref $left eq 'HASH' && ref $right eq 'HASH') {
      return { &hash_outer_join($left, $right, $deep_merge) };
    }
    return $right // $left;
  };

  my %x = (
    db      => { port  => 5432, host => 'localhost' },
    logging => { level => 'info'                    },
  );
  my %y = (
    db      => { port  => 3306, user => 'admin'     },
    cache   => { ttl   => 3600                      },
  );

  my %result = &hash_outer_join(\%x, \%y, $deep_merge);

  is($result{db}{host}, 'localhost', 'deep merge: left value preserved');
  is($result{db}{port}, 3306, 'deep merge: right value overrides');
  is($result{db}{user}, 'admin', 'deep merge: right value added');
  is($result{logging}{level}, 'info', 'deep merge: left-only section');
  is($result{cache}{ttl}, 3600, 'deep merge: right-only section');
};

subtest 'deep merge three levels' => sub {
  my $deep_merge;
  $deep_merge = sub {
    my ($k, $left, $right) = @_;
    if (ref $left eq 'HASH' && ref $right eq 'HASH') {
      return { &hash_outer_join($left, $right, $deep_merge) };
    }
    return $right // $left;
  };

  my %x = (
    level1 => {
      level2 => {
        level3 => { a => 1, b => 2 }
      }
    }
  );
  my %y = (
    level1 => {
      level2 => {
        level3 => { b => 3, c => 4 }
      }
    }
  );

  my %result = &hash_outer_join(\%x, \%y, $deep_merge);

  is($result{level1}{level2}{level3}{a}, 1, 'deep merge: three levels - left');
  is($result{level1}{level2}{level3}{b}, 3, 'deep merge: three levels - override');
  is($result{level1}{level2}{level3}{c}, 4, 'deep merge: three levels - right');
};

subtest 'hash with reference values' => sub {
  my %x = (a => [1, 2, 3], b => {x => 1});
  my %y = (a => [4, 5, 6], c => {y => 2});

  my %result = hash_inner_join %x, %y, sub {
    my ($k, $left, $right) = @_;
    [@$left, @$right];
  };

  is_deeply($result{a}, [1, 2, 3, 4, 5, 6], 'inner_join: merge array refs');
};

subtest 'numeric string keys' => sub {
  my %x = ('01' => 'a', '10' => 'b');
  my %y = ('01' => 'c', '10' => 'd');

  my %result = hash_inner_join %x, %y;
  is($result{'01'}, 'c', 'numeric string keys preserved');
  is($result{'10'}, 'd', 'numeric string keys preserved');
};

subtest 'special characters in keys' => sub {
  my %x = ('foo-bar' => 1, 'baz_qux' => 2, 'test.key' => 3);
  my %y = ('foo-bar' => 4, 'baz_qux' => 5);

  my %result = hash_inner_join %x, %y;
  is($result{'foo-bar'}, 4, 'hyphen in key');
  is($result{'baz_qux'}, 5, 'underscore in key');
};

subtest 'unicode keys' => sub {
  use utf8;
  my %x = ('café' => 1, '日本' => 2);
  my %y = ('café' => 3, '中国' => 4);

  my %result = hash_inner_join %x, %y;
  is($result{'café'}, 3, 'unicode key preserved');
};

subtest 'merge function returns undef' => sub {
  my %x = (a => 1, b => 2);
  my %y = (a => 3, b => 4);

  my %result = hash_inner_join %x, %y, sub { undef };

  ok(exists $result{a}, 'key exists when merge returns undef');
  ok(!defined $result{a}, 'value is undef');
};

subtest 'merge function modifies input' => sub {
  my %x = (a => [1, 2]);
  my %y = (a => [3, 4]);

  my %result = hash_inner_join %x, %y, sub {
    my ($k, $left, $right) = @_;
    push @$left, 999;
    return $left;
  };

  is_deeply($x{a}, [1, 2, 999], 'merge function can modify refs');
};

subtest 'merge function dies' => sub {
  my %x = (a => 1, b => 2);
  my %y = (a => 3, b => 4);

  eval {
    my %result = hash_inner_join %x, %y, sub {
      die "merge error";
    };
  };

  like($@, qr/merge error/, 'merge function can die');
};

done_testing;
