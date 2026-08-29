package MCP::Server::KnowledgeStore::TermWeight;
use v5.38;
use Mojo::Base -base;

our $VERSION = '0.001';

# ABSTRACT: TermWeight vector operations using Lingua::TermWeight

use Lingua::TermWeight;
use Lingua::TermWeight::WordSegmenter::SplitBySpace;
use Carp qw(croak);

# Singleton calculator instance
my $Calc = do {
  my $segmenter = Lingua::TermWeight::WordSegmenter::SplitBySpace->new;
  Lingua::TermWeight->new(word_segmenter => $segmenter);
};

# Compute TF for a single document
# Returns: {term => normalized_frequency}
sub compute_tf {
  my ($self, $text, $normalize) = @_;
  $normalize //= 1;
  croak 'text is required' unless defined $text;
  return $Calc->tf(document => $text, normalize => $normalize);
}

# Compute IDF for a corpus of documents
# Arguments: arrayref of document texts
# Returns: {term => idf_weight}
sub compute_idf {
  my ($self, $documents) = @_;
  croak 'documents is required'
    unless defined $documents && ref $documents eq 'ARRAY';
  croak 'documents must not be empty' unless @$documents;
  return $Calc->idf(documents => $documents);
}

# Compute TF-IDF for a single document given pre-computed IDF
# Arguments: document text, idf hashref
# Returns: {term => tfidf_weight}
sub compute_tfidf {
  my ($self, $text, $idf) = @_;
  croak 'text is required' unless defined $text;
  croak 'idf is required'  unless defined $idf && ref $idf eq 'HASH';

  my $tf = $self->compute_tf($text);
  return {
    map { $_ => ($tf->{$_} // 0) * ($idf->{$_} // 0) } keys %$tf,
    keys %$idf
  };
}

# Compute TF-IDF for multiple documents given pre-computed IDF
# Arguments: arrayref of document texts, idf hashref
# Returns: arrayref of {term => tfidf_weight}
sub compute_tfidf_batch {
  my ($self, $documents, $idf) = @_;
  croak 'documents is required'
    unless defined $documents && ref $documents eq 'ARRAY';
  croak 'idf is required' unless defined $idf && ref $idf eq 'HASH';

  my @tfidf;
  for my $doc (@$documents) {
    push @tfidf, $self->compute_tfidf($doc, $idf);
  }
  return \@tfidf;
}

# Compute cosine similarity between two vectors
# Arguments: two hashrefs {term => weight}
# Returns: similarity score (0-1)
sub cosine_similarity {
  my ($self, $vec1, $vec2) = @_;
  croak 'vec1 is required' unless defined $vec1 && ref $vec1 eq 'HASH';
  croak 'vec2 is required' unless defined $vec2 && ref $vec2 eq 'HASH';

  my $dot  = 0;
  my $mag1 = 0;
  my $mag2 = 0;

  my %all_terms = map { $_ => 1 } keys %$vec1, keys %$vec2;
  for my $term (keys %all_terms) {
    my $v1 = $vec1->{$term} // 0;
    my $v2 = $vec2->{$term} // 0;
    $dot  += $v1 * $v2;
    $mag1 += $v1**2;
    $mag2 += $v2**2;
  }

  return 0 unless $mag1 && $mag2;
  return $dot / (sqrt($mag1) * sqrt($mag2));
}

# Batch cosine similarity: compute similarity of query vector against multiple document vectors
# Arguments: query_vector, arrayref of document_vectors
# Returns: arrayref of similarity scores
sub batch_cosine_similarity {
  my ($self, $query_vec, $doc_vectors) = @_;
  croak 'query_vec is required'
    unless defined $query_vec && ref $query_vec eq 'HASH';
  croak 'doc_vectors is required'
    unless defined $doc_vectors && ref $doc_vectors eq 'ARRAY';

  return [map { $self->cosine_similarity($query_vec, $_) } @$doc_vectors];
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::TermWeight - TermWeight vector operations using Lingua::TermWeight

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use MCP::Server::KnowledgeStore::TermWeight;

  my $tw = MCP::Server::KnowledgeStore::TermWeight->new;

  # Compute TF for a document
  my $tf = $tw->compute_tf('the quick brown fox');

  # Compute IDF for a corpus
  my $idf = $tw->compute_idf([qw/doc1 doc2 doc3/]);

  # Compute TF-IDF for a document
  my $tfidf = $tw->compute_tfidf('the quick brown fox', $idf);

  # Compute cosine similarity
  my $similarity = $tw->cosine_similarity($vec1, $vec2);

=head1 DESCRIPTION

This module provides vector operations for semantic search using L<Lingua::TermWeight>.
It computes TF-IDF vectors and cosine similarity for ranking search results.

All operations work on the latest revisions only - historical revisions are not
considered in the corpus statistics.

=head1 NAME

MCP::Server::KnowledgeStore::TermWeight - TermWeight vector operations using Lingua::TermWeight

=head1 METHODS

=head2 compute_tf

  my $tf = $tw->compute_tf($text, $normalize);

Computes term frequency vector for a document. Returns a hashref of C<{term => weight}>.

=head2 compute_idf

  my $idf = $tw->compute_idf(\@documents);

Computes inverse document frequency for a corpus. C<\@documents> is an arrayref
of document texts. Returns a hashref of C<{term => weight}>.

=head2 compute_tfidf

  my $tfidf = $tw->compute_tfidf($text, $idf);

Computes TF-IDF vector for a document given pre-computed IDF. Returns a hashref
of C<{term => weight}>.

=head2 cosine_similarity

  my $sim = $tw->cosine_similarity($vec1, $vec2);

Computes cosine similarity between two vectors. Returns a score between 0 and 1.

=head1 SEE ALSO

L<Lingua::TermWeight>, L<MCP::Server::KnowledgeStore::Store>

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
