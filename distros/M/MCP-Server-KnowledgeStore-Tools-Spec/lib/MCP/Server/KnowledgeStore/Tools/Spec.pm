package MCP::Server::KnowledgeStore::Tools::Spec;
use v5.38;
use Mojo::Base -strict, -signatures;

our $VERSION = '0.001';

# ABSTRACT: The spec MCP tools, as an MCP::Server::KnowledgeStore::Tools plugin

use Mojo::JSON                                  qw(true false);
use MCP::Server::KnowledgeStore::Tools::Support qw(
  name_pattern summary author revision_property author_property
  project_property
);

my $NAME_PATTERN = name_pattern;

sub register ($class, $server, $store, %opts) {
  $server->tool(
    name        => 'list_specs',
    description =>
      'List spec entries for a project - the write-up others can read to '
      . 'see what a project is meant to do',
    input_schema => {
      type                 => 'object',
      properties           => project_property(),
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $entries = $store->list('spec', $args->{project});
      return $tool->structured_result(
        { specs => [map { summary($_) } @$entries] });
    },
  );

  # Postgres tsvector picks the candidates, TF-IDF corpus vectors rank
  # them, and the matching lines come back with the hit. One tool: the
  # two this replaced ran the same query through the same ranking.
  $server->tool(
    name        => 'search_specs',
    description =>
      'Search across spec frontmatter and bodies. Postgres tsvector '
      . 'picks the candidates, TF-IDF corpus vectors rank them.',
    input_schema => {
      type       => 'object',
      properties => {
        query => { type => 'string', description => 'Text to search for' },
        limit => {
          type        => 'integer',
          minimum     => 1,
          maximum     => 100,
          default     => 10,
          description => 'Maximum number of results (default: 10)'
        },
        project_property()->%*,
      },
      required             => ['query'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $hits = $store->search('spec', $args->{query}, $args->{project},
        $args->{limit} // 10);
      return $tool->structured_result(
        {
          specs => [
            map {
              {
                summary($_)->%*,
                  matches => $_->{matches},
                  rank    => $_->{rank},
                  ts_rank => $_->{ts_rank}
              }
            } @$hits
          ]
        }
      );
    },
  );

  $server->tool(
    name        => 'get_spec',
    description =>
      'Fetch the full content of one spec, at its current or an older revision',
    input_schema => {
      type       => 'object',
      properties => {
        name => { type => 'string', pattern => $NAME_PATTERN },
        revision_property()->%*,
      },
      required             => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $entry = $store->get('spec', $args->{name}, $args->{revision});
      return $tool->text_result(
        "No spec named '$args->{name}'"
          . (
          defined $args->{revision} ? " at revision $args->{revision}" : ''
          ),
        1
      ) unless $entry;
      return $entry->{content};
    },
  );

  $server->tool(
    name         => 'save_spec',
    description  => 'Save a spec as a new revision in the shared store',
    input_schema => {
      type       => 'object',
      properties => {
        name        => { type => 'string', pattern => $NAME_PATTERN },
        content     => { type => 'string' },
        description => { type => 'string' },
        project_property()->%*,
        author_property()->%*,
      },
      required             => [qw(name content project)],
      additionalProperties => true,
    },
    code => sub ($tool, $args) {
      my $entry = $store->save(
        'spec', $args->{name}, $args->{content},
        author => author($tool, $args),
        map { defined $args->{$_} ? ($_ => $args->{$_}) : () }
          qw(description project)
      );
      return $tool->structured_result(
        { name => $entry->{name}, revision => $entry->{revision} });
    },
  );

  $server->tool(
    name         => 'list_spec_revisions',
    description  => 'List every saved revision of one spec, newest first',
    input_schema => {
      type       => 'object',
      properties => { name => { type => 'string', pattern => $NAME_PATTERN } },
      required   => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $history = $store->history('spec', $args->{name});
      return $tool->text_result("No spec named '$args->{name}'", 1)
        unless @$history;
      my @revisions;
      for my $row (@$history) {
        push @revisions,
          {
          revision    => $row->{revision},
          description => $row->{description},
          created_at  => "$row->{created_at}",
          is_head     => $row->{is_head} ? true : false,
          map { defined $row->{$_} ? ($_ => $row->{$_}) : () }
            qw(author type project),
          };
      }
      return $tool->structured_result({ revisions => \@revisions });
    },
  );

  $server->tool(
    name        => 'mark_spec_useful',
    description =>
      'Record that a spec was useful, incrementing its useful_count',
    input_schema => {
      type       => 'object',
      properties => { name => { type => 'string', pattern => $NAME_PATTERN } },
      required   => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $count = eval { $store->mark_useful('spec', $args->{name}) };
      return $tool->text_result("No spec named '$args->{name}'", 1)
        unless defined $count;
      return $tool->structured_result(
        { name => $args->{name}, useful_count => $count });
    },
  );

  # Lifecycle management tools - we need to handle allow_purge here since
  # Spec doesn't use Revisioned. Get it from the server stash if passed.
  my $allow_purge = $opts{allow_purge} // 1;

  $server->tool(
    name        => 'archive_spec',
    description =>
      'Archive (soft delete) a spec. Hides it from normal operations '
      . 'but keeps all data and revision history.',
    input_schema => {
      type       => 'object',
      properties => {
        name              => { type => 'string', pattern => $NAME_PATTERN },
        expected_revision => {
          type        => 'integer',
          minimum     => 1,
          description => 'Optional: verify this revision before archiving',
        },
        author => {
          type        => 'string',
          description => 'Who to record as performing the archive'
        },
        reason =>
          { type => 'string', description => 'Optional reason for archiving' },
      },
      required             => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $author = author($tool, $args);
      my $entry  = eval {
        $store->archive(
          'spec', $args->{name},
          author            => $author,
          expected_revision => $args->{expected_revision},
          reason            => $args->{reason},
        );
      };
      return $tool->text_result(
        "No spec named '$args->{name}' or already archived", 1)
        if $@ && $@ =~ /no spec named/;
      return $tool->text_result($@,                                1) if $@;
      return $tool->text_result("Already archived: $args->{name}", 1)
        unless $entry;
      return $tool->structured_result(
        {
          name        => $entry->{name},
          revision    => $entry->{revision},
          archived_at => "$entry->{archived_at}",
        }
      );
    },
  );

  $server->tool(
    name         => 'restore_spec',
    description  => 'Restore a previously archived spec',
    input_schema => {
      type       => 'object',
      properties => {
        name   => { type => 'string', pattern => $NAME_PATTERN },
        author => {
          type        => 'string',
          description => 'Who to record as performing the restore'
        },
        reason =>
          { type => 'string', description => 'Optional reason for restoring' },
      },
      required             => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $author = author($tool, $args);
      my $entry  = eval {
        $store->restore(
          'spec', $args->{name},
          author => $author,
          reason => $args->{reason}
        );
      };
      return $tool->text_result($@, 1) if $@;
      return $tool->text_result("No archived spec named '$args->{name}'", 1)
        unless $entry;
      return $tool->structured_result(
        {
          name     => $entry->{name},
          revision => $entry->{revision},
        }
      );
    },
  );

  $server->tool(
    name        => 'purge_spec',
    description => "Permanently delete a spec and ALL its revision history. "
      . (
      $allow_purge
      ? 'This is destructive and cannot be undone.'
      : 'DISABLED on this server'
      ),
    input_schema => {
      type       => 'object',
      properties => {
        name              => { type => 'string', pattern => $NAME_PATTERN },
        expected_revision => {
          type        => 'integer',
          minimum     => 1,
          description => 'Optional: verify this revision before purging',
        },
        author => {
          type        => 'string',
          description => 'Who to record as performing the purge'
        },
        reason => {
          type        => 'string',
          description => 'Optional reason for permanent deletion'
        },
      },
      required             => ['name'],
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      return $tool->text_result("purge_spec is disabled on this server", 1)
        unless $allow_purge;

      my $author = author($tool, $args);
      my $result = eval {
        $store->purge(
          'spec', $args->{name},
          author            => $author,
          expected_revision => $args->{expected_revision},
          reason            => $args->{reason},
        );
      };
      return $tool->text_result($@, 1) if $@;
      return $tool->structured_result($result);
    },
  );

  $server->tool(
    name        => 'list_archived_specs',
    description =>
      'List archived spec entries, optionally filtered by project',
    input_schema => {
      type                 => 'object',
      properties           => project_property(),
      additionalProperties => false,
    },
    code => sub ($tool, $args) {
      my $entries = $store->list_archived('spec', $args->{project});
      return $tool->structured_result(
        { specs => [map { summary($_) } @$entries] });
    },
  );

  # Add MCP Resource Templates (if server supports them)
  # These provide addressable reads via URIs as an alternative to get_spec
  if ($server->can('add_template')) {
    $server->add_template(
      uri_template => 'spec://specs/{name}',
      name         => 'spec_read',
      description  => 'Read the current revision of a spec by name',
      mime_type    => 'text/markdown',
      code         => sub ($template, $params, $context) {
        my $name  = $params->{name};
        my $entry = $store->get('spec', $name);
        return undef unless $entry;
        return $entry->{content};
      },
    );

    $server->add_template(
      uri_template => 'spec://specs/{name}/revisions/{revision}',
      name         => 'spec_read_revision',
      description  =>
        'Read a specific revision of a spec by name and revision number',
      mime_type => 'text/markdown',
      code      => sub ($template, $params, $context) {
        my $name     = $params->{name};
        my $revision = $params->{revision};
        my $entry    = $store->get('spec', $name, $revision);
        return undef unless $entry;
        return $entry->{content};
      },
    );
  }

  return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

MCP::Server::KnowledgeStore::Tools::Spec - The spec MCP tools, as an MCP::Server::KnowledgeStore::Tools plugin

=head1 VERSION

version 0.001

=head1 SYNOPSIS

  use MCP::Server::KnowledgeStore::Tools::Spec;

  MCP::Server::KnowledgeStore::Tools::Spec->register($mcp_server, $store);

=head1 DESCRIPTION

A L<MCP::Server::KnowledgeStore::Tools> plugin registering C<list_specs>,
C<search_specs>, C<get_spec>, C<save_spec>, C<list_spec_revisions>,
C<mark_spec_useful>, and the archive, restore, purge, and archived-list tools
against a L<MCP::Server::KnowledgeStore::Store>. Unlike memory and skill, a
spec's C<project> is required and single. A spec document belongs to exactly
one project, so there is no tag/untag pair.

=head1 METHODS

=head2 register

  MCP::Server::KnowledgeStore::Tools::Spec->register($server, $store);

Adds this plugin's tools to C<$server> (an L<MCP::Server>), backed by
C<$store>. Called by L<MCP::Server::KnowledgeStore::Tools/build> for every
installed plugin - not normally called directly.

=head1 AUTHOR

Wesley Schwengle <waterkip@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2026 by Wesley Schwengle.

This is free software, licensed under:

  The (three-clause) BSD License

=cut
