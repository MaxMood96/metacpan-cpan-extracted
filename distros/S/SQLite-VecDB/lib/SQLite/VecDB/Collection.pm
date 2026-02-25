package SQLite::VecDB::Collection;
# ABSTRACT: A named vector collection in SQLite::VecDB
our $VERSION = '0.001';

use Moose;
use JSON::MaybeXS qw( encode_json decode_json );
use DBI qw( :sql_types );
use Carp qw( croak );
use SQLite::VecDB::Result;

has name => (
  is => 'ro',
  isa => 'Str',
  required => 1,
);


has dbh => (
  is => 'ro',
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

has _initialized => (
  is => 'rw',
  isa => 'Bool',
  default => 0,
  init_arg => undef,
);

sub BUILD {
  my ( $self ) = @_;
  $self->_ensure_tables;
  if ($self->has_embedding) {
    require SQLite::VecDB::Role::Embedding;
    SQLite::VecDB::Role::Embedding->meta->apply($self);
  }
}

sub _ensure_tables {
  my ( $self ) = @_;
  return if $self->_initialized;

  my $name   = $self->name;
  my $dims   = $self->dimensions;
  my $metric = $self->distance_metric;
  my $dbh    = $self->dbh;

  $dbh->do(q{
    INSERT OR IGNORE INTO _vecdb_collections (name, dimensions, distance_metric)
    VALUES (?, ?, ?)
  }, {}, $name, $dims, $metric);

  $dbh->do(qq{
    CREATE VIRTUAL TABLE IF NOT EXISTS "vec_${name}" USING vec0(
      embedding float[$dims] distance_metric=$metric
    )
  });

  $dbh->do(qq{
    CREATE TABLE IF NOT EXISTS "meta_${name}" (
      rowid INTEGER PRIMARY KEY,
      id TEXT UNIQUE NOT NULL,
      metadata TEXT,
      content TEXT,
      created_at REAL DEFAULT (julianday('now'))
    )
  });

  $self->_initialized(1);
}

sub add {
  my ( $self, %args ) = @_;
  my $id       = $args{id}     // croak "id is required";
  my $vector   = $args{vector} // croak "vector is required";
  my $metadata = $args{metadata};
  my $content  = $args{content};

  croak "vector must have " . $self->dimensions . " dimensions"
    unless @$vector == $self->dimensions;

  my $name      = $self->name;
  my $dbh       = $self->dbh;
  my $json_meta = $metadata ? encode_json($metadata) : undef;
  my $vec_json = encode_json($vector);

  my $need_txn = $dbh->{AutoCommit};
  $dbh->begin_work if $need_txn;
  eval {
    $dbh->do(
      qq{INSERT INTO "meta_${name}" (id, metadata, content) VALUES (?, ?, ?)},
      {}, $id, $json_meta, $content,
    );
    my $rowid = $dbh->last_insert_id("", "", "", "");
    my $vec_sth = $dbh->prepare(
      qq{INSERT INTO "vec_${name}" (rowid, embedding) VALUES (?, ?)}
    );
    $vec_sth->bind_param(1, $rowid, SQL_INTEGER);
    $vec_sth->bind_param(2, $vec_json);
    $vec_sth->execute;
    $dbh->commit if $need_txn;
  };
  if (my $err = $@) {
    eval { $dbh->rollback } if $need_txn;
    croak "Failed to add vector: $err";
  }
  return $id;
}


sub search {
  my ( $self, %args ) = @_;
  my $vector = $args{vector} // croak "vector is required";
  my $limit  = $args{limit}  // 10;

  my $name     = $self->name;
  my $vec_json = encode_json($vector);

  my $sth = $self->dbh->prepare(qq{
    SELECT m.id, m.metadata, m.content, v.distance
    FROM "vec_${name}" v
    JOIN "meta_${name}" m ON m.rowid = v.rowid
    WHERE v.embedding MATCH ?
      AND k = ?
    ORDER BY v.distance
  });
  $sth->execute($vec_json, $limit);

  my @results;
  while (my $row = $sth->fetchrow_hashref) {
    push @results, SQLite::VecDB::Result->new(
      id       => $row->{id},
      distance => $row->{distance},
      metadata => $row->{metadata} ? decode_json($row->{metadata}) : {},
      ($row->{content} ? (content => $row->{content}) : ()),
    );
  }
  return @results;
}


sub get {
  my ( $self, %args ) = @_;
  my $id   = $args{id} // croak "id is required";
  my $name = $self->name;

  my $row = $self->dbh->selectrow_hashref(
    qq{SELECT id, metadata, content FROM "meta_${name}" WHERE id = ?},
    {}, $id,
  );
  return unless $row;

  return SQLite::VecDB::Result->new(
    id       => $row->{id},
    metadata => $row->{metadata} ? decode_json($row->{metadata}) : {},
    ($row->{content} ? (content => $row->{content}) : ()),
  );
}


sub delete {
  my ( $self, %args ) = @_;
  my $id   = $args{id} // croak "id is required";
  my $name = $self->name;
  my $dbh  = $self->dbh;

  my ($rowid) = $dbh->selectrow_array(
    qq{SELECT rowid FROM "meta_${name}" WHERE id = ?},
    {}, $id,
  );
  return 0 unless defined $rowid;

  my $need_txn = $dbh->{AutoCommit};
  $dbh->begin_work if $need_txn;
  eval {
    $dbh->do(qq{DELETE FROM "vec_${name}" WHERE rowid = ?}, {}, $rowid);
    $dbh->do(qq{DELETE FROM "meta_${name}" WHERE rowid = ?}, {}, $rowid);
    $dbh->commit if $need_txn;
  };
  if (my $err = $@) {
    eval { $dbh->rollback } if $need_txn;
    croak "Failed to delete vector: $err";
  }
  return 1;
}


sub count {
  my ( $self ) = @_;
  my $name = $self->name;
  my ($count) = $self->dbh->selectrow_array(
    qq{SELECT COUNT(*) FROM "meta_${name}"},
  );
  return $count;
}


sub add_batch {
  my ( $self, @items ) = @_;
  my $dbh = $self->dbh;
  $dbh->begin_work;
  eval {
    for my $item (@items) {
      $self->add(%$item);
    }
    $dbh->commit;
  };
  if (my $err = $@) {
    eval { $dbh->rollback };
    croak "Batch add failed: $err";
  }
  return scalar @items;
}


__PACKAGE__->meta->make_immutable;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SQLite::VecDB::Collection - A named vector collection in SQLite::VecDB

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  my $coll = $vdb->collection('documents');

  $coll->add(id => 'doc1', vector => [...], metadata => { title => 'Hi' });
  $coll->add(id => 'doc2', vector => [...], content => 'Some text');

  my @results = $coll->search(vector => [...], limit => 5);
  my $result  = $coll->get(id => 'doc1');
  my $count   = $coll->count;
  $coll->delete(id => 'doc1');

=head1 DESCRIPTION

Represents a named vector collection backed by a sqlite-vec virtual table
and a companion metadata table. Created via L<SQLite::VecDB/collection>.

When the parent L<SQLite::VecDB> has an C<embedding> engine,
L<SQLite::VecDB::Role::Embedding> is applied automatically, adding
C<add_text> and C<search_text> methods.

=head2 name

The collection name. Used as suffix for the underlying SQLite tables.

=head2 add

  $coll->add(
    id       => 'doc1',
    vector   => [0.1, 0.2, ...],
    metadata => { title => 'Hello' },   # optional
    content  => 'Original text...',      # optional
  );

Store a vector with optional metadata and content. The C<vector> ArrayRef
must have exactly C<dimensions> elements.

=head2 search

  my @results = $coll->search(
    vector => [0.1, 0.2, ...],
    limit  => 5,                  # default: 10
  );

Perform a KNN (k-nearest neighbor) search. Returns a list of
L<SQLite::VecDB::Result> objects ordered by distance (closest first).

=head2 get

  my $result = $coll->get(id => 'doc1');

Retrieve a stored entry by ID. Returns a L<SQLite::VecDB::Result> or
C<undef> if not found.

=head2 delete

  $coll->delete(id => 'doc1');

Delete a stored vector by ID. Returns 1 if deleted, 0 if not found.

=head2 count

  my $n = $coll->count;

Returns the number of vectors in this collection.

=head2 add_batch

  $coll->add_batch(
    { id => 'doc1', vector => [...] },
    { id => 'doc2', vector => [...], metadata => { ... } },
  );

Add multiple vectors in a single transaction.

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
