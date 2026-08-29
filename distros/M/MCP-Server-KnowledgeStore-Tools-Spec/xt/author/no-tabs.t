use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.15

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/MCP/Server/KnowledgeStore/Tools/Spec.pm',
    't/00-compile.t',
    't/01-basic.t',
    't/02-tools.t'
);

notabs_ok($_) foreach @files;
done_testing;
