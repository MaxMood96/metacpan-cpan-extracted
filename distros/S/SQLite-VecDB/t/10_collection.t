use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $vdb = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('test');
isa_ok $coll, 'SQLite::VecDB::Collection';

# Empty collection
is $coll->count, 0, 'empty collection has count 0';

# Add a vector
my $id = $coll->add(
  id     => 'v1',
  vector => [1.0, 0.0, 0.0],
);
is $id, 'v1', 'add returns id';
is $coll->count, 1, 'count is 1 after add';

# Get by id
my $result = $coll->get(id => 'v1');
isa_ok $result, 'SQLite::VecDB::Result';
is $result->id, 'v1', 'get returns correct id';

# Get non-existent
my $missing = $coll->get(id => 'nope');
ok !defined $missing, 'get returns undef for missing id';

# Add more
$coll->add(id => 'v2', vector => [0.0, 1.0, 0.0]);
$coll->add(id => 'v3', vector => [0.0, 0.0, 1.0]);
is $coll->count, 3, 'count is 3 after adding more';

# Delete
my $deleted = $coll->delete(id => 'v2');
is $deleted, 1, 'delete returns 1 for existing';
is $coll->count, 2, 'count decreased after delete';

my $not_deleted = $coll->delete(id => 'nope');
is $not_deleted, 0, 'delete returns 0 for missing';

# Multiple collections
my $coll2 = $vdb->collection('other');
is $coll2->count, 0, 'new collection is empty';
$coll2->add(id => 'x1', vector => [0.5, 0.5, 0.0]);
is $coll2->count, 1, 'second collection has its own count';
is $coll->count, 2, 'first collection unchanged';

# List collections
my @names = sort $vdb->collections;
is \@names, [qw(other test)], 'collections lists both';

# Default collection
my $default = $vdb->collection;
isa_ok $default, 'SQLite::VecDB::Collection';

done_testing;
