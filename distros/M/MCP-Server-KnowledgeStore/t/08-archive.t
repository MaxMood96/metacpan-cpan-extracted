use v5.38;
use Test::Most;
use MCP::Server::KnowledgeStore::Store;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

# Same throwaway database as the other TEST_ONLINE files, wiped so this
# starts empty. t/02-store.t only exercises Test::StoreDouble (an
# in-memory reimplementation), which can't catch a bug in the real SQL -
# archive() had a bind-parameter order mismatch (author/reason bound
# last while the UPDATE's placeholders put them first) that made every
# archive_* call return success while updating zero rows, entirely
# undetected until this file existed. See git log for the fix.
my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');
$store->migrate;

subtest 'archive actually hides an entry and marks it archived' => sub {
  $store->save(
    'memory', 'archive-me', 'body',
    type   => 'reference',
    author => 'test'
  );
  ok((grep { $_->{name} eq 'archive-me' } @{ $store->list('memory') }),
    'visible before archiving');

  $store->archive('memory', 'archive-me', author => 'test');

  my $entry = $store->get('memory', 'archive-me');
  ok($entry, 'get still returns the entry after archiving');
  ok($entry->{archived_at},
    'archived_at is actually set - the real bug: this silently stayed unset');
  ok(!(grep { $_->{name} eq 'archive-me' } @{ $store->list('memory') }),
    'excluded from list() after archiving');

  ok(
    (grep { $_->{name} eq 'archive-me' } @{ $store->list_archived('memory') }),
    'appears in list_archived()'
  );

  throws_ok { $store->archive('memory', 'archive-me', author => 'test') }
  qr/already archived/,
    're-archiving an already-archived entry is refused, not silently a no-op';
};

subtest 'restore brings it back' => sub {
  $store->restore('memory', 'archive-me', author => 'test');
  ok((grep { $_->{name} eq 'archive-me' } @{ $store->list('memory') }),
    'visible in list() again after restore');
  my $entry = $store->get('memory', 'archive-me');
  ok(!$entry->{archived_at}, 'archived_at cleared after restore');
};

subtest 'purge actually deletes' => sub {
  $store->purge('memory', 'archive-me', author => 'test');
  is($store->get('memory', 'archive-me'), undef, 'gone entirely after purge');
};

subtest 'archiving an unknown entry is refused' => sub {
  throws_ok { $store->archive('memory', 'never-existed', author => 'test') }
  qr/no memory named/;
};

done_testing;
