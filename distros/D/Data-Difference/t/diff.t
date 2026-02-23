#!perl
use strict;
use warnings;

use Test::More;
use Test::Differences;

BEGIN { use_ok('Data::Difference', 'data_diff'); }

my @tests = (
  {a => undef, b => undef, out => []},
  {a => undef, b => 1,     out => [{path => [], a => undef, b => 1}]},
  {a => 1,     b => 2,     out => [{path => [], a => 1, b => 2}]},
  {a => [1, 2, 3], b => [1, 2], out => [{path => [2], a => 3}]},
  {a => [1, 2], b => [1, 2, 3], out => [{path => [2], b => 3}]},
  { a   => { k => undef },
    b   => { k => 1 },
    out => [
      { path => ['k'], a => undef, b => 1 }
    ]
  },
  { a   => { k => 1 },
    b   => { k => undef },
    out => [
      { path => ['k'], a => 1, b => undef }
    ]
  },
  { a   => [ undef ],
    b   => [ 1 ],
    out => [
      { path => ['0'], a => undef, b => 1 }
    ]
  },
  { a   => [ 1 ],
    b   => [ undef ],
    out => [
      { path => ['0'], a => 1, b => undef }
    ]
  },
  { a   => {Q => 1, W => 2, E => 3},
    b   => {W => 4, E => 3, R => 5},
    out => [  ##
      {path => ['Q'], a => 1},
      {path => ['R'], b => 5},
      {path => ['W'], a => 2, b => 4},
    ]
  },
);

for my $i (0 .. $#tests) {
  my $t = $tests[$i];
  eq_or_diff(
    [data_diff($t->{a}, $t->{b})],
    $t->{out},
    "\$tests[$i]"
  );
}

subtest "circular structure" => sub {
  {
    my $a = { val => 1 };
    $a->{self} = $a;

    my $b = { val => 1 };
    $b->{self} = $b;

    eq_or_diff(
      [data_diff($a, $b)],
      [],
      "identical cyclic structures: no diff",
    );
  }

  {
    my $a = { val => 1 };
    $a->{self} = $a;

    my $b = { val => 2 };
    $b->{self} = $b;

    eq_or_diff(
      [data_diff($a, $b)],
      [{path => ['val'], a => 1, b => 2}],
      "cyclic structures differing in a scalar value: diff reported",
    );
  }

  {
    my $a = { val => 1 };
    $a->{self} = $a;

    eq_or_diff(
      [data_diff($a, $a)],
      [],
      "cyclic structure compared to itself: no diff",
    );
  }

  {
    my $a = [[]];
    push @{$a->[0]}, $a->[0];

    my $b = [[]];
    push @{$b->[0]}, $b->[0];

    eq_or_diff(
      [data_diff($a, $b)],
      [],
      "identical cyclic array structures: no diff",
    );
  }
};

subtest "shared sub-structures (DAG)" => sub {
  {
    my $shared_l = { x => 1 };
    my $left = { a => $shared_l, b => $shared_l };

    my $shared_r = { x => 2 };
    my $right = { a => $shared_r, b => $shared_r };

    eq_or_diff(
      [data_diff($left, $right)],
      [
        {path => ['a', 'x'], a => 1, b => 2},
        {path => ['b', 'x'], a => 1, b => 2},
      ],
      "shared sub-structure diff reported in each location",
    );
  }

  {
    my $shared_l = { x => 1 };
    my $left = { a => $shared_l, b => $shared_l };

    my $shared_r = { x => 1 };
    my $right = { a => $shared_r, b => $shared_r };

    eq_or_diff(
      [data_diff($left, $right)],
      [],
      "identical shared sub-structures: no diff",
    );
  }

  {
    my $shared = {};
    $shared->{self} = $shared;
    my $left = { a => $shared, b => $shared };

    my $shared_r = {};
    $shared_r->{self} = $shared_r;
    my $right = { a => $shared_r, b => $shared_r };

    eq_or_diff(
      [data_diff($left, $right)],
      [],
      "identical cyclic shared sub-structures: no diff",
    );
  }
};

done_testing();
