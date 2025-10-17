#!perl

BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}


use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::Perl::Critic::Subset 3.001.006

use Test::Perl::Critic (-profile => "") x!! -e "";

my $filenames = ['lib/App/ClipboardUtils.pm','lib/App/ClipboardUtils/Manual/HowTo/ClipaddCookbook.pod','script/add-clipboard-content','script/ca','script/cg','script/clear-clipboard-content','script/clear-clipboard-history','script/clipadd','script/clipget','script/cliptee','script/ct','script/detect-clipboard-manager','script/get-clipboard-content','script/get-clipboard-history-item','script/list-clipboard-history','script/tee-clipboard-content'];
unless ($filenames && @$filenames) {
    $filenames = -d "blib" ? ["blib"] : ["lib"];
}

all_critic_ok(@$filenames);
