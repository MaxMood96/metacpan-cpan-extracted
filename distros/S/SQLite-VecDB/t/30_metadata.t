use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $vdb = eval { SQLite::VecDB->new(db_file => ':memory:', dimensions => 3) };
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('meta_test');

# Add with metadata and content
$coll->add(
  id       => 'doc1',
  vector   => [1.0, 0.0, 0.0],
  metadata => { title => 'First Doc', tags => ['perl', 'sqlite'] },
  content  => 'This is the first document.',
);

$coll->add(
  id       => 'doc2',
  vector   => [0.0, 1.0, 0.0],
  metadata => { title => 'Second Doc' },
);

# Add without metadata
$coll->add(
  id     => 'doc3',
  vector => [0.0, 0.0, 1.0],
);

# Get with metadata
my $r1 = $coll->get(id => 'doc1');
is $r1->metadata->{title}, 'First Doc', 'metadata title preserved';
is $r1->metadata->{tags}, ['perl', 'sqlite'], 'metadata arrays preserved';
ok $r1->has_content, 'content predicate true';
is $r1->content, 'This is the first document.', 'content preserved';

# Get without metadata
my $r3 = $coll->get(id => 'doc3');
is $r3->metadata, {}, 'no metadata returns empty hashref';
ok !$r3->has_content, 'no content predicate false';

# Search returns metadata
my @results = $coll->search(vector => [1.0, 0.0, 0.0], limit => 3);
is $results[0]->metadata->{title}, 'First Doc', 'search results include metadata';
ok $results[0]->has_content, 'search results include content';
is $results[0]->content, 'This is the first document.', 'search content matches';

# Unicode metadata
$coll->add(
  id       => 'doc4',
  vector   => [0.5, 0.5, 0.0],
  metadata => { title => "Ümlauts & Straße" },
  content  => "Ελληνικά",
);
my $r4 = $coll->get(id => 'doc4');
is $r4->metadata->{title}, "Ümlauts & Straße", 'unicode metadata preserved';
is $r4->content, "Ελληνικά", 'unicode content preserved';

# Batch add with metadata
$coll->add_batch(
  { id => 'b1', vector => [0.3, 0.3, 0.4], metadata => { batch => 1 } },
  { id => 'b2', vector => [0.4, 0.3, 0.3], metadata => { batch => 2 } },
);
is $coll->count, 6, 'batch add works with metadata';
is $coll->get(id => 'b1')->metadata->{batch}, 1, 'batch metadata preserved';

done_testing;
