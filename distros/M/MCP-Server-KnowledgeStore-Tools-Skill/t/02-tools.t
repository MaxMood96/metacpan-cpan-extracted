use v5.38;
use Test::Most;
use Mojolicious::Lite -signatures;
use MCP::Client;
use MCP::Server;
use Test::Mojo;
use MCP::Server::KnowledgeStore::Store;
use MCP::Server::KnowledgeStore::Tools::Skill;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');
$store->migrate;

my $mcp_server = MCP::Server->new(name => 'test');
MCP::Server::KnowledgeStore::Tools::Skill->register($mcp_server, $store);
any '/mcp' => $mcp_server->to_action;

my $t = Test::Mojo->new;
my $mcp = MCP::Client->new(ua => $t->ua, url => $t->ua->server->url->path('/mcp'));

subtest 'this plugin registers exactly its own tools' => sub {
  my @names = sort map { $_->{name} } @{ $mcp->list_tools->{tools} };
  eq_or_diff \@names, [sort qw(
    list_skills get_skill save_skill
    list_skill_revisions mark_skill_useful tag_skill untag_skill
  )], 'nothing borrowed from another plugin';
};

subtest 'save then read back a skill' => sub {
  my $saved = $mcp->call_tool(save_skill => {
    name => 'shell-workflows',
    content => 'Prefer zsh.',
    description => 'Shell conventions',
  });
  eq_or_diff $saved->{structuredContent},
    {name => 'shell-workflows', revision => 1}, 'saved as revision 1';

  my $skills = $mcp->call_tool('list_skills')->{structuredContent}{skills};
  eq_or_diff $skills, [{
    name => 'shell-workflows', description => 'Shell conventions',
    revision => 1, view_count => 0, useful_count => 0, projects => [],
  }], 'listed without a type - skills carry none';

  like $mcp->call_tool(get_skill => {name => 'shell-workflows'})
    ->{content}[0]{text}, qr/Prefer zsh\./, 'content returned, and viewed';
  is $mcp->call_tool('list_skills')->{structuredContent}{skills}[0]{view_count},
    1, 'the get bumped the view count';
};

subtest 'marking useful' => sub {
  $mcp->call_tool(mark_skill_useful => {name => 'shell-workflows'});
  is $mcp->call_tool('list_skills')
    ->{structuredContent}{skills}[0]{useful_count}, 1, 'incremented';

  my $missing = $mcp->call_tool(mark_skill_useful => {name => 'absent'});
  ok $missing->{isError}, 'marking a missing skill is an error';
};

subtest 'tagging is additive, and a save with project tags too' => sub {
  $mcp->call_tool(save_skill => {
    name => 'shell-workflows', content => 'Prefer zsh.', project => 'bta',
  });
  eq_or_diff $mcp->call_tool('list_skills')
    ->{structuredContent}{skills}[0]{projects}, ['bta'],
    'save with project tags rather than replaces';

  $mcp->call_tool(tag_skill => {name => 'shell-workflows', project => 'mcp-ks'});
  eq_or_diff $mcp->call_tool('list_skills')
    ->{structuredContent}{skills}[0]{projects}, ['bta', 'mcp-ks'],
    'tag_skill adds another';

  $mcp->call_tool(untag_skill => {name => 'shell-workflows', project => 'bta'});
  eq_or_diff $mcp->call_tool('list_skills')
    ->{structuredContent}{skills}[0]{projects}, ['mcp-ks'],
    'untag removes just the one';

  my $missing = $mcp->call_tool(tag_skill => {name => 'absent', project => 'bta'});
  ok $missing->{isError}, 'tagging a missing skill is an error';
};

subtest 'revisions are appended, not overwritten' => sub {
  my $third = $mcp->call_tool(save_skill => {
    name => 'shell-workflows', content => 'Prefer zsh, but bash is fine too.',
  });
  eq_or_diff $third->{structuredContent},
    {name => 'shell-workflows', revision => 3},
    'third save (the tagging subtest already made one more)';

  my $revisions = $mcp->call_tool(
    list_skill_revisions => {name => 'shell-workflows'}
  )->{structuredContent}{revisions};
  eq_or_diff [map { $_->{revision} } @$revisions], [3, 2, 1], 'newest first';
  ok $revisions->[0]{is_head}, 'the newest is the head';
  ok !$revisions->[1]{is_head}, 'the older one is not';

  my $none = $mcp->call_tool(list_skill_revisions => {name => 'absent'});
  ok $none->{isError}, 'history of a missing entry is an error too';
};

subtest 'missing entries are tool errors, not crashes' => sub {
  my $result = $mcp->call_tool(get_skill => {name => 'absent'});
  ok $result->{isError}, 'flagged as an error';
  like $result->{content}[0]{text}, qr/No skill named 'absent'/, 'says which';
};

done_testing;
