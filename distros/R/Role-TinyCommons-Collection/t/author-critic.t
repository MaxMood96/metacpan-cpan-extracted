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

my $filenames = ['lib/Role/TinyCommons/Collection.pm','lib/Role/TinyCommons/Collection/CompareItems.pm','lib/Role/TinyCommons/Collection/FindItem.pm','lib/Role/TinyCommons/Collection/FindItem/Iterator.pm','lib/Role/TinyCommons/Collection/GetItemByKey.pm','lib/Role/TinyCommons/Collection/GetItemByPos.pm','lib/Role/TinyCommons/Collection/PickItems.pm','lib/Role/TinyCommons/Collection/PickItems/Iterator.pm','lib/Role/TinyCommons/Collection/PickItems/RandomPos.pm','lib/Role/TinyCommons/Collection/PickItems/RandomSeekLines.pm','lib/Role/TinyCommons/Collection/SelectItems.pm'];
unless ($filenames && @$filenames) {
    $filenames = -d "blib" ? ["blib"] : ["lib"];
}

all_critic_ok(@$filenames);
