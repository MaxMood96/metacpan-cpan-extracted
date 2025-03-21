
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'bin/build_selenium_spec.pl',
    'lib/Selenium/Client.pm',
    'lib/Selenium/Client/Commands.pm',
    'lib/Selenium/Client/Driver.pm',
    'lib/Selenium/Client/WDKeys.pm',
    'lib/Selenium/Client/WebElement.pm',
    'lib/Selenium/Driver/Auto.pm',
    'lib/Selenium/Driver/Chrome.pm',
    'lib/Selenium/Driver/Edge.pm',
    'lib/Selenium/Driver/Gecko.pm',
    'lib/Selenium/Driver/Safari.pm',
    'lib/Selenium/Driver/SeleniumHQ/Jar.pm',
    'lib/Selenium/Driver/WinApp.pm',
    'lib/Selenium/Specification.pm',
    'lib/Selenium/Subclass.pm',
    't/00-compile.t',
    't/author-critic.t',
    't/author-distmeta.t',
    't/author-eol.t',
    't/author-minimum-version.t',
    't/author-mojibake.t',
    't/author-no-tabs.t',
    't/author-pod-linkcheck.t',
    't/author-pod-syntax.t',
    't/author-portability.t',
    't/author-synopsis.t',
    't/author-test-version.t',
    't/release-cpan-changes.t',
    't/release-dist-manifest.t',
    't/release-kwalitee.t',
    't/release-meta-json.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
