
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
    'lib/Webservice/Judobase.pm',
    'lib/Webservice/Judobase.pod',
    'lib/Webservice/Judobase/Competitor.pm',
    'lib/Webservice/Judobase/Competitor.pod',
    'lib/Webservice/Judobase/Contests.pm',
    'lib/Webservice/Judobase/Contests.pod',
    'lib/Webservice/Judobase/Country.pm',
    'lib/Webservice/Judobase/Country.pod',
    'lib/Webservice/Judobase/General.pm',
    'lib/Webservice/Judobase/General.pod',
    't/00-Basic.t',
    't/00-compile.t',
    't/author-critic.t',
    't/author-distmeta.t',
    't/author-eol.t',
    't/author-minimum-version.t',
    't/author-mojibake.t',
    't/author-no-tabs.t',
    't/author-pod-coverage.t',
    't/author-pod-linkcheck.t',
    't/author-pod-syntax.t',
    't/author-synopsis.t',
    't/author-test-version.t',
    't/release-changes_has_content.t',
    't/release-cpan-changes.t',
    't/release-dist-manifest.t',
    't/release-kwalitee.t',
    't/release-meta-json.t',
    't/release-unused-vars.t'
);

notabs_ok($_) foreach @files;
done_testing;
