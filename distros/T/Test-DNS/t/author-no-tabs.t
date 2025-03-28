
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
    'lib/Test/DNS.pm',
    't/00-compile.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/follow_cname.t',
    't/records/a.t',
    't/records/cname.t',
    't/records/mx.t',
    't/records/ns.t',
    't/records/ptr.t',
    't/records/txt.t'
);

notabs_ok($_) foreach @files;
done_testing;
