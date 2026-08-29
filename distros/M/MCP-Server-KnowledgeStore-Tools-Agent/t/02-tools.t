use v5.38;
use Test::Most;
use Mojolicious::Lite -signatures;
use MCP::Client;
use MCP::Server;
use Test::Mojo;
use MCP::Server::KnowledgeStore::Store;
use MCP::Server::KnowledgeStore::Tools::Agent;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');
$store->migrate;

my $mcp_server = MCP::Server->new(name => 'test');
MCP::Server::KnowledgeStore::Tools::Agent->register($mcp_server, $store);
any '/mcp' => $mcp_server->to_action;

my $t = Test::Mojo->new;
my $mcp
  = MCP::Client->new(ua => $t->ua, url => $t->ua->server->url->path('/mcp'));

subtest 'this plugin registers exactly its own tools' => sub {
  my @names = sort map { $_->{name} } @{ $mcp->list_tools->{tools} };
  eq_or_diff \@names,
    [sort qw(list_agents get_agent save_agent tag_agent untag_agent)],
    'nothing borrowed from another plugin';
};

subtest 'agents are global; project is a separate tailoring tag' => sub {
  my $saved = $mcp->call_tool(
    save_agent => {
      name    => 'react-native-programming',
      content =>
        "---\nname: react-native-programming\ntools: Read, Edit\n---\nBody.\n",
    }
  );
  is $saved->{structuredContent}{name}, 'react-native-programming', 'saved';

  like $mcp->call_tool(get_agent => { name => 'react-native-programming' })
    ->{content}[0]{text}, qr/tools: Read, Edit/,
    'frontmatter preserved verbatim';

  # Overwrite in place: no revision to read back.
  $mcp->call_tool(
    save_agent => {
      name    => 'react-native-programming',
      content => 'Updated body.'
    }
  );
  like $mcp->call_tool(get_agent => { name => 'react-native-programming' })
    ->{content}[0]{text}, qr/Updated body\./, 'overwritten, not appended';

  # Tailored for two projects: no per-project copy, one shared agent.
  $mcp->call_tool(
    tag_agent => { name => 'react-native-programming', project => 'abto' });
  $mcp->call_tool(
    tag_agent => { name => 'react-native-programming', project => 'bta' });

  eq_or_diff $mcp->call_tool('list_agents')
    ->{structuredContent}{agents}[0]{projects}, ['abto', 'bta'],
    'both tags on the one agent';

  my $abto_agents = $mcp->call_tool(list_agents => { project => 'abto' })
    ->{structuredContent}{agents};
  is scalar @$abto_agents,    1, 'filtering list_agents by project finds it';
  is $abto_agents->[0]{name}, 'react-native-programming', 'the right one';
  is
    scalar @{ $mcp->call_tool(list_agents => { project => 'nosuch' })
      ->{structuredContent}{agents} }, 0, 'an untagged project finds nothing';

  $mcp->call_tool(
    untag_agent => { name => 'react-native-programming', project => 'bta' });
  eq_or_diff $mcp->call_tool('list_agents')
    ->{structuredContent}{agents}[0]{projects}, ['abto'],
    'untag removes just the one tag';

  my $missing = $mcp->call_tool(get_agent => { name => 'absent' });
  ok $missing->{isError}, 'a missing agent is a tool error';

  my $missing_tag
    = $mcp->call_tool(tag_agent => { name => 'absent', project => 'abto' });
  ok $missing_tag->{isError}, 'tagging a missing agent is an error too';
};

done_testing;
