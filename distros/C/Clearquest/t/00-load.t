#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
  # Stub CQPerlExt if unavailable to allow compilation
  unless (eval {require CQPerlExt; 1}) {
    no strict 'refs';
    ${"CQPerlExt::CQ_COMP_OP_EQ"}          = 1;
    ${"CQPerlExt::CQ_COMP_OP_IS_NULL"}     = 2;
    ${"CQPerlExt::CQ_COMP_OP_NEQ"}         = 3;
    ${"CQPerlExt::CQ_COMP_OP_IS_NOT_NULL"} = 4;
    ${"CQPerlExt::CQ_COMP_OP_LT"}          = 5;
    ${"CQPerlExt::CQ_COMP_OP_GT"}          = 6;
    ${"CQPerlExt::CQ_COMP_OP_LTE"}         = 7;
    ${"CQPerlExt::CQ_COMP_OP_GTE"}         = 8;
    ${"CQPerlExt::CQ_COMP_OP_LIKE"}        = 9;
    ${"CQPerlExt::CQ_COMP_OP_NOT_LIKE"}    = 10;
    ${"CQPerlExt::CQ_COMP_OP_BETWEEN"}     = 11;
    ${"CQPerlExt::CQ_COMP_OP_NOT_BETWEEN"} = 12;
    ${"CQPerlExt::CQ_COMP_OP_IN"}          = 13;
    ${"CQPerlExt::CQ_COMP_OP_NOT_IN"}      = 14;
    ${"CQPerlExt::CQ_BOOL_OP_AND"}         = 15;
    ${"CQPerlExt::CQ_BOOL_OP_OR"}          = 16;
  } ## end unless (eval {require CQPerlExt...})

  $ENV{CQ_CONF} = 't/cq.conf';
  use_ok ('Clearquest') || print "Bail out!\n";
} ## end BEGIN

diag ("Testing Clearquest $Clearquest::VERSION, Perl $], $^X");
