use v5.38;
use Test::Most;

use Digest::SHA qw(sha256_hex);
use MCP::Client;
use Test::Mojo;
use MCP::Server::KnowledgeStore::Store;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');
$store->migrate;

subtest 'minting' => sub {
  my $token = $store->create_token('machine-a');
  is $token->{name}, 'machine-a', 'named';
  like $token->{token}, qr/\Amcp_ks_[A-Za-z0-9_-]{43}\z/,
    'prefixed, url-safe, 32 bytes of entropy';
  ok $token->{created_at}, 'timestamped';

  # Only the hash is stored, so a database dump yields nothing usable.
  my $stored
    = $store->db->query('SELECT token_hash FROM tokens WHERE name = ?',
    'machine-a')->hash;
  is $stored->{token_hash}, sha256_hex($token->{token}), 'stored as its hash';
  isnt $stored->{token_hash}, $token->{token}, 'not the token itself';

  my $second = $store->create_token('machine-b');
  isnt $second->{token}, $token->{token}, 'two mints differ';

  throws_ok { $store->create_token('machine-a') } qr/already exists/,
    'a name cannot be reused';
  throws_ok { $store->create_token('') } qr/name is required/, 'name required';
};

subtest 'verifying' => sub {
  my $token    = $store->create_token('machine-c');
  my $verified = $store->verify_token($token->{token});
  ok $verified, 'a live token verifies';
  is $verified->{name}, 'machine-c', 'and identifies itself';
  ok $verified->{last_used_at}, 'use is stamped';

  is $store->verify_token('mcp_ks_nope'), undef, 'unknown token refused';
  is $store->verify_token(''),            undef, 'empty refused';
  is $store->verify_token(undef),         undef, 'undef refused';

  # The hash is what is stored; presenting it must not authenticate.
  is $store->verify_token(sha256_hex($token->{token})), undef,
    'presenting the stored hash does not work';
};

subtest 'revoking' => sub {
  my $token = $store->create_token('machine-d');
  ok $store->verify_token($token->{token}), 'works before revoking';

  my $revoked = $store->revoke_token('machine-d');
  ok $revoked->{revoked_at}, 'revoked';
  is $store->verify_token($token->{token}), undef, 'and stops working';

  is $store->revoke_token('machine-d'),     undef, 'revoking twice is a no-op';
  is $store->revoke_token('never-existed'), undef, 'as is an unknown name';

  # The row stays, so the audit trail of what once had access survives -
  # and the name stays reserved, so it cannot come back on a new token.
  my ($row) = grep { $_->{name} eq 'machine-d' } @{ $store->list_tokens };
  ok $row,            'the token is still listed';
  ok !$row->{active}, 'as inactive';
  throws_ok { $store->create_token('machine-d') } qr/revoked names stay/,
    'and its name cannot be recycled';
};

subtest 'listing' => sub {
  my $tokens = $store->list_tokens;
  eq_or_diff [map { $_->{name} } @$tokens],
    [qw(machine-a machine-b machine-c machine-d)], 'sorted by name';
  ok !(grep { exists $_->{token_hash} } @$tokens), 'hashes are never listed';
};

subtest 'a token authenticates the MCP endpoint and names the author' => sub {
  my $agent   = $store->create_token('claude-code machine-a');
  my $revoked = $store->create_token('retired-agent');
  $store->revoke_token('retired-agent');

  $ENV{MCP_KS_PG} = $ENV{TEST_ONLINE};
  delete $ENV{MCP_KS_TOKEN};    # database tokens only
  my $t = Test::Mojo->new('MCP::Server::KnowledgeStore');

  # No resource plugin is a dependency of this repo, so attribution is
  # proven with an ad hoc tool rather than save_memory - the app exposes
  # its assembled MCP::Server precisely so a tool can be added like this
  # after startup and still be dispatched to (see mcp_server in
  # MCP::Server::KnowledgeStore).
  my @seen_principals;
  $t->app->mcp_server->tool(
    name => 'whoami',
    code => sub ($tool, $args) {
      push @seen_principals, $tool->context->principal;
      return 'ok';
    },
  );

  my $client = sub ($token) {
    return MCP::Client->new(
      ua      => $t->ua,
      url     => $t->ua->server->url->path('/mcp'),
      headers => { Authorization => "Bearer $token" },
    );
  };

  my $ping = { jsonrpc => '2.0', id => 1, method => 'ping' };
  $t->post_ok(
    '/mcp',
    { Authorization => "Bearer $agent->{token}" },
    json => $ping
  )->status_is(200, 'a live token is accepted');
  $t->post_ok(
    '/mcp',
    { Authorization => "Bearer $revoked->{token}" },
    json => $ping
  )->status_is(401, 'a revoked token is not');
  $t->post_ok(
    '/mcp',
    { Authorization => 'Bearer mcp_ks_invented' },
    json => $ping
  )->status_is(401, 'nor an invented one');
  $t->post_ok('/mcp', json => $ping)->status_is(401, 'nor no token at all');

  # The token's name is what becomes the principal - the point of
  # naming them.
  $client->($agent->{token})->call_tool('whoami');
  is $seen_principals[0], 'claude-code machine-a',
    'the tool saw the token as its principal';

  ok $store->verify_token($agent->{token})->{last_used_at},
    'and the token records having been used';
};

subtest 'the bootstrap token still works, under its own name' => sub {
  $ENV{MCP_KS_TOKEN} = 'bootstrap-secret';
  my $t    = Test::Mojo->new('MCP::Server::KnowledgeStore');
  my $ping = { jsonrpc => '2.0', id => 1, method => 'ping' };

  $t->post_ok(
    '/mcp',
    { Authorization => 'Bearer bootstrap-secret' },
    json => $ping
  )->status_is(200, 'accepted');
  $t->post_ok(
    '/mcp',
    { Authorization => 'Bearer bootstrap-secre' },
    json => $ping
  )->status_is(401, 'and not a near miss');

  my @seen_principals;
  $t->app->mcp_server->tool(
    name => 'whoami',
    code => sub ($tool, $args) {
      push @seen_principals, $tool->context->principal;
      return 'ok';
    },
  );
  MCP::Client->new(
    ua      => $t->ua,
    url     => $t->ua->server->url->path('/mcp'),
    headers => { Authorization => 'Bearer bootstrap-secret' },
  )->call_tool('whoami');
  is $seen_principals[0], 'bootstrap',
    'the bootstrap credential is its own principal';
};

done_testing;
