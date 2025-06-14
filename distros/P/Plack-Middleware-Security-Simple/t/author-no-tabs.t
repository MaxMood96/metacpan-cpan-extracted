
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
    'lib/Plack/Middleware/Security/Common.pm',
    'lib/Plack/Middleware/Security/Simple.pm',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/10-Hash-Match.t',
    't/10-arrayref.t',
    't/10-coderef.t',
    't/10-hashref.t',
    't/20-logging.t',
    't/30-handler.t',
    't/31-status.t',
    't/40-common.t',
    't/author-changes.t',
    't/author-critic.t',
    't/author-eof.t',
    't/author-eol.t',
    't/author-minimum-version.t',
    't/author-no-tabs.t',
    't/author-pod-coverage.t',
    't/author-pod-linkcheck.t',
    't/author-pod-syntax.t',
    't/author-portability.t',
    't/author-vars.t',
    't/release-dist-manifest.t',
    't/release-fixme.t',
    't/release-kwalitee.t',
    't/release-trailing-space.t'
);

notabs_ok($_) foreach @files;
done_testing;
