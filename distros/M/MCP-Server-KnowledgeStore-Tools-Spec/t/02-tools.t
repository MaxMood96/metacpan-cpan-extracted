use v5.38;
use Test::Most;
use Mojolicious::Lite -signatures;
use MCP::Client;
use MCP::Server;
use Test::Mojo;
use MCP::Server::KnowledgeStore::Store;
use MCP::Server::KnowledgeStore::Tools::Spec;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');
$store->migrate;

my $mcp_server = MCP::Server->new(name => 'test');
MCP::Server::KnowledgeStore::Tools::Spec->register($mcp_server, $store);
any '/mcp' => $mcp_server->to_action;

my $t = Test::Mojo->new;
my $mcp = MCP::Client->new(ua => $t->ua, url => $t->ua->server->url->path('/mcp'));

subtest 'this plugin registers exactly its own tools' => sub {
  my @names = sort map { $_->{name} } @{ $mcp->list_tools->{tools} };
  eq_or_diff \@names, [sort qw(
    list_specs get_spec save_spec list_spec_revisions mark_spec_useful
  )], 'nothing borrowed from another plugin, and no tag/untag';
};

subtest 'specs need a project' => sub {
  throws_ok {
    $mcp->call_tool(save_spec => {name => 'ok-name', content => 'x'})
  } qr/-32602|Invalid arguments/, 'project is required by the schema';

  my $saved = $mcp->call_tool(save_spec => {
    name => 'mcp-ks-spec',
    content => "This is the plan.\n",
    description => 'The server spec',
    project => 'mcp-ks',
    type => 'project',
  });
  eq_or_diff $saved->{structuredContent},
    {name => 'mcp-ks-spec', revision => 1}, 'saved as revision 1';

  my $specs = $mcp->call_tool(list_specs => {project => 'mcp-ks'})
    ->{structuredContent}{specs};
  eq_or_diff $specs, [{
    name => 'mcp-ks-spec', description => 'The server spec',
    project => 'mcp-ks', revision => 1,
    view_count => 0, useful_count => 0, projects => [],
  }], 'listed under its project, with no type';

  like $mcp->call_tool(get_spec => {name => 'mcp-ks-spec'})
    ->{content}[0]{text}, qr/This is the plan\./, 'content returned, and viewed';
  is $mcp->call_tool(list_specs => {project => 'mcp-ks'})
    ->{structuredContent}{specs}[0]{view_count}, 1, 'the get bumped the view count';
};

subtest 'marking useful' => sub {
  $mcp->call_tool(mark_spec_useful => {name => 'mcp-ks-spec'});
  is $mcp->call_tool(list_specs => {project => 'mcp-ks'})
    ->{structuredContent}{specs}[0]{useful_count}, 1, 'incremented';

  my $missing = $mcp->call_tool(mark_spec_useful => {name => 'absent'});
  ok $missing->{isError}, 'marking a missing spec is an error';
};

subtest 'revisions are appended, not overwritten' => sub {
  my $second = $mcp->call_tool(save_spec => {
    name => 'mcp-ks-spec', content => "Updated plan.\n", project => 'mcp-ks',
  });
  eq_or_diff $second->{structuredContent},
    {name => 'mcp-ks-spec', revision => 2}, 'second save is revision 2';

  my $revisions = $mcp->call_tool(
    list_spec_revisions => {name => 'mcp-ks-spec'}
  )->{structuredContent}{revisions};
  eq_or_diff [map { $_->{revision} } @$revisions], [2, 1], 'newest first';

  my $none = $mcp->call_tool(list_spec_revisions => {name => 'absent'});
  ok $none->{isError}, 'history of a missing entry is an error too';
};

subtest 'missing entries are tool errors, not crashes' => sub {
  my $result = $mcp->call_tool(get_spec => {name => 'absent'});
  ok $result->{isError}, 'flagged as an error';
  like $result->{content}[0]{text}, qr/No spec named 'absent'/, 'says which';
};

done_testing;
