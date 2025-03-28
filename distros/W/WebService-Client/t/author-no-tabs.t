
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
    'lib/WebService/Client.pm',
    'lib/WebService/Client/Response.pm',
    't/00-compile.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/00-test-get.t',
    't/author-eof.t',
    't/author-eol.t',
    't/author-no-breakpoints.t',
    't/author-no-tabs.t',
    't/author-pod-syntax.t',
    't/author-portability.t',
    't/release-distmeta.t',
    't/release-kwalitee.t',
    't/release-pause-permissions.t',
    't/release-unused-vars.t'
);

notabs_ok($_) foreach @files;
done_testing;
