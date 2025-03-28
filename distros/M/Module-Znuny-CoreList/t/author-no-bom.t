
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoBOM 0.002

use Test::More 0.88;
use Test::BOM;

my @files = (
    'lib/Module/Znuny/CoreList.pm',
    'lib/Module/Znuny/CoreList.pod',
    't/001_shipped.t',
    't/002_changed_tickets_dashboard.t',
    't/003_modules.t',
    't/004_cpan.t'
);

ok(file_hasnt_bom($_)) for @files;

done_testing;
