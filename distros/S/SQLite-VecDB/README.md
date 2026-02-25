# SQLite::VecDB

SQLite as a vector database using [sqlite-vec](https://github.com/asg017/sqlite-vec). Store vectors with metadata, do KNN search, and optionally generate embeddings automatically via [Langertha](https://metacpan.org/pod/Langertha).

## Synopsis

```perl
use SQLite::VecDB;

my $vdb = SQLite::VecDB->new(
  db_file    => 'vectors.db',  # or ':memory:'
  dimensions => 768,
);

my $coll = $vdb->collection('documents');

$coll->add(
  id       => 'doc1',
  vector   => [0.1, 0.2, ...],
  metadata => { title => 'Hello World' },
  content  => 'Original text',
);

my @results = $coll->search(vector => [0.1, 0.2, ...], limit => 5);

for my $r (@results) {
  say "$r — distance: " . $r->distance;
}
```

## With Langertha — Automatic Embeddings

```perl
use SQLite::VecDB;
use Langertha::Engine::Ollama;

my $vdb = SQLite::VecDB->new(
  db_file    => 'vectors.db',
  dimensions => 768,
  embedding  => Langertha::Engine::Ollama->new(
    url             => 'http://localhost:11434',
    embedding_model => 'nomic-embed-text',
  ),
);

my $coll = $vdb->collection('docs');
$coll->add_text(id => 'doc1', text => 'Some text to embed and store.');
my @results = $coll->search_text(text => 'search query', limit => 5);
```

## Local Embeddings with Ollama (Docker)

```bash
docker run -d -p 11434:11434 --name ollama ollama/ollama
docker exec ollama ollama pull nomic-embed-text
```

## Installation

```
cpanm SQLite::VecDB
```
