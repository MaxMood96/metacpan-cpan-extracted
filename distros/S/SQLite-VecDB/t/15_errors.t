use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $vdb = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('errors');

# --- Missing required arguments ---

like dies { $coll->add(vector => [1,0,0]) },
  qr/id is required/, 'add without id croaks';

like dies { $coll->add(id => 'x') },
  qr/vector is required/, 'add without vector croaks';

like dies { $coll->search() },
  qr/vector is required/, 'search without vector croaks';

like dies { $coll->get() },
  qr/id is required/, 'get without id croaks';

like dies { $coll->delete() },
  qr/id is required/, 'delete without id croaks';

# --- Wrong vector dimensions ---

like dies { $coll->add(id => 'x', vector => [1,0]) },
  qr/3 dimensions/, 'add with too few dimensions croaks';

like dies { $coll->add(id => 'x', vector => [1,0,0,0]) },
  qr/3 dimensions/, 'add with too many dimensions croaks';

# --- Duplicate IDs ---

$coll->add(id => 'dup', vector => [1,0,0]);
is $coll->count, 1, 'first add succeeds';

like dies { $coll->add(id => 'dup', vector => [0,1,0]) },
  qr/Failed to add/, 'duplicate id croaks';

is $coll->count, 1, 'count unchanged after duplicate id error (rollback works)';

# Verify original is still intact
my $r = $coll->get(id => 'dup');
ok $r, 'original vector still accessible after duplicate error';

# --- Delete then search ---

$coll->add(id => 'a', vector => [0.9, 0.1, 0.0]);
$coll->add(id => 'b', vector => [0.0, 0.9, 0.1]);
$coll->add(id => 'c', vector => [0.0, 0.1, 0.9]);
is $coll->count, 4, 'four vectors total';

my @before = $coll->search(vector => [1.0, 0.0, 0.0], limit => 10);
my %ids_before = map { $_->id => 1 } @before;
ok $ids_before{a}, 'vector a found in search before delete';

$coll->delete(id => 'a');
is $coll->count, 3, 'count 3 after delete';

my @after = $coll->search(vector => [1.0, 0.0, 0.0], limit => 10);
my %ids_after = map { $_->id => 1 } @after;
ok !$ids_after{a}, 'deleted vector a is gone from search results';
ok $ids_after{b}, 'vector b still in results';
ok $ids_after{c}, 'vector c still in results';

# --- Batch add with failure (duplicate) rolls back entirely ---

my $coll2 = $vdb->collection('batch_errors');
$coll2->add(id => 'existing', vector => [1,0,0]);
is $coll2->count, 1, 'pre-existing vector for batch test';

like dies {
  $coll2->add_batch(
    { id => 'new1', vector => [0,1,0] },
    { id => 'existing', vector => [0,0,1] },  # duplicate!
    { id => 'new2', vector => [0.5,0.5,0] },
  );
}, qr/Batch add failed/, 'batch with duplicate croaks';

is $coll2->count, 1, 'batch rolled back entirely — count still 1';
ok !$coll2->get(id => 'new1'), 'new1 was rolled back';

done_testing;
