use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::EOL 0.19

use Test::More 0.88;
use Test::EOL;

my @files = (
    'bin/mcp-ks',
    'lib/MCP/Server/KnowledgeStore.pm',
    'lib/MCP/Server/KnowledgeStore/Command/agent.pm',
    'lib/MCP/Server/KnowledgeStore/Command/rebuild_vectors.pm',
    'lib/MCP/Server/KnowledgeStore/Command/token.pm',
    'lib/MCP/Server/KnowledgeStore/ResourceTemplates.pm',
    'lib/MCP/Server/KnowledgeStore/Store.pm',
    'lib/MCP/Server/KnowledgeStore/TermWeight.pm',
    'lib/MCP/Server/KnowledgeStore/Tools.pm',
    'lib/MCP/Server/KnowledgeStore/Tools/Revisioned.pm',
    'lib/MCP/Server/KnowledgeStore/Tools/Support.pm',
    't/00-compile.t',
    't/01-basic.t',
    't/02-store.t',
    't/03-mcp.t',
    't/04-tokens.t',
    't/05-agent-command.t',
    't/06-vector-search.t',
    't/07-logging.t',
    't/08-archive.t',
    't/09-cached-plan.t',
    't/lib/Test/StoreDouble.pm'
);

eol_unix_ok($_, { trailing_whitespace => 1 }) foreach @files;
done_testing;
