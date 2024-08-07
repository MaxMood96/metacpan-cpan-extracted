
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
    'lib/DBIx/Class/InflateColumn/TimePiece.pm',
    't/00_base.t',
    't/01_deflate.t',
    't/lib/TimePieceDB.pm',
    't/lib/TimePieceDB/TestUser.pm'
);

notabs_ok($_) foreach @files;
done_testing;
