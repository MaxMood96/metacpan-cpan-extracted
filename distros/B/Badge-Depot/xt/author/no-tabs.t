use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/Badge/Depot.pm',
    't/00-compile.t',
    't/00-report-prereqs.dd',
    't/00-report-prereqs.t',
    't/01-basic.t',
    't/corpus/lib/Badge/Depot/Plugin/Afakebadge.pm',
    't/corpus/lib/Badge/Depot/Plugin/Afakebadgewithoutimage.pm'
);

notabs_ok($_) foreach @files;
done_testing;
