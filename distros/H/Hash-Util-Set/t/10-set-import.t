#!perl
use strict;
use warnings;

use Test::More;

use_ok('Hash::Util::Set');

my @Operations = qw[ keys_union
                     keys_intersection
                     keys_difference
                     keys_symmetric_difference
                     keys_partition ];
my @Predicates = qw[ keys_disjoint
                     keys_equal
                     keys_subset
                     keys_proper_subset
                     keys_superset
                     keys_proper_superset ];
my @Membership = qw[ keys_any
                     keys_all
                     keys_none ];
my @Aliases    = qw[ keys_or
                     keys_and
                     keys_sub
                     keys_xor ];

my @All = ( @Operations,
            @Predicates,
            @Membership,
            @Aliases );

my %Api; @Api{@All} = (1) x @All;

{
  package Foo::Operations;
  Test::More::note q[Tag :operations];
  Test::More::use_ok('Hash::Util::Set', q[:operations]);
  Test::More::can_ok(__PACKAGE__, @Operations);
}

{
  package Foo::Predicates;
  Test::More::note q[Tag :predicates];
  Test::More::use_ok('Hash::Util::Set', q[:predicates]);
  Test::More::can_ok(__PACKAGE__, @Predicates);
}

{
  package Foo::Membership;
  Test::More::note q[Tag :membership];
  Test::More::use_ok('Hash::Util::Set', q[:membership]);
  Test::More::can_ok(__PACKAGE__, @Membership);
}

{
  package Foo::Aliases;
  Test::More::note q[Tag :aliases];
  Test::More::use_ok('Hash::Util::Set', q[:aliases]);
  Test::More::can_ok(__PACKAGE__, @Aliases);
}

{
  package Foo::All;
  Test::More::note q[Tag :all];
  Test::More::use_ok('Hash::Util::Set', q[:all]);
  Test::More::can_ok(__PACKAGE__, @All);
}

{
  package Foo::Individually;
  Test::More::note q[All individually];
  Test::More::use_ok('Hash::Util::Set', @All);
  Test::More::can_ok(__PACKAGE__, @All);
}

my @exported =
  grep { $Api{$_} }
  grep {; no strict 'refs'; *{"main::$_"}{CODE} }
  sort keys %main::;

ok(! scalar @exported, 'No exported subroutines by default')
  or diag "Found: @exported";

done_testing;
