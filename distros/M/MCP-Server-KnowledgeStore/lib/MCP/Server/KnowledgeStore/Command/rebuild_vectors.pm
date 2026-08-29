package MCP::Server::KnowledgeStore::Command::rebuild_vectors;
use v5.38;
use Mojo::Base 'Mojolicious::Command', -signatures;

our $VERSION = '0.001';

use MCP::Server::KnowledgeStore::TermWeight;

# ABSTRACT: Rebuild the TF-IDF vectors used by search tools

has description =>
  'Rebuild TF-IDF vectors for latest revisions (hybrid search)';
has usage => <<~'USAGE';
  Usage: APPLICATION rebuild_vectors [OPTIONS]

    ./bin/mcp-ks rebuild_vectors
    ./bin/mcp-ks rebuild_vectors --kind=memory
    ./bin/mcp-ks rebuild_vectors --kind=skill
    ./bin/mcp-ks rebuild_vectors --all

  Rebuilds the TF-IDF vectors used by search_* tools.
  By default rebuilds vectors for all kinds (memory, skill, spec).
  Only processes LATEST REVISIONS (head_id).

  This should be run after initial deployment or when you want to
  refresh the vector cache.

  USAGE

sub run ($self, @args) {
  my $kind = undef;
  my $all  = 0;

  require Getopt::Long;
  Getopt::Long::GetOptions(
    'kind=s' => \$kind,
    'all'    => \$all,
  ) or die $self->usage;

  die $self->usage if @args;

  my $store = $self->app->store;
  my @kinds = $all ? qw(memory skill spec) : ($kind // qw(memory skill spec));

  for my $k (@kinds) {
    $self->app->log->info(
      "Rebuilding vectors for kind '$k' (latest revisions only)...");

    # Clear existing cache for this kind
    $store->db->query(<<~"SQL", $k);
      DELETE FROM document_tfidf
      WHERE revision_id IN (
        SELECT r.id
          FROM revisions r
          JOIN entries e ON e.head_id = r.id
         WHERE e.kind = ?
      )
      SQL
    $store->db->query('DELETE FROM corpus_idf WHERE kind = ?', $k);

    # Get all LATEST revisions
    my $entries = $store->db->query(<<~'SQL', $k)->hashes->to_array;
      SELECT e.id AS entry_id, e.name, r.id AS revision_id,
             r.body, r.description
        FROM entries e
        JOIN revisions r ON r.id = e.head_id
       WHERE e.kind = ? AND e.archived_at IS NULL
      SQL

    $self->app->log->info(
      "Found " . scalar(@$entries) . " latest revisions for $k");

    next unless @$entries;

    # Compute corpus IDF from latest revisions
    my $tw = MCP::Server::KnowledgeStore::TermWeight->new;
    my @texts
      = map { join ' ', $_->{name}, $_->{body}, ($_->{description} // '') }
      @$entries;
    my $idf = $tw->compute_idf(\@texts);

    # Store corpus IDF
    my $json_idf       = { json => $idf };
    my $document_count = scalar @$entries;
    my @idf_bind
      = ($k, $json_idf, $document_count, $json_idf, $document_count);
    $store->db->query(<<~'SQL', @idf_bind);
      INSERT INTO corpus_idf (kind, idf, document_count)
      VALUES (?, ?, ?)
      ON CONFLICT (kind) DO UPDATE SET idf = ?, document_count = ?, updated_at = now()
      SQL

    # Compute and store document vectors
    my $count = 0;
    for my $entry (@$entries) {
      my $text = join ' ', $entry->{name}, $entry->{body},
        ($entry->{description} // '');
      my $tf = $tw->compute_tf($text);
      my $tfidf
        = { map { $_ => ($tf->{$_} // 0) * ($idf->{$_} // 0) } keys %$tf };

      my $json_tfidf = { json => $tfidf };
      my $term_count = scalar keys %$tfidf;
      my @tfidf_bind
        = ($entry->{revision_id}, $json_tfidf, $term_count, $json_tfidf);
      $store->db->query(<<~'SQL', @tfidf_bind);
        INSERT INTO document_tfidf (revision_id, tfidf_vector, term_count)
        VALUES (?, ?, ?)
        ON CONFLICT (revision_id) DO UPDATE SET tfidf_vector = ?, updated_at = now()
        SQL
      $count++;
    }

    $self->app->log->info("Rebuild complete for $k: $count vectors stored");
  }

  $self->app->log->info('All vector rebuilds complete!');
  return 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Command::rebuild_vectors - Rebuild the TF-IDF vectors used by search tools

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  ./bin/mcp-ks rebuild_vectors
  ./bin/mcp-ks rebuild_vectors --kind=memory
  ./bin/mcp-ks rebuild_vectors --all

=head1 DESCRIPTION

Rebuilds the TF-IDF vectors used by the C<search_*> tools.

This command:

=over

=item * Clears existing vector cache

=item * Computes corpus-wide IDF from all latest revisions

=item * Computes and stores TF-IDF vectors for each latest revision

=back

Only LATEST REVISIONS (those referenced by C<entries.head_id>) are processed.
Historical revisions are ignored.

Run this after initial deployment, or whenever you want to refresh the
vector cache (e.g., after importing a large amount of data).

=head1 NAME

MCP::Server::KnowledgeStore::Command::rebuild_vectors - Rebuild TF-IDF vectors for hybrid search

=head1 OPTIONS

=over

=item --kind=KIND

Rebuild vectors only for the specified kind. Can be 'memory', 'skill', or 'spec'.
Default: rebuilds all kinds.

=item --all

Rebuild vectors for all kinds (memory, skill, spec). This is the default.

=back

=head1 SEE ALSO

L<MCP::Server::KnowledgeStore::Store>, L<MCP::Server::KnowledgeStore::TermWeight>

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
