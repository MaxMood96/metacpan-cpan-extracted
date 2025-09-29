use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'bin/i3-ipc',
    'bin/i3-wod',
    'lib/AnyEvent/I3X/Workspace/OnDemand.pm',
    'lib/AnyEvent/I3X/Workspace/OnDemand/UserGuide.pod',
    't/00-compile.t',
    't/01-basic.t'
);

notabs_ok($_) foreach @files;
done_testing;
