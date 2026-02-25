package SQLite::VecDB;
# ABSTRACT: SQLite as a vector database using sqlite-vec
our $VERSION = '0.001';

use Moose;
use DBI;
use Carp qw( croak );
use SQLite::VecDB::Collection;

has db_file => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);


has dimensions => (
  is => 'ro',
  isa => 'Int',
  required => 1,
);


has distance_metric => (
  is => 'ro',
  isa => 'Str',
  default => 'cosine',
);


has embedding => (
  is => 'ro',
  predicate => 'has_embedding',
);


has sqlite_vec_path => (
  is => 'ro',
  isa => 'Str',
  lazy => 1,
  builder => '_build_sqlite_vec_path',
);


has dbh => (
  is => 'ro',
  lazy => 1,
  builder => '_build_dbh',
  init_arg => undef,
);

sub _build_sqlite_vec_path {
  my ( $self ) = @_;
  return $ENV{SQLITE_VEC_PATH} if $ENV{SQLITE_VEC_PATH};
  eval { require Alien::sqlite_vec };
  if (!$@) {
    my @libs = Alien::sqlite_vec->dynamic_libs;
    return $libs[0] if @libs;
  }
  croak "Cannot find sqlite-vec extension. Set SQLITE_VEC_PATH or install Alien::sqlite_vec";
}

sub _build_dbh {
  my ( $self ) = @_;
  my $dbh = DBI->connect("dbi:SQLite:dbname=" . $self->db_file, "", "", {
    RaiseError => 1,
    PrintError => 0,
    sqlite_unicode => 1,
  });
  $dbh->sqlite_enable_load_extension(1);
  my $sth = $dbh->prepare("SELECT load_extension(?)");
  $sth->execute($self->sqlite_vec_path);
  $sth->finish;
  $dbh->do(q{
    CREATE TABLE IF NOT EXISTS _vecdb_collections (
      name TEXT PRIMARY KEY,
      dimensions INTEGER NOT NULL,
      distance_metric TEXT NOT NULL DEFAULT 'cosine',
      created_at REAL DEFAULT (julianday('now'))
    )
  });
  return $dbh;
}

sub collection {
  my ( $self, $name ) = @_;
  $name //= '_default';
  return SQLite::VecDB::Collection->new(
    name            => $name,
    dbh             => $self->dbh,
    dimensions      => $self->dimensions,
    distance_metric => $self->distance_metric,
    ($self->has_embedding ? (embedding => $self->embedding) : ()),
  );
}


sub collections {
  my ( $self ) = @_;
  my $rows = $self->dbh->selectall_arrayref(
    "SELECT name FROM _vecdb_collections ORDER BY name",
    { Slice => {} },
  );
  return map { $_->{name} } @$rows;
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SQLite::VecDB - SQLite as a vector database using sqlite-vec

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use SQLite::VecDB;

  my $vdb = SQLite::VecDB->new(
    db_file    => 'vectors.db',   # or ':memory:'
    dimensions => 768,
  );

  my $coll = $vdb->collection('documents');

  # Store a vector
  $coll->add(
    id       => 'doc1',
    vector   => [0.1, 0.2, ...],
    metadata => { title => 'Hello World' },
    content  => 'Original text content',
  );

  # KNN search
  my @results = $coll->search(
    vector => [0.1, 0.2, ...],
    limit  => 5,
  );

  for my $r (@results) {
    say $r->id;        # 'doc1'
    say $r->distance;  # 0.042
    say $r->metadata;  # { title => 'Hello World' }
    say $r->content;   # 'Original text content'
  }

=head1 DESCRIPTION

SQLite::VecDB turns SQLite into a vector database using the
L<sqlite-vec|https://github.com/asg017/sqlite-vec> extension. It supports
storing vectors with metadata, KNN (k-nearest neighbor) search, and
optional automatic embedding generation via L<Langertha>.

=head2 db_file

Path to the SQLite database file. Use C<:memory:> for an in-memory database.

=head2 dimensions

The number of dimensions for vectors in this database. Must match the
embedding model you are using (e.g. 768 for nomic-embed-text, 1536 for
OpenAI text-embedding-3-small).

=head2 distance_metric

Distance metric for vector search. Default is C<cosine>. Supported by
sqlite-vec: C<cosine>, C<l2>, C<l1>.

=head2 embedding

Optional. A L<Langertha> engine instance that supports the
L<Langertha::Role::Embedding> role. When set, collections gain
C<add_text> and C<search_text> methods that automatically generate
embeddings.

=head2 sqlite_vec_path

Path to the sqlite-vec shared library. Auto-detected from
C<$ENV{SQLITE_VEC_PATH}> or L<Alien::sqlite_vec> if not specified.

=head2 collection

  my $coll = $vdb->collection('documents');
  my $coll = $vdb->collection;  # uses '_default'

Returns a L<SQLite::VecDB::Collection> for the given name. Creates the
underlying tables on first use.

=head2 collections

  my @names = $vdb->collections;

Returns the names of all existing collections.

=head1 WITH LANGERTHA — AUTOMATIC EMBEDDINGS

  use SQLite::VecDB;
  use Langertha::Engine::OpenAI;

  my $engine = Langertha::Engine::OpenAI->new(
    api_key => $ENV{OPENAI_API_KEY},
  );

  my $vdb = SQLite::VecDB->new(
    db_file    => 'vectors.db',
    dimensions => 1536,
    embedding  => $engine,
  );

  my $coll = $vdb->collection('docs');

  # Text is automatically embedded
  $coll->add_text(
    id   => 'doc1',
    text => 'Kubernetes is a container orchestration platform.',
  );

  # Query is automatically embedded
  my @results = $coll->search_text(
    text  => 'container management',
    limit => 5,
  );

=head1 EMBEDDING SETUP

SQLite::VecDB stores and searches raw vectors. To generate embeddings from
text, pass any L<Langertha> engine that supports L<Langertha::Role::Embedding>
as the C<embedding> attribute.

=head2 Local Embeddings with Ollama (Recommended for Getting Started)

The easiest way to run embeddings locally — no API key, no cloud, free:

  # Start Ollama in Docker
  docker run -d -p 11434:11434 --name ollama ollama/ollama

  # Pull an embedding model (768 dimensions, ~270MB)
  docker exec ollama ollama pull nomic-embed-text

Then in Perl:

  use SQLite::VecDB;
  use Langertha::Engine::Ollama;

  my $engine = Langertha::Engine::Ollama->new(
    url             => 'http://localhost:11434',
    embedding_model => 'nomic-embed-text',
  );

  my $vdb = SQLite::VecDB->new(
    db_file    => 'my_vectors.db',
    dimensions => 768,
    embedding  => $engine,
  );

=head2 Popular Embedding Models

  Model                            Dimensions  Provider
  ─────────────────────────────────────────────────────
  nomic-embed-text (Ollama)        768         Local
  all-minilm (Ollama)              384         Local
  mxbai-embed-large (Ollama)       1024        Local
  text-embedding-3-small (OpenAI)  1536        Cloud
  text-embedding-3-large (OpenAI)  3072        Cloud

=head2 Cloud Embeddings with OpenAI

  use Langertha::Engine::OpenAI;

  my $engine = Langertha::Engine::OpenAI->new(
    api_key => $ENV{OPENAI_API_KEY},
  );

  my $vdb = SQLite::VecDB->new(
    db_file    => 'vectors.db',
    dimensions => 1536,   # text-embedding-3-small default
    embedding  => $engine,
  );

=head1 SQLITE-VEC EXTENSION

The sqlite-vec extension must be available as a shared library. SQLite::VecDB
finds it in this order:

=over

=item 1. The C<sqlite_vec_path> attribute (explicit path)

=item 2. C<$ENV{SQLITE_VEC_PATH}> environment variable

=item 3. L<Alien::sqlite_vec> (installs and compiles it automatically)

=back

=head1 SEE ALSO

=over

=item * L<SQLite::VecDB::Collection> - Collection operations (add, search, delete)

=item * L<SQLite::VecDB::Result> - Search result objects

=item * L<Alien::sqlite_vec> - Automatic sqlite-vec installation

=item * L<Langertha> - Perl LLM framework for embedding generation

=item * L<https://github.com/asg017/sqlite-vec> - sqlite-vec documentation

=back

=head1 SUPPORT

=head2 Issues

Please report bugs and feature requests on GitHub at
L<https://github.com/Getty/p5-sqlite-vecdb/issues>.

=head1 CONTRIBUTING

Contributions are welcome! Please fork the repository and submit a pull request.

=head1 AUTHOR

Torsten Raudssus <torsten@raudssus.us>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2026 by Torsten Raudssus.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
