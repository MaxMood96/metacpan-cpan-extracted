
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/exact.pm',
    't/00-compile.t',
    't/author-eol.t',
    't/author-no-tabs.t',
    't/author-pod-coverage.t',
    't/author-pod-syntax.t',
    't/author-portability.t',
    't/author-synopsis.t',
    't/bundle.t',
    't/carp.t',
    't/control.t',
    't/export.t',
    't/extension.t',
    't/features.t',
    't/maybe.t',
    't/no_dup_add_isa.t',
    't/package.t',
    't/release-kwalitee.t',
    't/try.t',
    't/v10.t'
);

notabs_ok($_) foreach @files;
done_testing;
