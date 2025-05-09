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

my $filenames = ['lib/App/FishCompleteUtils.pm','script/gen-fish-complete-from-getopt-long-complete-script','script/gen-fish-complete-from-getopt-long-descriptive-script','script/gen-fish-complete-from-getopt-long-script','script/gen-fish-complete-from-perinci-cmdline-script'];
unless ($filenames && @$filenames) {
    $filenames = -d "blib" ? ["blib"] : ["lib"];
}

all_critic_ok(@$filenames);
