use v5.38;
use Test::Most;
use MCP::Server::KnowledgeStore::Store;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

# Postgres plans a prepared statement custom for its first few executions
# and then switches to a generic plan it holds on to. Once it has, any
# change to the shape of that statement's result makes every later
# execution fail with "cached plan must not change result type", and
# because Mojo::Pg runs everything through prepare_cached the broken plan
# stays on that pooled connection until the process dies.
#
# A migration is enough to trigger it, which is how it happened: writes
# kept working while every search failed, and only a restart cleared it.
subtest 'a statement survives its table changing shape' => sub {
  my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
  my $db    = $store->db;

  $db->query('DROP TABLE IF EXISTS cached_plan_probe');
  $db->query('CREATE TABLE cached_plan_probe (id int, val text)');
  $db->query('INSERT INTO cached_plan_probe VALUES (1, ?)', 'a');

  my $sql = 'SELECT * FROM cached_plan_probe WHERE id = ?';

  # Past the custom-plan threshold, so a generic plan is in place.
  $db->query($sql, 1) for 1 .. 6;

  $db->query('ALTER TABLE cached_plan_probe ADD COLUMN extra int');

  lives_ok { $db->query($sql, 1) }
  'the statement still runs after the result type changed';

  $db->query('DROP TABLE IF EXISTS cached_plan_probe');
};

done_testing;
