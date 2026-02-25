package SQLite::VecDB::Role::Embedding;
# ABSTRACT: Langertha embedding integration for SQLite::VecDB collections
our $VERSION = '0.001';

use Moose::Role;
use Carp qw( croak );

requires qw( add search embedding );

sub add_text {
  my ( $self, %args ) = @_;
  my $text = delete $args{text} // croak "text is required";
  my $vector = $self->embedding->simple_embedding($text);
  return $self->add(
    %args,
    vector  => $vector,
    content => $args{content} // $text,
  );
}


sub search_text {
  my ( $self, %args ) = @_;
  my $text = delete $args{text} // croak "text is required";
  my $vector = $self->embedding->simple_embedding($text);
  return $self->search(
    %args,
    vector => $vector,
  );
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

SQLite::VecDB::Role::Embedding - Langertha embedding integration for SQLite::VecDB collections

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  # Applied automatically when SQLite::VecDB has an embedding engine:
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

=head1 DESCRIPTION

This role is automatically applied to L<SQLite::VecDB::Collection> instances
when the parent L<SQLite::VecDB> has an C<embedding> engine set. It adds
C<add_text> and C<search_text> methods that use L<Langertha::Role::Embedding>
to generate vectors from text automatically.

=head2 add_text

  $coll->add_text(
    id   => 'doc1',
    text => 'Some text to embed and store.',
  );

Generates an embedding for C<text> using the configured Langertha engine,
then stores the vector. The text is also saved as C<content> unless you
provide your own C<content> value.

=head2 search_text

  my @results = $coll->search_text(
    text  => 'search query',
    limit => 10,
  );

Generates an embedding for the query C<text>, then performs KNN search.

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
