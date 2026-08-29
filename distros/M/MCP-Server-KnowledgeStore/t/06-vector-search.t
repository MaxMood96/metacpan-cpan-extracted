use v5.38;
use Test::Most;
use MCP::Server;
use MCP::Server::KnowledgeStore::Store;
use MCP::Server::KnowledgeStore::TermWeight;

plan skip_all => 'set TEST_ONLINE to a postgres connection string'
  unless $ENV{TEST_ONLINE};

my $store = MCP::Server::KnowledgeStore::Store->new(pg => $ENV{TEST_ONLINE});
$store->pg->db->query('DROP SCHEMA IF EXISTS public CASCADE');
$store->pg->db->query('CREATE SCHEMA public');
$store->migrate;

# Clean up
$store->pg->db->query(
  'TRUNCATE TABLE entries, revisions, tokens, document_tfidf, corpus_idf CASCADE'
);

subtest 'TermWeight module - basic vector operations' => sub {
  my $tw = MCP::Server::KnowledgeStore::TermWeight->new;

  # Test compute_tf
  my $tf = $tw->compute_tf('the quick brown fox jumps over the lazy dog');
  ok $tf && ref($tf) eq 'HASH', 'compute_tf returns hashref';
  ok exists $tf->{the},         'TF has "the"';
  ok exists $tf->{quick},       'TF has "quick"';
  ok $tf->{the} > 0,            'TF weight for "the" is positive';

  # Test compute_idf
  my $idf = $tw->compute_idf(
    ['the quick brown fox', 'over the lazy dog', 'the fox and the dog']);
  ok $idf && ref($idf) eq 'HASH', 'compute_idf returns hashref';
  ok exists $idf->{the},          'IDF has "the"';
  ok exists $idf->{fox},          'IDF has "fox"';

  # Test compute_tfidf
  my $tfidf = $tw->compute_tfidf('the quick brown fox', $idf);
  ok $tfidf && ref($tfidf) eq 'HASH', 'compute_tfidf returns hashref';

  # Test cosine_similarity
  my $vec1 = { the => 0.5, fox => 0.8 };
  my $vec2 = { the => 0.6, fox => 0.7 };
  my $sim  = $tw->cosine_similarity($vec1, $vec2);
  ok defined $sim, 'cosine_similarity returns a value';
  cmp_ok $sim, '>=', 0, 'similarity >= 0';
  cmp_ok $sim, '<=', 1, 'similarity <= 1';

  # Similarity of same vector should be 1
  my $sim_same = $tw->cosine_similarity($vec1, $vec1);
  cmp_ok $sim_same, '==', 1, 'similarity of identical vectors is 1';

  # Similarity of orthogonal vectors should be 0
  my $vec3      = { a => 1, b => 1 };
  my $vec4      = { c => 1, d => 1 };
  my $sim_ortho = $tw->cosine_similarity($vec3, $vec4);
  cmp_ok $sim_ortho, '==', 0, 'similarity of orthogonal vectors is 0';

  done_testing;
};

subtest 'Store - vector tables created by migration' => sub {
  my $db = $store->db;

  # Check search_vector column exists
  my $col = $db->query(
    q{
    SELECT column_name 
      FROM information_schema.columns 
     WHERE table_name = 'revisions' AND column_name = 'search_vector'
  }
  )->hash;
  ok $col, 'search_vector column exists';

  # Check document_tfidf table exists
  my $table = $db->query(
    q{
    SELECT table_name 
      FROM information_schema.tables 
     WHERE table_name = 'document_tfidf'
  }
  )->hash;
  ok $table, 'document_tfidf table exists';

  # Check corpus_idf table exists
  $table = $db->query(
    q{
    SELECT table_name 
      FROM information_schema.tables 
     WHERE table_name = 'corpus_idf'
  }
  )->hash;
  ok $table, 'corpus_idf table exists';

  # Check indices exist
  my $idx = $db->query(
    q{
    SELECT indexname 
      FROM pg_indexes 
     WHERE tablename = 'revisions' AND indexname = 'revisions_search_vector_idx'
  }
  )->hash;
  ok $idx, 'revisions_search_vector_idx index exists';

  $idx = $db->query(
    q{
    SELECT indexname 
      FROM pg_indexes 
     WHERE tablename = 'document_tfidf' AND indexname = 'document_tfidf_revision_idx'
  }
  )->hash;
  ok $idx, 'document_tfidf_revision_idx index exists';

  done_testing;
};

subtest 'Store - hybrid_search method' => sub {

  # Save a test memory first
  my $entry = $store->save(
    'memory', 'test-vector-memory',
    'This is a test memory for vector search',
    type        => 'user',
    description => 'Test description'
  );
  ok $entry, 'saved test memory';
  $store->save(
    'memory', 'unrelated-memory',
    'Completely different content',
    type        => 'user',
    description => 'Unrelated description'
  );
  $store->save(
    'memory', 'redis-memory',
    'Redis cache',
    type        => 'user',
    description => 'Exact weighted term'
  );
  $store->save(
    'memory', 'session-memory',
    'session storage',
    type        => 'user',
    description => 'PostgreSQL stemming candidate'
  );

  # Test hybrid_search
  my $results = $store->hybrid_search('memory', 'test-vector-memory');
  ok $results && ref($results) eq 'ARRAY', 'hybrid_search returns arrayref';
  is scalar(@$results),   1, 'hybrid_search returns the seeded memory';
  is $results->[0]{name}, 'test-vector-memory', 'hybrid_search finds by name';
  is $results->[0]{revision}, 1, 'hybrid_search returns the revision';
  cmp_ok $results->[0]{rank}, '>', 0, 'name contributes to TF-IDF rank';

  # If we got results, check structure
  if (@$results) {
    my $first = $results->[0];
    ok exists $first->{name},    'result has name';
    ok exists $first->{rank},    'result has rank';
    ok exists $first->{ts_rank}, 'result has ts_rank';
    ok defined $first->{rank},   'rank is defined';
    cmp_ok $first->{rank}, '>=', 0, 'rank >= 0';
    cmp_ok $first->{rank}, '<=', 1, 'rank <= 1';
  }

  my $cached = $store->hybrid_search('memory', 'test-vector-memory');
  is $cached->[0]{name}, 'test-vector-memory',
    'cached vector remains searchable';

  my $partial = $store->hybrid_search('memory', 'test absent-term');
  is $partial->[0]{name}, 'test-vector-memory',
    'candidate search matches any query term';

  my $pruned = $store->hybrid_search('memory', 'Redis sessions');
  is_deeply [map { $_->{name} } @$pruned], ['redis-memory'],
    'positive TF-IDF matches prune the zero-rank tail';

  my $fallback = $store->hybrid_search('memory', 'sessions');
  is $fallback->[0]{name}, 'session-memory',
    'PostgreSQL rank remains as an all-zero fallback';

  done_testing;
};

subtest 'Store - search now uses hybrid approach' => sub {

  # Test that search returns results with rank fields
  my $results = $store->search('memory', 'test');
  ok $results && ref($results) eq 'ARRAY', 'search returns arrayref';

  if (@$results) {
    my $first = $results->[0];

    # Should have both old fields (matches) and new fields (rank, ts_rank)
    ok exists $first->{matches}, 'result has matches (backward compat)';
    ok exists $first->{rank},    'result has rank';
    ok exists $first->{ts_rank}, 'result has ts_rank';
  }

  done_testing;
};

subtest 'Tools::Revisioned - one merged search tool' => sub {
  my $test_server = MCP::Server->new(name => 'test');

  # Mock a backend
  my $backend = bless {
    list          => sub { [] },
    search        => sub { [] },
    get           => sub { undef },
    save          => sub { {} },
    tag           => sub { 1 },
    untag         => sub { 1 },
    history       => sub { [] },
    mark_useful   => sub { 1 },
    archive       => sub { },
    restore       => sub { },
    purge         => sub { },
    list_archived => sub { [] },
    hybrid_search => sub { [] },
    },
    'MockBackend';

  require MCP::Server::KnowledgeStore::Tools::Revisioned;
  eval {
    MCP::Server::KnowledgeStore::Tools::Revisioned->register(
      $test_server, $backend,
      kind   => 'test',
      plural => 'tests',
      type   => 0,
      search => 1
    );
  };
  ok !$@, 'register with search=1 succeeded';

  # There is one search tool. It ranks with TF-IDF; the separate
  # hybrid_search_* tool it replaced is gone.
  my @tool_names = map { $_->name } @{ $test_server->tools };
  ok grep({ $_ eq 'search_tests' } @tool_names),
    'search_tests tool registered';
  ok !grep({ $_ eq 'hybrid_search_tests' } @tool_names),
    'no separate hybrid_search_tests tool';

  my ($search) = grep { $_->name eq 'search_tests' } @{ $test_server->tools };
  ok exists $search->input_schema->{properties}{limit},
    'the merged search tool takes a limit';

  done_testing;
};

subtest 'Tools::Revisioned - search tool still works' => sub {
  my $test_server = MCP::Server->new(name => 'test2');

  # Mock a backend with search
  my $backend = bless {
    list          => sub { [] },
    search        => sub { [] },
    get           => sub { undef },
    save          => sub { {} },
    tag           => sub { 1 },
    untag         => sub { 1 },
    history       => sub { [] },
    mark_useful   => sub { 1 },
    archive       => sub { },
    restore       => sub { },
    purge         => sub { },
    list_archived => sub { [] },
    },
    'MockBackend';

  # Test with search enabled but NO hybrid_search
  eval {
    MCP::Server::KnowledgeStore::Tools::Revisioned->register(
      $test_server, $backend,
      kind          => 'test2',
      plural        => 'test2s',
      type          => 0,
      search        => 1,
      hybrid_search => 0
    );
  };
  ok !$@, 'register with search=1, hybrid_search=0 succeeded';

  # Check that search_test2 tool was registered but NOT hybrid_search_test2
  my @tool_names = map { $_->name } @{ $test_server->tools };
  ok grep({ $_ eq 'search_test2s' } @tool_names),
    'search_test2s tool registered';
  ok !grep({ $_ eq 'hybrid_search_test2s' } @tool_names),
    'hybrid_search_test2s NOT registered';

  done_testing;
};

subtest 'TermWeight - batch operations' => sub {
  my $tw = MCP::Server::KnowledgeStore::TermWeight->new;

  my $documents
    = ['first document text', 'second document text', 'third document text'];

  # Test compute_idf with multiple documents
  my $idf = $tw->compute_idf($documents);
  ok $idf && ref($idf) eq 'HASH', 'compute_idf returns hashref';

  # Test compute_tfidf_batch
  my $tfidf_batch = $tw->compute_tfidf_batch($documents, $idf);
  ok $tfidf_batch && ref($tfidf_batch) eq 'ARRAY',
    'compute_tfidf_batch returns arrayref';
  cmp_ok scalar(@$tfidf_batch), '==', scalar(@$documents),
    'batch has correct number of vectors';

  # Test batch_cosine_similarity
  my $query_vec = $tw->compute_tfidf('document text', $idf);
  my $scores    = $tw->batch_cosine_similarity($query_vec, $tfidf_batch);
  ok $scores && ref($scores) eq 'ARRAY',
    'batch_cosine_similarity returns arrayref';
  cmp_ok scalar(@$scores), '==', scalar(@$tfidf_batch),
    'scores has correct count';

  done_testing;
};

done_testing;
