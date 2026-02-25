use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

# Mock embedding engine — no API key needed
{
  package MockEmbeddingEngine;
  use Moose;

  # Returns a deterministic 3-dim vector based on text content
  sub simple_embedding {
    my ( $self, $text ) = @_;
    # Simple hash-based mock: different texts get different vectors
    my @chars = split //, $text;
    my $sum = 0;
    $sum += ord($_) for @chars;
    my $a = sin($sum);
    my $b = cos($sum);
    my $c = sin($sum * 2);
    # Normalize
    my $norm = sqrt($a*$a + $b*$b + $c*$c) || 1;
    return [$a/$norm, $b/$norm, $c/$norm];
  }

  # Satisfy the Embedding role check
  sub does {
    my ( $self, $role ) = @_;
    return 1 if $role && $role eq 'Langertha::Role::Embedding';
    return $self->SUPER::does($role);
  }
}

my $engine = MockEmbeddingEngine->new;

my $vdb = eval {
  SQLite::VecDB->new(
    db_file    => ':memory:',
    dimensions => 3,
    embedding  => $engine,
  );
};
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('embed_test');

# Check that embedding methods are available
ok $coll->can('add_text'), 'collection has add_text method';
ok $coll->can('search_text'), 'collection has search_text method';

# add_text stores vector and content
$coll->add_text(id => 'doc1', text => 'hello world');
$coll->add_text(id => 'doc2', text => 'goodbye moon');
$coll->add_text(id => 'doc3', text => 'hello earth');

is $coll->count, 3, 'add_text adds vectors';

# Content is stored as the text
my $r = $coll->get(id => 'doc1');
is $r->content, 'hello world', 'add_text stores text as content';

# search_text works
my @results = $coll->search_text(text => 'hello world', limit => 3);
is scalar @results, 3, 'search_text returns results';
is $results[0]->id, 'doc1', 'search_text finds exact match first';

# Custom content overrides text
$coll->add_text(
  id      => 'doc4',
  text    => 'some embedding text',
  content => 'display content',
);
my $r4 = $coll->get(id => 'doc4');
is $r4->content, 'display content', 'custom content overrides text';

# Collection without embedding does NOT have add_text
my $vdb_raw = eval {
  SQLite::VecDB->new(db_file => ':memory:', dimensions => 3);
};
if ($vdb_raw) {
  my $raw_coll = $vdb_raw->collection('raw');
  ok !$raw_coll->can('add_text'), 'collection without embedding has no add_text';
  ok !$raw_coll->can('search_text'), 'collection without embedding has no search_text';
}

done_testing;
