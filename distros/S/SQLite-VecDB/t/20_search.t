use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $vdb = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('search_test');

# Add vectors with known positions
# v1 is close to [1,0,0], v2 is close to [0,1,0], v3 is [0,0,1]
$coll->add(id => 'v1', vector => [0.9, 0.1, 0.0]);
$coll->add(id => 'v2', vector => [0.1, 0.9, 0.0]);
$coll->add(id => 'v3', vector => [0.0, 0.0, 1.0]);

# Search for [1,0,0] — v1 should be closest
my @results = $coll->search(vector => [1.0, 0.0, 0.0], limit => 3);
is scalar @results, 3, 'search returns 3 results';

isa_ok $results[0], 'SQLite::VecDB::Result';
is $results[0]->id, 'v1', 'v1 is closest to [1,0,0]';
ok $results[0]->distance < $results[1]->distance, 'results ordered by distance';

# v2 should be second (some similarity via 0.1 component)
is $results[1]->id, 'v2', 'v2 is second closest';

# v3 is orthogonal
is $results[2]->id, 'v3', 'v3 is furthest';

# Search with limit
my @limited = $coll->search(vector => [1.0, 0.0, 0.0], limit => 1);
is scalar @limited, 1, 'limit constrains results';
is $limited[0]->id, 'v1', 'limited search still finds closest';

# Stringification
is "$results[0]", 'v1', 'result stringifies to id';

# Search for [0,1,0] — v2 should be closest
my @results2 = $coll->search(vector => [0.0, 1.0, 0.0], limit => 2);
is $results2[0]->id, 'v2', 'v2 closest to [0,1,0]';

done_testing;
