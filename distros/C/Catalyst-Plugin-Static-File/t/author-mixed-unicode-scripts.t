
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use strict;
use warnings;

# This test was generated with Dist::Zilla::Plugin::Test::MixedScripts v0.1.0.

use Test::More 1.302200;

use Test::MixedScripts qw( file_scripts_ok );

my @scxs = ( 'ASCII' );

my @files = (
    'lib/Catalyst/Plugin/Static/File.pm',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/10-catalyst.t',
    't/20-psgi-mime.t',
    't/21-psgi-xsendfile.t',
    't/22-psgi-etag.t',
    't/23-psgi-conditional-get.t',
    't/author-changes.t',
    't/author-clean-namespaces.t',
    't/author-critic.t',
    't/author-cve.t',
    't/author-eof.t',
    't/author-eol.t',
    't/author-minimum-version.t',
    't/author-mixed-unicode-scripts.t',
    't/author-no-tabs.t',
    't/author-pod-coverage.t',
    't/author-pod-linkcheck.t',
    't/author-pod-syntax.t',
    't/author-portability.t',
    't/author-vars.t',
    't/etc/perlcritic.rc',
    't/lib/App.pm',
    't/lib/App/Controller/Root.pm',
    't/release-dist-manifest.t',
    't/release-fixme.t',
    't/release-kwalitee.t',
    't/release-trailing-space.t',
    't/static/hello.txt'
);

file_scripts_ok($_, { scripts => \@scxs } ) for @files;

done_testing;
