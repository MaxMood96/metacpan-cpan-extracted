
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for testing by the author');
  }
}

use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Win32/SDDL.pm',
    't/00-load.t',
    't/author-critic.t',
    't/author-no-tabs.t',
    't/author-pod-coverage.t',
    't/author-pod-syntax.t',
    't/boilerplate.t',
    't/functionality.t',
    't/pod-coverage.t',
    't/pod.t',
    't/release-kwalitee.t'
);

notabs_ok($_) foreach @files;
done_testing;
