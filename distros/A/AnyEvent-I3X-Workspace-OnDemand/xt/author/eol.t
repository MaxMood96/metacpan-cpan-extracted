use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'bin/i3-ipc',
    'bin/i3-wod',
    'lib/AnyEvent/I3X/Workspace/OnDemand.pm',
    'lib/AnyEvent/I3X/Workspace/OnDemand/UserGuide.pod',
    't/00-compile.t',
    't/01-basic.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
