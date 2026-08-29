use v5.38;
use Test::Most;
use MCP::Client;
use Test::Mojo;
use MCP::Server::KnowledgeStore::Store;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

# Same throwaway database as t/02, wiped so this file starts empty.
my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');

$ENV{MCP_KS_PG}    = $ENV{TEST_ONLINE};
$ENV{MCP_KS_TOKEN} = 'sekrit';

# The app migrates on startup, so this also covers that path.
my $t = Test::Mojo->new('MCP::Server::KnowledgeStore');

# In-process, so nothing binds a port. The client shares the test user
# agent and talks to Test::Mojo's own server.
sub client (%opts) {
  return MCP::Client->new(
    ua  => $t->ua,
    url => $t->ua->server->url->path('/mcp'),
    %opts,
  );
}

my $mcp = client(headers => { Authorization => 'Bearer sekrit' });

subtest 'health needs no token and checks the database' => sub {
  $t->get_ok('/health')
    ->status_is(200)
    ->json_is('/status'   => 'ok')
    ->json_is('/database' => 'up');
};

subtest 'the token is enforced' => sub {
  $t->post_ok('/mcp', json => { jsonrpc => '2.0', id => 1, method => 'ping' })
    ->status_is(401);
  $t->post_ok(
    '/mcp',
    { Authorization => 'Bearer wrong' },
    json => { jsonrpc => '2.0', id => 1, method => 'ping' }
  )->status_is(401);
  $t->post_ok(
    '/mcp',
    { Authorization => 'sekrit' },
    json => { jsonrpc => '2.0', id => 1, method => 'ping' }
  )->status_is(401);
};

# Everything else (memory/skill/spec/agent tools) lives in whichever
# MCP::Server::KnowledgeStore::Tools::* plugin distributions happen to be
# installed on the machine running this test - none are a dependency
# of this repo, so their presence or absence here says nothing about
# this repo's own correctness. What is guaranteed regardless is that
# this repo's own core tool is always registered.
subtest 'the core tool is always registered, whatever else is installed' =>
  sub {
  my @names = map { $_->{name} } @{ $mcp->list_tools->{tools} };
  ok + (grep { $_ eq 'list_projects' } @names), 'list_projects is there';
  };

subtest 'list_projects aggregates across whatever plugins tagged' => sub {
  eq_or_diff $mcp->call_tool('list_projects')->{structuredContent}{projects},
    [], 'nothing tagged anything yet';
};

done_testing;
