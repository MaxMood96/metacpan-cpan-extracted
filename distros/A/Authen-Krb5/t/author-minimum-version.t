
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    print qq{1..0 # SKIP these tests are for testing by the author\n};
    exit
  }
}

use strict;
use warnings;

use Test::More;
use Test::MinimumVersion;
all_minimum_version_ok( qq{5.008_008} );
