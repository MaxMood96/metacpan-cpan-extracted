use Test2::V0;

eval { require SQLite::VecDB };
skip_all "SQLite::VecDB dependencies not met: $@" if $@;

my $api_key = $ENV{TEST_LANGERTHA_OPENAI_API_KEY};
skip_all 'Set TEST_LANGERTHA_OPENAI_API_KEY for live embedding tests' unless $api_key;

eval { require Langertha::Engine::OpenAI };
skip_all "Langertha::Engine::OpenAI not available: $@" if $@;

my $engine = Langertha::Engine::OpenAI->new(
  api_key         => $api_key,
  embedding_model => 'text-embedding-3-small',
);

my $vdb = eval {
  SQLite::VecDB->new(
    db_file    => ':memory:',
    dimensions => 1536,
    embedding  => $engine,
  );
};
skip_all "sqlite-vec not available: $@" unless $vdb;

my $coll = $vdb->collection('live_test');

# Add some documents
$coll->add_text(
  id   => 'perl',
  text => 'Perl is a high-level programming language for text processing.',
);
$coll->add_text(
  id   => 'python',
  text => 'Python is a popular programming language for data science.',
);
$coll->add_text(
  id   => 'cooking',
  text => 'A good risotto needs arborio rice, broth, and parmesan cheese.',
);

is $coll->count, 3, 'three documents stored';

# Search for programming — should find perl/python before cooking
my @results = $coll->search_text(text => 'programming languages', limit => 3);
is scalar @results, 3, 'search returns 3 results';

my %rank = map { $results[$_]->id => $_ } 0..$#results;
ok $rank{cooking} > $rank{perl} || $rank{cooking} > $rank{python},
  'cooking ranks lower than at least one programming result';

note "Results:";
for my $r (@results) {
  note sprintf "  %s (distance: %.4f)", $r->id, $r->distance;
}

done_testing;
