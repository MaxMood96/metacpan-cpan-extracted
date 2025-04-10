use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.18

use Test::More 0.88;
use Test::EOL;

my @files = (
    'lib/JSON/RPC/LWP.pm',
    't/agent.t',
    't/agent_subclass.t',
    't/init.t',
    't/lazy.t',
    't/lib/Util.pm',
    't/load.t'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
