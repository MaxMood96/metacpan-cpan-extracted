#!perl
use strict;
use warnings;

use Test::More;

use_ok('Hash::Util::Join');

my @All = qw[ hash_inner_join
              hash_left_join
              hash_right_join
              hash_outer_join
              hash_left_anti_join
              hash_right_anti_join
              hash_full_anti_join ];

{
  package Foo::All;
  Test::More::note q[Tag :all];
  Test::More::use_ok('Hash::Util::Join', q[:all]);
  Test::More::can_ok(__PACKAGE__, @All);
}

{
  package Foo::Individually;
  Test::More::note q[All individually];
  Test::More::use_ok('Hash::Util::Join', @All);
  Test::More::can_ok(__PACKAGE__, @All);
}

my @exported =
  grep { /^hash_/ }
  grep {; no strict 'refs'; *{"main::$_"}{CODE} }
  sort keys %main::;

ok(! scalar @exported, 'No exported subroutines by default')
  or diag "Found: @exported";

done_testing;
