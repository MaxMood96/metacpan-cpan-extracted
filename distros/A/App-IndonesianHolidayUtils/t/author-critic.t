#!perl

BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}


use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Perl::Critic::Subset 3.001.005

use Test::Perl::Critic (-profile => "") x!! -e "";

my $filenames = ['lib/App/IndonesianHolidayUtils.pm','lib/Text/ANSITable/StyleSet/Calendar/Indonesia/Holiday/HolidayType.pm','script/count-idn-workdays','script/is-idn-holiday','script/is-idn-workday','script/list-idn-holidays','script/list-idn-workdays'];
unless ($filenames && @$filenames) {
    $filenames = -d "blib" ? ["blib"] : ["lib"];
}

all_critic_ok(@$filenames);
