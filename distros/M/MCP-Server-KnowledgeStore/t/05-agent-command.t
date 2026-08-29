use v5.38;
use Test::Most;

use File::Temp qw(tempdir);
use Cwd        qw(getcwd);
use Test::Mojo;
use MCP::Server::KnowledgeStore::Command::agent;
use MCP::Server::KnowledgeStore::Store;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');

$ENV{MCP_KS_PG}    = $ENV{TEST_ONLINE};
$ENV{MCP_KS_TOKEN} = 'sekrit';

# Test::Mojo builds and starts up the app the same way the real
# ./bin/mcp-ks entrypoint does, migrations included.
my $app = Test::Mojo->new('MCP::Server::KnowledgeStore')->app;
my $cmd = MCP::Server::KnowledgeStore::Command::agent->new(app => $app);

# Commands write relative to the current directory by default, so this
# runs from a scratch dir the way an operator's shell would sit in a
# project checkout.
my $dir   = tempdir(CLEANUP => 1);
my $start = getcwd;
chdir $dir or die "chdir $dir: $!";

# The underlying _list/_pull/_push, not run(): run() converts a die into
# a printed message and exit(1) for a real terminal, which a direct,
# in-process call can't safely trigger the way a subprocess could.
sub capture ($sub, @args) {
  my $out = '';
  open my $fh, '>', \$out or die $!;
  my $old = select $fh;
  no strict 'refs';
  "MCP::Server::KnowledgeStore::Command::agent::_$sub"->($cmd, @args);
  select $old;
  return $out;
}

subtest 'push writes a local file into the store' => sub {
  Mojo::File->new('.claude/agents')->make_path;
  Mojo::File->new('.claude/agents/react-native-programming.md')
    ->spurt(
    "---\nname: react-native-programming\ntools: Read, Edit\n---\nBody.\n");

  my $out = capture(push => 'react-native-programming');
  like $out, qr/Pushed .*-> react-native-programming/, 'reported';

  my $agent = $store->get_agent('react-native-programming');
  like $agent->{body}, qr/tools: Read, Edit/,
    'stored verbatim, frontmatter intact';
};

subtest 'push --project tags it too' => sub {
  capture(push => 'react-native-programming', '--project', 'abto');
  my $agents = $store->list_agents('abto');
  is $agents->[0]{name}, 'react-native-programming', 'tagged for abto';
};

subtest 'pull writes the stored body back to a local file' => sub {
  $store->save_agent('cli', "---\nname: cli\n---\nShell stuff.\n");
  $store->tag_agent('cli', 'abto');

  Mojo::File->new('.claude/agents')->remove_tree if -d '.claude/agents';
  my $out = capture(pull => 'cli');
  like $out, qr/Pulled cli -> /, 'reported';

  my $file = Mojo::File->new('.claude/agents/cli.md');
  ok -e $file, 'file written';
  like $file->slurp, qr/Shell stuff\./, 'with the stored content';
};

subtest 'pull --project fetches every agent tagged for it' => sub {
  Mojo::File->new('.claude/agents')->remove_tree if -d '.claude/agents';
  my $out = capture(pull => '--project', 'abto');
  like $out, qr/Pulled cli -> /, 'cli pulled';
  like $out, qr/Pulled react-native-programming -> /,
    'react-native-programming pulled too - both tagged for abto';
  ok -e Mojo::File->new('.claude/agents/cli.md'), 'cli file present';
  ok -e Mojo::File->new('.claude/agents/react-native-programming.md'),
    'the other file present';
};

subtest 'pull of an unknown project is an error, not an empty success' => sub {
  throws_ok { capture(pull => '--project', 'nosuch') }
  qr/No agents tagged/, 'refused';
};

subtest 'push of a missing file is an error' => sub {
  throws_ok { capture(push => 'never-written') } qr/No such file/, 'refused';
};

subtest 'list' => sub {
  my $out = capture('list');
  like $out, qr/react-native-programming.*abto/, 'shows name and tags';
  like $out, qr/cli.*abto/,                      'both agents listed';
};

chdir $start or die "chdir back to $start: $!";

done_testing;
