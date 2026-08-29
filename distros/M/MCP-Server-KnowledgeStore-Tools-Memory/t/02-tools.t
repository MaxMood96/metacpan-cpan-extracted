use v5.38;
use Test::Most;
use Mojolicious::Lite -signatures;
use MCP::Client;
use MCP::Server;
use Test::Mojo;
use MCP::Server::KnowledgeStore::Store;
use MCP::Server::KnowledgeStore::Tools::Memory;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');
$store->migrate;

# A bare Mojolicious::Lite app, standing in for the real MCP::Server::KnowledgeStore -
# this plugin only needs a store and somewhere to mount /mcp, not the
# whole application (auth, health check, Waya).
my $mcp_server = MCP::Server->new(name => 'test');
MCP::Server::KnowledgeStore::Tools::Memory->register($mcp_server, $store);
any '/mcp' => $mcp_server->to_action;

my $t = Test::Mojo->new;
my $mcp
  = MCP::Client->new(ua => $t->ua, url => $t->ua->server->url->path('/mcp'));

subtest 'this plugin registers exactly its own tools' => sub {
  my @names = sort map { $_->{name} } @{ $mcp->list_tools->{tools} };
  eq_or_diff \@names, [
    sort qw(
      list_memories search_memories get_memory save_memory
      list_memory_revisions mark_memory_useful tag_memory untag_memory
      archive_memory restore_memory purge_memory list_archived_memories
    )
    ],
    'nothing borrowed from another plugin, includes new lifecycle tools';
};

# Note: Testing purge blocking (MCP_KS_NO_PURGE) would require a separate
# test server instance with the environment variable set. The main tests
# above verify purge works when enabled (the default).

subtest 'save then read back a memory' => sub {
  my $saved = $mcp->call_tool(
    save_memory => {
      name        => 'no-auto-commit',
      content     => "Stage only, then ask.\n",
      type        => 'feedback',
      description => 'Commit etiquette',
    }
  );
  eq_or_diff $saved->{structuredContent},
    { name => 'no-auto-commit', revision => 1 }, 'saved as revision 1';

  my $list     = $mcp->call_tool('list_memories');
  my $memories = $list->{structuredContent}{memories};
  is scalar @$memories, 1, 'one memory listed';
  eq_or_diff $memories->[0],
    {
    name         => 'no-auto-commit',
    description  => 'Commit etiquette',
    type         => 'feedback',
    revision     => 1,
    view_count   => 0,
    useful_count => 0,
    projects     => [],
    },
    'summary carries the metadata and revision, but not the body';

  my $got = $mcp->call_tool(get_memory => { name => 'no-auto-commit' });
  like $got->{content}[0]{text}, qr/Stage only, then ask\./, 'body returned';
  like $got->{content}[0]{text}, qr/^  type: feedback$/m,
    'frontmatter too, type nested under metadata';

  my $listed
    = $mcp->call_tool('list_memories')->{structuredContent}{memories}[0];
  is $listed->{view_count}, 1, 'the get bumped the view count';
  ok $listed->{last_viewed_at}, 'and recorded when';
};

subtest 'marking useful' => sub {
  my $marked
    = $mcp->call_tool(mark_memory_useful => { name => 'no-auto-commit' });
  eq_or_diff $marked->{structuredContent},
    { name => 'no-auto-commit', useful_count => 1 }, 'first mark';

  $mcp->call_tool(mark_memory_useful => { name => 'no-auto-commit' });
  is $mcp->call_tool('list_memories')
    ->{structuredContent}{memories}[0]{useful_count}, 2, 'counts accumulate';

  my $missing = $mcp->call_tool(mark_memory_useful => { name => 'absent' });
  ok $missing->{isError}, 'marking a missing memory is an error';
};

subtest 'search' => sub {
  my $hits  = $mcp->call_tool(search_memories => { query => 'stage only' });
  my $found = $hits->{structuredContent}{memories};
  is scalar @$found, 1, 'found it';
  eq_or_diff $found->[0]{matches}, ['Stage only, then ask.'], 'matching line';

  my $none = $mcp->call_tool(search_memories => { query => 'nothing here' });
  eq_or_diff $none->{structuredContent}{memories}, [], 'no false hits';
};

subtest 'tagging is additive and independent of revisions' => sub {
  $mcp->call_tool(
    tag_memory => { name => 'no-auto-commit', project => 'mcp-ks' });
  $mcp->call_tool(
    tag_memory => { name => 'no-auto-commit', project => 'bta' });

  my $tagged
    = $mcp->call_tool('list_memories')->{structuredContent}{memories}[0];
  eq_or_diff $tagged->{projects}, ['bta', 'mcp-ks'], 'both tags present';

  is
    scalar @{ $mcp->call_tool(list_memories => { project => 'bta' })
      ->{structuredContent}{memories} }, 1, 'filtering by either tag finds it';
  is
    scalar @{ $mcp->call_tool(list_memories => { project => 'nosuch' })
      ->{structuredContent}{memories} }, 0,
    'an untagged project finds nothing';

  $mcp->call_tool(
    untag_memory => { name => 'no-auto-commit', project => 'bta' });
  eq_or_diff $mcp->call_tool('list_memories')
    ->{structuredContent}{memories}[0]{projects},
    ['mcp-ks'], 'untag removes just the one tag';

  my $missing
    = $mcp->call_tool(tag_memory => { name => 'absent', project => 'bta' });
  ok $missing->{isError}, 'tagging a missing memory is an error';
};

subtest 'missing entries are tool errors, not crashes' => sub {
  my $result = $mcp->call_tool(get_memory => { name => 'absent' });
  ok $result->{isError}, 'flagged as an error';
  like $result->{content}[0]{text}, qr/No memory named 'absent'/, 'says which';
};

subtest 'revisions are appended, not overwritten' => sub {
  my $second = $mcp->call_tool(
    save_memory => {
      name    => 'no-auto-commit',
      content => "Stage only, then wait for sign-off.\n",
      type    => 'feedback',
      author  => 'claude-code@machine-b',
    }
  );
  eq_or_diff $second->{structuredContent},
    { name => 'no-auto-commit', revision => 2 }, 'second save is revision 2';

  like $mcp->call_tool(get_memory => { name => 'no-auto-commit' })
    ->{content}[0]{text}, qr/wait for sign-off/, 'head is the new content';
  like $mcp->call_tool(
    get_memory => { name => 'no-auto-commit', revision => 1 })
    ->{content}[0]{text}, qr/then ask\./, 'revision 1 still readable';

  my $revisions
    = $mcp->call_tool(list_memory_revisions => { name => 'no-auto-commit' })
    ->{structuredContent}{revisions};
  eq_or_diff [map { $_->{revision} } @$revisions], [2, 1], 'newest first';
  ok $revisions->[0]{is_head},  'the newest is the head';
  ok !$revisions->[1]{is_head}, 'the older one is not';
  is $revisions->[0]{author}, 'claude-code@machine-b',
    'the author the client claimed';
};

subtest 'a missing revision is an error, not the head' => sub {
  my $result = $mcp->call_tool(
    get_memory => { name => 'no-auto-commit', revision => 99 });
  ok $result->{isError}, 'flagged as an error';
  like $result->{content}[0]{text}, qr/at revision 99/, 'says which revision';

  my $none = $mcp->call_tool(list_memory_revisions => { name => 'absent' });
  ok $none->{isError}, 'and history of a missing entry is an error too';
};

subtest 'archive and restore a memory' => sub {

  # Archive the memory
  my $archived = $mcp->call_tool(
    archive_memory => {
      name   => 'no-auto-commit',
      author => 'test-archiver',
      reason => 'Testing archive functionality'
    }
  );
  ok !$archived->{isError}, 'archive succeeded';
  eq_or_diff $archived->{structuredContent}{name}, 'no-auto-commit',
    'archived correct memory';
  ok $archived->{structuredContent}{archived_at}, 'has archived_at timestamp';

  # Verify it's hidden from list
  my $listed = $mcp->call_tool('list_memories')->{structuredContent}{memories};
  is scalar @$listed, 0, 'archived memory hidden from list';

  # Verify it's hidden from search
  my $search = $mcp->call_tool(search_memories => { query => 'Stage' })
    ->{structuredContent}{memories};
  is scalar @$search, 0, 'archived memory hidden from search';

  # Verify it's still gettable (for audit purposes)
  my $got = $mcp->call_tool(get_memory => { name => 'no-auto-commit' });
  ok !$got->{isError}, 'can still get archived memory';
  like $got->{content}[0]{text}, qr/Stage only, then wait for sign-off/,
    'content is intact';

  # List archived memories
  my $archived_list
    = $mcp->call_tool('list_archived_memories')->{structuredContent}{memories};
  is scalar @$archived_list, 1, 'one archived memory listed';
  eq_or_diff $archived_list->[0]{name}, 'no-auto-commit', 'correct name';

  # Restore the memory
  my $restored = $mcp->call_tool(
    restore_memory => {
      name   => 'no-auto-commit',
      author => 'test-restorer',
      reason => 'Bringing it back'
    }
  );
  ok !$restored->{isError}, 'restore succeeded';
  eq_or_diff $restored->{structuredContent}{name}, 'no-auto-commit',
    'restored correct memory';

  # Verify it's visible again
  $listed = $mcp->call_tool('list_memories')->{structuredContent}{memories};
  is scalar @$listed, 1, 'restored memory visible in list';
  eq_or_diff $listed->[0]{name}, 'no-auto-commit', 'correct name in list';

  # Archive with expected_revision check
  my $current
    = $mcp->call_tool(list_memory_revisions => { name => 'no-auto-commit' })
    ->{structuredContent}{revisions}[0]{revision};

  $archived = $mcp->call_tool(
    archive_memory => {
      name              => 'no-auto-commit',
      expected_revision => $current,
      author            => 'test-archiver-v2',
      reason            => 'With revision check'
    }
  );
  ok !$archived->{isError}, 'archive with expected_revision succeeded';

  # Try to archive again (already archived)
  my $double = $mcp->call_tool(
    archive_memory => {
      name   => 'no-auto-commit',
      author => 'test-archiver-3'
    }
  );
  ok $double->{isError}, 'archiving already archived memory is an error';

  # Restore again for cleanup
  $mcp->call_tool(
    restore_memory => { name => 'no-auto-commit', author => 'cleanup' });
};

subtest 'purge a memory permanently' => sub {

  # Create a memory to purge
  $mcp->call_tool(
    save_memory => {
      name        => 'to-be-purged',
      content     => "This will be deleted.\n",
      type        => 'user',
      description => 'Purge test',
    }
  );

  # Purge it
  my $purged = $mcp->call_tool(
    purge_memory => {
      name   => 'to-be-purged',
      author => 'test-purger',
      reason => 'Testing purge'
    }
  );
  ok !$purged->{isError}, 'purge succeeded';
  eq_or_diff $purged->{structuredContent}{name}, 'to-be-purged',
    'purged correct memory';
  ok $purged->{structuredContent}{deleted}, 'marked as deleted';

  # Verify it's completely gone
  my $gone = $mcp->call_tool(get_memory => { name => 'to-be-purged' });
  ok $gone->{isError}, 'purged memory cannot be retrieved';

  my $listed = $mcp->call_tool('list_memories')->{structuredContent}{memories};
  is scalar @$listed, 0, 'purged memory not in list';

  my $archived
    = $mcp->call_tool('list_archived_memories')->{structuredContent}{memories};
  is scalar @$archived, 0, 'purged memory not in archived list';

  # Purge a missing memory is an error
  my $missing = $mcp->call_tool(
    purge_memory => {
      name   => 'never-existed',
      author => 'test'
    }
  );
  ok $missing->{isError}, 'purging missing memory is an error';
};

subtest 'archive with wrong expected_revision fails' => sub {

  # Create a fresh memory
  $mcp->call_tool(
    save_memory => {
      name        => 'rev-check-test',
      content     => "Initial.\n",
      type        => 'user',
      description => 'Revision check test',
    }
  );

  # Try to archive with wrong revision
  my $failed = $mcp->call_tool(
    archive_memory => {
      name              => 'rev-check-test',
      expected_revision => 999,
      author            => 'test',
    }
  );
  ok $failed->{isError}, 'archive with wrong expected_revision fails';
  like $failed->{content}[0]{text}, qr/expected revision 999 but current is 1/,
    'error message shows actual revision';

  # Archive with correct revision should work
  my $success = $mcp->call_tool(
    archive_memory => {
      name              => 'rev-check-test',
      expected_revision => 1,
      author            => 'test',
    }
  );
  ok !$success->{isError}, 'archive with correct expected_revision works';

  # Restore for cleanup
  $mcp->call_tool(
    restore_memory => { name => 'rev-check-test', author => 'cleanup' });
};

done_testing;
